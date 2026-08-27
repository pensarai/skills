---
name: pensar-security
description: >-
  AI-powered penetration testing, vulnerability scanning, and attack-surface
  management with the Pensar Apex CLI. Use for security scanning, pentesting,
  reviewing findings, applying fixes, or managing the workspace attack surface
  (apps & endpoints), pentests, and issues from the Console.
metadata:
  author: pensarai
  version: "3.0"
---

# Security Testing with Pensar

Pensar Apex is an open-source, AI-powered CLI for penetration testing. It
supports autonomous scanning, targeted tests with specific objectives, an
interactive operator mode, and full management of the workspace **attack
surface** (apps & endpoints), pentests, issues, fixes, and agent logs through
the Pensar Console API.

Install: `curl -fsSL https://pensarai.com/install.sh | bash` | Docs: https://docs.pensar.dev/apex
Repo: https://github.com/pensarai/apex

The CLI splits into two kinds of operations:

- **Local engagements** run on this machine and stream results to the terminal:
  `pensar pentest`, `pensar targeted-pentest`, `pensar threat-model`, and the
  operator (`pensar -p <prompt>` or the interactive TUI).
- **Console / workspace operations** act on the workspace you logged into with
  `pensar login`. They print JSON to stdout — ideal for an agent to parse and
  chain: `pensar apps`, `pensar pentests`, `pensar issues`, `pensar fixes`,
  `pensar logs`. There is no `projectId` argument — everything is scoped to the
  selected workspace.

## When to Use

Activate when the user:
- Asks to scan a project or URL for vulnerabilities
- Wants to run a penetration test
- Asks about security findings, issues, or vulnerabilities
- Wants to see or apply fix recommendations
- Mentions CVSS scores or severity ratings
- Asks to check the status of a security scan
- Wants to view, create, update, or audit the **attack surface** — the apps and
  endpoints Pensar knows about in their workspace
- Wants to dispatch a Console scan, triage issues, or inspect agent logs

Also consider suggesting a security scan when:
- The user just wrote or modified authentication code
- The user is working on payment processing, file uploads, or user input handling
- The user is about to deploy or merge to production
- The user asks "is this secure?" about code they're writing
- New API endpoints or routes were added (these likely belong on the attack surface)

## Setup

### Installation

```bash
# macOS / Linux
curl -fsSL https://pensarai.com/install.sh | bash

# Homebrew
brew tap pensarai/tap && brew install apex

# npm (requires Node.js)
npm install -g @pensar/apex

# Windows
irm https://www.pensarai.com/apex.ps1 | iex
```

After installing, run `pensar doctor` to check and auto-install optional
dependencies (e.g., nmap). Full setup guide: https://docs.pensar.dev/apex/overview/getting-started

### Authentication

**Option A — Pensar Console (managed inference + workspace operations):**
```bash
pensar login            # device-flow browser auth; select a workspace
pensar login status     # show connection + active workspace
pensar login logout     # disconnect
```
`pensar login` is required before any Console/workspace operation (`apps`,
`pentests`, `issues`, `fixes`, `logs`). The legacy `pensar auth ...` alias still
works (`pensar auth login`, `pensar auth status`, `pensar auth logout`).

**Option B — Bring your own API key (local engagements only):**
Set `ANTHROPIC_API_KEY` (or `OPENAI_API_KEY`, `OPENROUTER_API_KEY`, or
`PENSAR_API_KEY`) as an environment variable. Config is stored in
`~/.pensar/config.json`. This powers local pentests/operator but does not give
access to workspace Console data (use `pensar login` for that).

---

## Workflows

### Manage the Attack Surface (apps & endpoints)

`pensar apps` inventories and edits the workspace attack surface — the **apps**
(applications/services) and the **endpoints** that belong to them. Requires
`pensar login`; all output is JSON, so chain commands by extracting IDs.

```bash
pensar apps                              # list apps (paginated)
pensar apps get <appId>                  # app detail
pensar apps endpoints <appId>            # an app's endpoints
pensar apps endpoint <endpointId>        # endpoint detail (incl. objectives)
pensar apps search-endpoints "admin" --min-risk 7
```

> **For anything beyond reading, use the `pensar-attack-surface` skill.**
> Consolidating duplicate apps, moving endpoints between apps, rewriting
> testing objectives and threat models, and adding what recon missed all have
> ordering and data-loss pitfalls — notably that **deleting an app also deletes
> its endpoints**, and that `--objective` replaces the list rather than
> appending. That skill covers those workflows in full.

