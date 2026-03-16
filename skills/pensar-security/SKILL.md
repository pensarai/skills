---
name: pensar-security
description: >-
  Security testing and penetration testing with Pensar. Use when the user asks
  about vulnerability scanning, penetration testing, security findings, or
  fixing security issues — or when they're working on security-sensitive code
  like authentication, payments, file uploads, or user input handling. Supports
  hands-on pentesting via the Apex CLI and project management via Console MCP
  tools.
metadata:
  author: pensarai
  version: "1.0"
---

# Security Testing with Pensar

Pensar provides AI-powered penetration testing. Two tools are available
depending on your setup — detect which is available and use the right one.

**Apex CLI** — open-source, hands-on security testing. Best for actively
pentesting a target, running targeted tests with specific objectives, and
whitebox testing against local source code. More flexible for deep-dive work.
Install: `npm i -g pensar` | Docs: https://docs.pensar.dev/apex
Repo: https://github.com/pensarai/apex

**Console MCP** — hosted platform for ongoing security. Best for checking in on
projects, continuous testing, kicking off pentests in the background, reviewing
findings across scans, and applying AI-generated fixes. Requires a Pensar
account. Docs: https://docs.pensar.dev/console

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

## Choose Your Tool

**If the Pensar MCP server is configured** (check for `pensar` in MCP servers):
Use Console MCP tools. Structured JSON responses, no shell needed.
Good for: checking project status, reviewing findings, dispatching scans,
applying fixes.

**If the `pensar` CLI is on PATH** (run `which pensar`):
Use the Apex CLI. Best for hands-on testing with specific objectives.
Good for: targeted pentests, whitebox testing with local source code,
interactive operator mode, deep-dive security assessments.

**If neither is available:**
Suggest installing Apex: `npm i -g pensar` (free, open source, immediate)
Or setting up the Console MCP server: https://docs.pensar.dev/console/integrations/mcp-server

**If both are available:**
Use Console MCP for project management, status checks, and applying fixes.
Use Apex CLI when the user wants hands-on targeted testing or interactive mode.

---

## Console MCP

The Pensar MCP server provides structured access to Console features — project
management, scan dispatching, issue tracking, and AI-generated fixes — directly
from your coding agent.

### Setup

The server is hosted at `https://api.pensar.dev/mcp` using Streamable HTTP
transport. Authentication uses OAuth 2.0 — most MCP clients handle the flow
automatically. Just sign in via browser when first connecting.

For client configuration (Claude Code, Cursor, Windsurf, etc.):
https://docs.pensar.dev/console/integrations/mcp-server

### Workflows

#### Scan a Project for Vulnerabilities

1. `list_projects` — find the project by name, get `projectId`
2. `dispatch_pentest({ projectId, scanLevel: "full" })` — get `scanId`
3. Poll `get_scan({ scanId })` until status is `completed` (check every 30s)
4. `list_issues({ projectId, scanId })` — retrieve findings
5. For critical/high findings: `get_issue` → `list_fixes` → `get_fix`

Confirm with user before dispatching — creates real scans, uses compute.
Use `scanLevel: "priority"` for a quick check, `"full"` for comprehensive.
Specify `branch` to target a specific git branch.

#### Review Existing Findings

1. `list_projects` — find the project
2. `list_scans({ projectId })` — find the relevant scan
3. `list_issues({ projectId, scanId })` — overview of all findings
4. `get_issue({ issueId })` — full details including description and PoC

Present findings grouped by severity (CRITICAL first). For each, include:
the title, severity, affected endpoint/location, and a one-line description.

#### Apply a Fix

1. `list_fixes({ issueId })` — check if fixes are available
2. `get_fix({ fixId })` — returns `{ filePath, diff, explanation }`
3. Apply the unified diff to `filePath`
4. Share the `explanation` with the user so they understand the change
5. Run tests to verify the fix doesn't break anything

### Scan Statuses

| Status | Meaning |
|--------|---------|
| `queued` | Scan is waiting to start |
| `running` | Scan is actively testing |
| `completed` | Scan finished — results available |
| `failed` | Scan encountered an error |
| `paused` | Scan was paused |

### Tools Reference

#### list_projects
List all projects in the workspace.
**Input:** None
**Returns:** `[{ id, name, source }]`

#### list_scans
List scans for a project.
**Input:** `projectId` (required)
**Returns:** `[{ id, label, status, scanType, branch, startedAt, completedAt }]`

#### get_scan
Get details for a specific scan.
**Input:** `scanId` (required)
**Returns:** `{ id, label, status, scanType, branch, startedAt, completedAt, projectId, projectName, errorMessage, issuesFound, reportReady }`

#### list_issues
List security issues with optional filters.
**Input:** `projectId` (required), `scanId?`, `status?`, `severity?`, `branch?`
**Returns:** `[{ id, title, severity, status, location }]`

#### get_issue
Get full details for a security issue.
**Input:** `issueId` (required)
**Returns:** `{ id, title, severity, status, location, description, lineRange, branch, endpoint, poc, projectId, projectName, createdAt }`

#### list_fixes
List available fixes for an issue.
**Input:** `issueId` (required)
**Returns:** `[{ id, filePath }]`

#### get_fix
Get the fix diff and explanation.
**Input:** `fixId` (required)
**Returns:** `{ id, filePath, diff, explanation, issueId }`

#### dispatch_pentest
Dispatch a new penetration test. **Confirm with user before calling.**
**Input:** `projectId` (required), `branch?`, `scanLevel?` ("priority" | "full", default: "priority")
**Returns:** `{ scanId, label, status: "queued", message }`

**For more details:**
- https://docs.pensar.dev/console — full Console documentation
- https://docs.pensar.dev/console/integrations/mcp-server — MCP server setup

---

## Apex CLI

Open-source CLI for hands-on security testing. Install with `npm i -g pensar`.

### Authentication

Run `pensar` and use the `/auth` command in the TUI.
Or set `ANTHROPIC_API_KEY` (or other provider key) as an environment variable.
Config is stored in `~/.pensar/config.json`.

### Workflows

#### Scan a Project for Vulnerabilities

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

#### Run a Targeted Test

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

#### Review Existing Findings

Findings from the last session are in `~/.pensar/sessions/`. Each finding
is a JSON file in the `findings/` directory. The pentest report at
`pentest-report.md` has a formatted summary.

#### Apply a Fix

PoC scripts in `~/.pensar/sessions/{id}/pocs/` demonstrate the vulnerability.
The pentest report includes remediation guidance. Apply the suggested fix,
then re-run the targeted test to confirm the vulnerability is resolved.

#### Interactive Operator Mode

For deep-dive security work with full agent control:
```bash
pensar operator
```

This launches an interactive TUI where you can direct the security agent
in real-time — useful for complex testing scenarios.

### Command Reference

| Command | Description |
|---------|-------------|
| `pensar pentest --target <url>` | Blackbox pentest |
| `pensar pentest --target <url> --cwd <path>` | Whitebox pentest |
| `pensar targeted-pentest --target <url> --objective <text>` | Targeted test |
| `pensar operator` | Interactive operator mode |

Common flags:
- `--model <model>` — AI model (default: `claude-sonnet-4-5`)
- `--mode exfil` — Flag extraction mode (CTF)
- `--objective <text>` — Repeatable for multiple objectives

**For more details:**
1. `pensar --help` and `pensar <command> --help` — authoritative CLI reference
2. https://docs.pensar.dev/apex — full documentation
3. https://github.com/pensarai/apex — source code, issues, README

Always check `pensar --help` first for the latest flags and commands — it's
the source of truth for CLI usage.

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
