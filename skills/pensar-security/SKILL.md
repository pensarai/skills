---
name: pensar-security
description: >-
  Security testing and penetration testing with Pensar Apex CLI. Use when the
  user asks about vulnerability scanning, penetration testing, security
  findings, or fixing security issues — or when they're working on
  security-sensitive code like authentication, payments, file uploads, or user
  input handling.
metadata:
  author: pensarai
  version: "2.0"
---

# Security Testing with Pensar

Pensar Apex is an open-source, AI-powered CLI for penetration testing. It
supports autonomous scanning, targeted tests with specific objectives, and
interactive operator mode for guided security assessments.

Install: `npm i -g pensar` | Docs: https://docs.pensar.dev/apex
Repo: https://github.com/pensarai/apex

## When to Use

Activate when the user:
- Asks to scan a project or URL for vulnerabilities
- Wants to run a penetration test
- Asks about security findings, issues, or vulnerabilities
- Wants to see or apply fix recommendations
- Mentions CVSS scores or severity ratings
- Asks to check the status of a security scan

Also consider suggesting a security scan when:
- The user just wrote or modified authentication code
- The user is working on payment processing, file uploads, or user input handling
- The user is about to deploy or merge to production
- The user asks "is this secure?" about code they're writing
- New API endpoints or routes were added

## Setup

### Installation

```bash
npm i -g pensar
```

Verify with `pensar version`. Run `pensar doctor` to check dependencies and
AI provider configuration.

### Authentication

**Option A — Pensar Console (managed inference):**
```bash
pensar auth login
```
Opens a browser for device authorization. Tokens are stored locally. Check
status with `pensar auth status`.

**Option B — Bring your own API key:**
Set `ANTHROPIC_API_KEY` (or another provider's key) as an environment variable.
Config is stored in `~/.pensar/config.json`.

---

## Workflows

### Scan a Project for Vulnerabilities

```bash
# Blackbox (just a URL)
pensar pentest --target <url>

# Whitebox (URL + local source code for deeper analysis)
pensar pentest --target <url> --cwd <path>
```

Results stream to the terminal and are saved to:
- Findings: `~/.pensar/sessions/{id}/findings/`
- PoC scripts: `~/.pensar/sessions/{id}/pocs/`
- Report: `~/.pensar/sessions/{id}/pentest-report.md`

### Run a Targeted Test

When the user has a specific concern ("test the auth endpoint", "check for
SQL injection on the search form"):

```bash
pensar targeted-pentest --target <url> --objective "Test for SQL injection on /api/search"
```

Multiple objectives can be specified:
```bash
pensar targeted-pentest --target <url> \
  --objective "Test for authentication bypass" \
  --objective "Test for IDOR on user profile endpoints"
```

This is more focused than a full scan — the agent tests exactly what you ask.

### Interactive Operator Mode

For deep-dive security work with real-time control:
```bash
pensar operator
```

Launches an interactive TUI where you can direct the security agent step by
step. Supports two modes toggled with `Shift+Tab`:
- **Default mode** — all tools available (read/write/modify targets)
- **Plan mode** — read-only, agent observes and plans without taking action

Toggle approval on/off with `Option+Shift+Tab` to require confirmation before
each tool call.

Best for: targeted investigations, first-time testing, learning, and sensitive
production environments.

### Manage Projects & Scans via Console API

When authenticated with `pensar auth login`, you can manage projects and scans
through the CLI:

```bash
# List all projects in your workspace
pensar projects

# List scans for a project
pensar pentests <projectId>

# Get scan details
pensar pentests get <pentestId>

# Dispatch a new pentest via Console
pensar pentests dispatch <projectId> --branch main --level full
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

**From Console API:**
```bash
# List issues for a project
pensar issues <projectId>

# Filter by severity and status
pensar issues <projectId> --status open --severity critical

# Get full details for an issue
pensar issues get <issueId>
```

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
- `--limit <n>` — cap entries (default 100, max 500)

---

## CLI Command Reference

### Pentesting

| Command | Description |
|---------|-------------|
| `pensar pentest --target <url>` | Autonomous blackbox pentest |
| `pensar pentest --target <url> --cwd <path>` | Whitebox pentest with source code |
| `pensar targeted-pentest --target <url> --objective <text>` | Focused test with specific objectives |
| `pensar operator` | Interactive operator mode (TUI) |

Common flags for pentest commands:
- `--target <url>` — target URL, domain, or IP (required)
- `--cwd <path>` — path to local source code for whitebox analysis
- `--model <model>` — AI model to use (default: `claude-sonnet-4-5`)
- `--mode exfil` — flag extraction mode (CTF)
- `--objective <text>` — repeatable, for targeted-pentest

### Console API

| Command | Description |
|---------|-------------|
| `pensar auth login` | Authenticate with Pensar Console |
| `pensar auth logout` | Remove stored credentials |
| `pensar auth status` | Show connection details |
| `pensar projects` | List workspace projects |
| `pensar pentests <projectId>` | List scans for a project |
| `pensar pentests get <pentestId>` | Get scan details |
| `pensar pentests dispatch <projectId>` | Dispatch a new pentest |
| `pensar issues <projectId>` | List issues for a project |
| `pensar issues get <issueId>` | Get full issue details |
| `pensar issues update <issueId>` | Update issue status |
| `pensar fixes <issueId>` | List fixes for an issue |
| `pensar fixes get <fixId>` | Get fix diff and explanation |
| `pensar logs <issueId>` | List agent logs for an issue |
| `pensar logs search <issueId> <query>` | Search agent logs |

### Utility

| Command | Description |
|---------|-------------|
| `pensar doctor` | Check dependencies and AI provider config |
| `pensar upgrade` | Update to the latest version |
| `pensar version` | Show installed version |
| `pensar uninstall` | Remove Pensar Apex |

### TUI Slash Commands (Interactive Mode)

When running `pensar` interactively, these slash commands are available:

| Command | Description |
|---------|-------------|
| `/pentest` | Start autonomous pentest session |
| `/operator` | Start guided operator session |
| `/auth` | Connect to Pensar Console |
| `/models` | View and select AI models |
| `/providers` | Manage AI provider configs and API keys |
| `/sessions` | Browse and resume previous sessions |
| `/credits` | Check credit balance (managed inference) |
| `/config` | View and modify configuration |
| `/create-skill` | Create reusable operator skills |
| `/themes` | Change visual theme |
| `/help` | Show available commands |

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