Creating, updating, and deleting are **mutating** — confirm with the user
first. Pagination contract: responses include `hasMore`, `limit`, `offset`;
iterate by incrementing `--offset` by `--limit` until `hasMore` is `false`.


### Scan a Project for Vulnerabilities (local)

```bash
# Blackbox (just a URL)
pensar pentest --target <url>

# Whitebox (URL + local source code → enables whitebox attack-surface analysis)
pensar pentest --target <url> --cwd <path>
```

Useful pentest flags:
- `--cwd <path>` — local source for whitebox analysis
- `--mode exfil` — pivoting & flag extraction (CTF)
- `--model <model>` — override the AI model (default: auto-selected from provider)
- `--prompt <text|@file>` — extra guidance (inline or `@filepath`)
- `--threat-model <text|@file>` — threat model to steer the pentest
- `--extended-thinking` — enable extended thinking (supported models)
- `--task-driven` — experimental task-driven architecture
- `--header "Name: Value"` / `--headers-from <file>` / `--no-global-headers` — HTTP headers

Results stream to the terminal and are saved to:
- Findings: `~/.pensar/sessions/{id}/findings/`
- PoC scripts: `~/.pensar/sessions/{id}/pocs/`
- Report: `~/.pensar/sessions/{id}/pentest-report.md`

The session path is printed as `PENSAR_SESSION_PATH:<path>`.

### Run a Targeted Test (local)

When the user has a specific concern ("test the auth endpoint", "check for
SQL injection on the search form"):

```bash
pensar targeted-pentest --target <url> --objective "Test for SQL injection on /api/search"
```

Multiple objectives (repeat `--objective`, at least one required):
```bash
pensar targeted-pentest --target <url> \
  --objective "Test for authentication bypass" \
  --objective "Test for IDOR on user profile endpoints"
```

This is more focused than a full scan — the agent tests exactly what you ask.
Also accepts `--model` and the `--header` / `--headers-from` / `--no-global-headers` flags.

### Operator Mode (interactive or headless)

For deep-dive security work with real-time control.

**Headless (scriptable / agent-friendly):**
```bash
pensar -p "Enumerate the admin panel on https://example.com and report auth weaknesses"
```
Options: `-p/--prompt <text|@file>` (required), `-s/--system <text|@file>`,
`--target <url>`, `--model`, and the header flags. After the agent finishes it
prompts for an optional follow-up so you can continue the conversation.

**Interactive TUI:**
```bash
pensar            # launch the TUI, then run /operator
```
In the operator dashboard, press **Shift+Tab** to cycle the mode:
`approvals-on → approvals-off → plan`.
- **approvals-on** — every tool call waits for approval (`Y` to approve, `A` to auto-approve from here on)
- **approvals-off** — tool calls execute automatically
- **plan** — read-only; the agent reconnoiters and writes a plan without taking action

Best for: targeted investigations, first-time testing, learning, and sensitive
production environments.

### Generate a Threat Model (local)

Produce an application-centric threat model for the current codebase:

```bash
pensar threat-model                       # writes ./threat-model.md
pensar threat-model -o docs/threat.md     # custom output path
pensar threat-model --model <model>
```

Runs against the current working directory and writes a Markdown threat model
you can feed back into a pentest via `--threat-model`.

### Dispatch & Track Console Pentests

When logged in, manage Console-run scans on the active workspace:

```bash
# List scans in the workspace
pensar pentests

# Get scan details
pensar pentests get <pentestId>

# Dispatch a new pentest (operates on the logged-in workspace)
pensar pentests dispatch --branch main --level full
```

Dispatch options:
- `--branch <branch>` — target a specific git branch
- `--level <level>` — `priority` (default, quick) or `full` (comprehensive)

**Confirm with user before dispatching** — this creates real scans and uses
compute.

### Review Findings

**From local sessions:**
Findings from the last session are in `~/.pensar/sessions/`. Each finding is a
JSON file in the `findings/` directory. The pentest report at
`pentest-report.md` has a formatted summary.

**From Console API (workspace-scoped):**
```bash
# List issues in the workspace
pensar issues

# Filter by severity, status, scan, or branch
pensar issues --status open --severity critical
pensar issues --scan <scanId> --branch main

# Get full details for an issue
pensar issues get <issueId>
```

`<issueId>` accepts the issue UUID or its label (e.g. `VULN-000123`).

Filter options for `pensar issues`:
- `--status` — `open`, `closed`, `false-positive`, `in-review`
- `--severity` — `critical`, `high`, `medium`, `low`
- `--scan` — filter by scan ID
- `--branch` — filter by branch name

Present findings grouped by severity (CRITICAL first). For each, include:
the title, severity, affected endpoint/location, and a one-line description.

### Apply a Fix

**From local sessions:**
PoC scripts in `~/.pensar/sessions/{id}/pocs/` demonstrate the vulnerability.
The pentest report includes remediation guidance. Apply the suggested fix,
then re-run the targeted test to confirm the vulnerability is resolved.

**From Console API:**
```bash
# List fixes for an issue
pensar fixes <issueId>

# Get fix details with diff
pensar fixes get <fixId>
```

The fix includes `filePath`, `diff`, and `explanation`. Apply the diff, share
the explanation with the user, and run tests to verify.

### Update Issue Status

```bash
# Close an issue
pensar issues update <issueId> --status closed --closed-reason "Patched in v2.1"

# Add comments while updating
pensar issues update <issueId> --status in-review --closed-comments "Pending review"

# Mark as false positive
pensar issues update <issueId> --false-positive --fp-reason "Test environment only"
```

### Debug Agent Behavior

```bash
# List agent logs for an issue
pensar logs <issueId>

# Filter by level or role
pensar logs <issueId> --level error --role tool-call --limit 50

# Search logs
pensar logs search <issueId> "SQL injection" --context 5
```

Log filters:
- `--level` — `debug`, `info`, `warn`, `error`
- `--role` — `assistant`, `user`, `system`, `tool-call`, `tool-result`
- `--limit <n>` — cap entries (default 100, max 500), list only
- `--context <n>` — context lines around matches (default 3), search only

### Manage Global Default HTTP Headers

Headers stored here are snapshotted into new local sessions at create time
(useful for auth tokens, tenant IDs, etc.):

```bash
pensar config headers list [--show]        # --show reveals masked secret values
pensar config headers add "Authorization: Bearer <token>"
pensar config headers set "X-Tenant-Id: acme"   # overwrite existing
pensar config headers remove <Name>
pensar config headers import <file>        # replace all from JSON/Name:Value file
pensar config headers clear --yes
```

Existing sessions are not retroactively updated. Per-engagement, prefer the
`--header` / `--headers-from` flags on `pentest` / `targeted-pentest` /
`-p` operator instead.

---

## CLI Command Reference

### Local Engagements

| Command | Description |
|---------|-------------|
| `pensar pentest --target <url>` | Autonomous blackbox pentest |
| `pensar pentest --target <url> --cwd <path>` | Whitebox pentest with source code |
| `pensar targeted-pentest --target <url> --objective <text>` | Focused test with specific objectives |
| `pensar -p <prompt>` | Headless operator session |
| `pensar` | Launch the interactive TUI (use `/operator`, `/pentest`, …) |
| `pensar threat-model [-o <path>]` | Generate an application-centric threat model |

Common flags:
- `--target <url>` — target URL, domain, or IP (required for pentest/targeted-pentest)
- `--cwd <path>` — local source for whitebox analysis (pentest)
- `--model <model>` — AI model (default: auto-selected from configured provider)
- `--mode exfil` — flag extraction mode, CTF (pentest)
- `--objective <text>` — repeatable (targeted-pentest, required)
- `--prompt <text|@file>` / `--threat-model <text|@file>` — guidance (pentest)
- `--extended-thinking`, `--task-driven` — pentest tuning (experimental)
- `--header "Name: Value"`, `--headers-from <file>`, `--no-global-headers` — HTTP headers
- `-p/--prompt <text|@file>` (required), `-s/--system <text|@file>` — operator

### Console / Workspace API (requires `pensar login`)

| Command | Description |
|---------|-------------|
| `pensar login` | Authenticate with Pensar Console + select workspace |
| `pensar login status` | Show connection + active workspace |
| `pensar login logout` | Remove stored credentials |
| `pensar apps` | List apps (attack surface) in the workspace |
| `pensar apps get <appId>` | Show app details |
| `pensar apps create [options]` | Create an app |
| `pensar apps update <appId> [options]` | Update an app |
| `pensar apps delete <appId>` | Delete an app |
| `pensar apps endpoints <appId> [filters]` | List an app's endpoints |
| `pensar apps endpoint <endpointId>` | Show endpoint details |
| `pensar apps endpoint-create <appId> [options]` | Create an endpoint |
| `pensar apps endpoint-update <endpointId> [options]` | Update an endpoint |
| `pensar apps endpoint-delete <endpointId>` | Delete an endpoint |
| `pensar apps search <query> [options]` | Substring-search apps |
| `pensar apps search-endpoints <query> [options]` | Substring-search endpoints |
| `pensar pentests` | List scans in the workspace |
| `pensar pentests get <pentestId>` | Get scan details |
| `pensar pentests dispatch [--branch <b>] [--level <l>]` | Dispatch a new pentest |
| `pensar issues [filters]` | List issues in the workspace |
| `pensar issues get <issueId>` | Get full issue details |
| `pensar issues update <issueId> [options]` | Update issue status |
| `pensar issues retest <issueId>` | Re-run the test that produced an issue |
| `pensar issues link-pr <issueId> --url <url>` | Link an externally opened PR to an issue |
| `pensar issues prs <issueId>` | List pull requests linked to an issue |
| `pensar fixes <issueId>` | List fixes for an issue |
| `pensar fixes get <fixId>` | Get fix diff and explanation |
| `pensar logs <issueId> [filters]` | List agent logs for an issue |
| `pensar logs search <issueId> <query>` | Search agent logs |
| `pensar targets <pentestId>` | List the targets (endpoints) a pentest exercised |
| `pensar targets logs <targetId> [filters]` | Agent logs for a target, incl. runs that found nothing |
| `pensar targets search <targetId> <query>` | Search a target's agent logs |

### Configuration & Utility

| Command | Description |
|---------|-------------|
| `pensar config headers ...` | Manage global default HTTP headers |
| `pensar doctor` | Check dependencies and AI provider config |
| `pensar upgrade` | Update to the latest version |
| `pensar version` | Show installed version |
| `pensar uninstall` | Remove Pensar Apex (keeps sessions, memories, skills) |
| `pensar help` | Show help |

### Global Flags

- `-h, --help` / `-v, --version`
- `--log-level <debug\|info\|warn\|error\|silent>` (`--verbose` = debug, `--quiet` = warn)
- `--obfuscate` (aliases `--redact`, `-O`) — redact hostnames, IPs, UUIDs,
  emails, paths, tokens, and apparent company names so TUI screenshots are safe
  to share

### TUI Slash Commands (Interactive Mode)

When running `pensar` interactively, these slash commands are available:

| Command | Description |
|---------|-------------|
| `/pentest` (`/p`, `/web`) | Start autonomous pentest swarm |
| `/operator` (`/o`) | Start interactive operator session |
| `/new` | Start a new operator session |
| `/plan` | Show current pentest plan |
| `/threat-model` (`/tm`) | Generate application-centric threat model |
| `/resume` (`/sessions`, `/s`) | Browse and resume previous sessions |
| `/login` (`/auth`) | Connect to Pensar Console |
| `/credits` (`/buy`) | Check credit balance / buy credits |
| `/models` | View and select AI models |
| `/providers` | Manage AI provider configs and API keys |
| `/obfuscate` (`/redact`) | Toggle screenshot-safe redaction (`on`/`off`/`toggle`) |
| `/themes` (`/theme`) | Change visual theme |
| `/skills` | View installed skills |
| `/help` | Show available commands |
| `/exit` (`/quit`, `/q`) | Exit the application |

**Always check `pensar --help` and `pensar <command> --help` first for the
latest flags and commands — the CLI is the source of truth for usage.**

---

## Interpreting Results

### Severity Levels

| Severity | CVSS Range | What to Do |
|----------|-----------|------------|
| CRITICAL | 9.0–10.0 | Flag immediately. Show the fix. Recommend blocking deployment. |
| HIGH | 7.0–8.9 | Show details and fix. Recommend prioritizing. |
| MEDIUM | 4.0–6.9 | Include in summary. Show fix if available. Fix before merge. |
| LOW | 0.1–3.9 | Mention in summary. Low priority. |

### Finding Fields

Each finding contains:
- **title** — Vulnerability name (e.g., "SQL Injection in Login Form")
- **severity** — CRITICAL, HIGH, MEDIUM, or LOW
- **description** — Technical details of the vulnerability
- **endpoint** — Affected URL or API endpoint
- **location** — Source file path (whitebox scans)
- **lineRange** — Affected line numbers (e.g., "10-25")
- **poc** — Proof of concept demonstrating the vulnerability
- **evidence** — Evidence collected during testing
