---
name: pensar-attack-surface
description: >-
  Curate a Pensar workspace's attack surface with the Pensar Apex CLI — review
  what recon discovered, consolidate duplicate applications, move endpoints
  between apps, rewrite testing objectives and threat models, and add apps or
  endpoints recon missed. Use when the user says the attack surface is wrong,
  messy, duplicated, or incomplete, or wants to clean up / reorganize / curate
  their workspace, applications, endpoints, or scan objectives before a pentest.
metadata:
  author: pensarai
  version: "1.1"
---

# Curating the Pensar Attack Surface

Pensar's reconnaissance builds a workspace **attack surface**: a set of
**applications** (services, UIs, domains, databases) each owning a set of
**endpoints** (routes, RPCs, assets). Everything Pensar later pentests is
driven off that model — so when recon gets the shape wrong, the pentest tests
the wrong things.

This skill covers fixing that shape from the CLI. It is the "editing" half of
Pensar. For running pentests and triaging findings, use the `pensar-security`
skill.

Install: `curl -fsSL https://pensarai.com/install.sh | bash`
Docs: https://docs.pensar.dev/apex · Repo: https://github.com/pensarai/apex

## When to Use This Skill

Reach for it when the user says any of:

- "The attack surface doesn't look right" / "recon got this wrong"
- "These are all the same app" / "why are there twelve applications?"
- "This endpoint belongs to the other service"
- "It's testing the wrong things" / "these objectives are useless"
- "It missed our admin API" / "add these endpoints"
- "Clean up the workspace before we run the pentest"

The common trigger is **after a recon run, before a pentest**. Recon is a good
first draft, not a final answer — it over-splits applications it saw on
different hosts, under-describes internal services, and writes generic
objectives. Curating that draft is the highest-leverage thing a user can do to
improve pentest quality.

## The Mental Model

```
workspace
└── domain (optional, links an app to a verified hostname)
    └── application            ← "app": a service/UI/database
        └── endpoint           ← a route/RPC/asset, owns objectives
```

Three facts drive almost every decision below:

1. **Endpoints belong to exactly one app.** Reorganizing means *reparenting*
   endpoints, not copying them.
2. **Objectives live on the endpoint** and are handed to the pentest agent as
   that endpoint's marching orders. Editing objectives is how you steer a
   pentest without touching a single flag.
3. **Deleting an app deletes its endpoints.** There is no undo.

## Setup

```bash
pensar login          # device-flow browser auth; select the workspace
pensar login status   # confirm which workspace is active
```

Every command in this skill is scoped to the workspace selected at login.
There is no `--workspace` flag. **Always run `pensar login status` first** and
tell the user which workspace you are about to modify — editing the wrong
workspace is the most common serious mistake.

Check `pensar --version` and `pensar apps --help` before choosing commands.
An older executable on PATH may lack attack-surface commands; verify the
actual binary or source checkout used by every step. Do not silently switch
CLI versions halfway through a batch.

Data commands emit JSON; login status may be text. Parse and validate every
response. If large piped responses are truncated, capture stdout to a regular
temporary file and parse it after successful process exit. Never treat invalid
or partial JSON as an empty result.

## Working Rules

Apply these to every task in this skill:

- **Read before you write.** List and inspect first; build the full picture,
  then present a plan. Never mutate on the first command.
- **Confirm every destructive or bulk change** with the user before running
  it — `delete`, `endpoint-delete`, reparenting, and anything touching more
  than a couple of records. Prepare the concrete manifest and preview first.
  Existing explicit approval covers that scope; do not ask again for each
  record or a safe resume of the same batch.
- **Objectives are not in list output.** `apps endpoints` and
  `apps search-endpoints` omit `objectives` to keep responses small. You must
  `pensar apps endpoint <endpointId>` to read them. Never conclude "this
  endpoint has no objectives" from a list.
- **Updates are sparse.** Only the flags you pass change; everything else is
  left alone. There is no need to re-send unchanged fields.
- **`--objective` replaces, it does not append.** Passing objectives on an
  update overwrites the whole list. To add one, read the current list first
  and re-send all of them.
- **Risk scores are read-only through the curation CLI.** Agents compute
  them from exposure, data sensitivity, function criticality and security
  indicators. Metadata updates do not themselves trigger scoring; manually
  created endpoints can remain unscored. Better context helps when a scoring
  workflow actually runs. Report null scores separately from zero, and verify
  target inclusion before a scan: minimum-risk filters can exclude unscored
  records. Do not invent a score flag or perform an unrequested backend write.
- **Bulk changes need a recoverable batch.** Use an explicit field allowlist,
  before/after manifest, fresh backup, preflight, durable journal and per-write
  readback. See [bulk updates and recovery](references/bulk-updates.md).
- **Source coverage and context quality are separate checks.** Confirm routes
  against registered source paths, then trace behavior and permissions. Read
  [source-grounded context](references/source-grounded-context.md) when source
  is available; route counts and valid citations alone do not prove accuracy.
- **Page through everything.** List responses are
  `{ ..., hasMore, limit, offset }`. Increment `--offset` by `--limit` until
  `hasMore` is `false`. Default page is 100 (max 200) for lists, 50 (max 200)
  for search. Silently working off page one is how you "consolidate" a
  workspace and leave half of it behind.

---

## Workflow 1 — Audit the Attack Surface

Do this first, always. It is also the whole job when the user just asks
"what does Pensar think our attack surface is?"

```bash
# Every app in the workspace
pensar apps --limit 200

# Endpoint counts and risk per app
pensar apps endpoints <appId> --limit 200

# Full detail on one app / one endpoint
pensar apps get <appId>
pensar apps endpoint <endpointId>
```

Build an inventory, then report it grouped by application with endpoint count
and highest risk score, including the count of unscored records. While reading,
flag the four problems worth fixing:

| Symptom | What it means | Workflow |
|---|---|---|
| Several apps with near-identical names, or one logical service split across hosts | Recon over-split | 2 — Consolidate |
| An endpoint whose path clearly belongs to a different service | Misfiled during recon | 3 — Move endpoints |
| Objectives that are generic ("test for vulnerabilities") or absent | Pentest has no direction | 4 — Rewrite objectives |
| A service the user knows exists but isn't listed | Recon couldn't reach it | 5 — Add what's missing |

Surface these as a proposal. Let the user pick what to fix.

To find things fast in a large workspace:

```bash
pensar apps search "billing" --type api-service
pensar apps search-endpoints "admin" --min-risk 7
pensar apps search-endpoints "login" --auth-required --app <appId>
```

Both are substring matches scoped to the workspace.

---

## Workflow 2 — Consolidate Duplicate Applications

**Consolidation can destroy data when duplicates are deleted.** Recon
routinely represents one service as several apps (staging vs prod hostnames, a
CDN alias, an IP and its DNS name).

The safe order is always: **keep one, move the endpoints, then delete the
empties.** Deleting first takes the endpoints with it.

```
Consolidation checklist:
- [ ] 1. List all candidate apps and their endpoints (page fully)
- [ ] 2. Pick the survivor; confirm the merge set with the user
- [ ] 3. Move every endpoint from each duplicate onto the survivor
- [ ] 4. Verify the duplicates are now empty
- [ ] 5. Delete the empty duplicates
- [ ] 6. Update the survivor's description to cover the merged scope
```

### 1–2. Identify and confirm

```bash
pensar apps --limit 200 | jq '.apps[] | {id, name, type, domainUrl}'
pensar apps endpoints <dupId> --limit 200 | jq '.endpoints[] | {id, endpoint, transport}'
```

Present the merge plan — survivor, duplicates, and endpoint count moving —
and get explicit approval. Prefer as survivor the app with the richest
description and the linked domain.

### 3. Move the endpoints

`endpoint-update --app <destAppId>` reparents an endpoint. Repeat per endpoint:

```bash
pensar apps endpoint-update <endpointId> --app <survivorAppId>
```

For a whole application, first collect **every page** of endpoint IDs into
an immutable manifest, inspect collisions, and use the
[bulk workflow](references/bulk-updates.md). Do not mutate an application while
paginating its shrinking endpoint list: offset pagination can skip records.

**Expect collisions.** Endpoint identity is unique on **(path, transport)
within an app**. Moving `/health` onto an app that already has `/health` over
the same transport returns **409**:

> An endpoint with this path and transport already exists in the application.

That is an identity collision, not proof the records describe identical
behavior. Compare methods, auth and context before proposing a merge: read both
(`apps endpoint <id>`), fold any objectives, business logic, or auth details
the survivor's copy is missing into it with `endpoint-update`, then delete the
leftover with `endpoint-delete`. Never resolve a 409 by renaming the path to
something that isn't real — a fabricated path gets pentested as if it existed.

### 4–5. Verify, then delete

```bash
pensar apps endpoints <dupId>          # must be empty before deleting
pensar apps delete <dupId>
```

Confirm the empty result before every delete. `apps delete` cascades to any
endpoint still attached, and nothing warns you.

### 6. Fix the survivor's description

The merged app now covers more than its description says. Descriptions feed
the pentest agent's understanding of the target, so this matters:

```bash
pensar apps update <survivorAppId> \
  --description "Billing service — prod and staging hosts, invoicing and payment webhooks" \
  --type api-service
```

---

## Workflow 3 — Move Endpoints Between Apps

The same reparenting primitive, used surgically when the app inventory is
already correct but individual endpoints are misfiled:

```bash
pensar apps endpoint-update <endpointId> --app <correctAppId>
```

Use it when an endpoint's path clearly belongs to another service — recon
often files everything it found behind one hostname under a single app, even
when a reverse proxy fronts three services.

Moving an endpoint keeps its objectives, risk score, auth details, and threat
model. Only its parent changes. The (path, transport) collision rule above
applies here too.

---

## Workflow 4 — Rewrite Objectives and Threat Models

**The highest-value edit in this skill and the most underused.** Objectives
are the per-endpoint instructions the pentest agent receives. Recon writes
plausible but generic ones. Replacing them with what the user actually worries
about is the difference between a pentest that finds real business-logic bugs
and one that reports missing headers.

Read the current state first — objectives only appear on detail:

```bash
pensar apps endpoint <endpointId> | jq '{endpoint, objectives, businessLogic, threatModel, authenticationRequired}'
```

Before rewriting, trace the handler/page, authorization dependency and service
behavior. Preserve useful existing details. Each record should explain its
actors, inputs, ownership/capability boundaries, state changes and side effects;
objectives should specify fixtures, actions, controls and observable outcomes.
Use [source-grounded context](references/source-grounded-context.md) for the
review checklist. Prefer relevant specificity over a word-count target.

Then rewrite. **Every `--objective` you pass replaces the entire list**, so
send the full intended set in one call:

```bash
pensar apps endpoint-update <endpointId> \
  --objective "Attempt IDOR: fetch another tenant's invoice by incrementing the id" \
  --objective "Verify the finance-role check cannot be bypassed via the export param" \
  --business-logic "Tenant-scoped. Only finance-role users may read invoices." \
  --threat-model "Cross-tenant data exposure is the primary risk; billing totals are PII-adjacent."
```

What makes an objective good:

- **Specific about the attack**, not the category — "test for IDOR on the
  invoice id path param", not "check authorization".
- **Grounded in the app's real rules** — name the roles, tenancy model, and
  which fields must not cross a boundary.
- **Reachable from this endpoint.** Objectives are scoped to the endpoint they
  sit on; put an auth-bypass objective on the auth endpoint.

The three free-text fields work together, and all three reach the agent:

| Field | Holds | Use it for |
|---|---|---|
| `--objective` (repeatable) | What to try | Concrete attacks to attempt |
| `--business-logic` | How it's supposed to work | Tenancy, roles, invariants |
| `--threat-model` | What would hurt | The consequence worth preventing |

Also correct auth metadata while you are here — it changes how the agent
approaches the endpoint and provides evidence for a future scoring pass:

```bash
pensar apps endpoint-update <endpointId> \
  --auth-required --auth-details "Bearer JWT; finance role required"

pensar apps endpoint-update <endpointId> --no-auth-required
```

At the application level, `--disallowed-actions` is the guardrail: free-form
notes telling the agent what it must not do against this app.

```bash
pensar apps update <appId> \
  --disallowed-actions "Do not submit payment intents. Do not delete customer records."
```

Set this on anything touching production, payments, or destructive endpoints —
before dispatching a pentest, not after.

---

## Workflow 5 — Add What Recon Missed

Recon only finds what it can reach. Internal services, unlinked admin panels,
and anything behind a VPN need to be added by hand — and the user usually
knows exactly what is missing.

```bash
pensar apps create \
  --name "Admin API" \
  --description "Internal back-office API; not publicly routed" \
  --type api-service \
  --framework "Express"
```

Then attach endpoints. `--endpoint` and `--description` are required:

```bash
pensar apps endpoint-create <appId> \
  --endpoint "/api/admin/users/:id/impersonate" \
  --description "Starts an impersonation session as the target user" \
  --type api-endpoint \
  --auth-required \
  --auth-details "Admin session cookie" \
  --objective "Verify a non-admin session cannot reach impersonation" \
  --objective "Check whether impersonation is audit-logged and revocable" \
  --business-logic "Admin-only. Should be logged and time-bounded."
```

If the codebase is at hand, record where the endpoint lives — it enables
whitebox correlation between findings and source:

```bash
pensar apps endpoint-create <appId> \
  --endpoint "/api/admin/users/:id/impersonate" \
  --description "Impersonation entrypoint" \
  --location "src/routes/admin/impersonate.ts" \
  --start-line 42 --end-line 88
```

**Valid types.** Invalid values are rejected with the full list, so when in
doubt just try one and read the error.

- `--type` on apps: `ui`, `api-service`, `web-application`, `full-stack`,
  `domain`, `subdomain`, `database`, `cloud-resource`, `storage`
- `--type` on endpoints: `api-endpoint`, `web-endpoint`, `auth-endpoint`,
  `database`, `file-storage`, `asset`

Reconcile registered routes, router mount prefixes and client API base URLs
against a fully paginated workspace inventory. Search all applications before
calling a route missing: it may be misfiled. Report method/path registrations
separately from platform records, whose identity is path plus transport within
an application. Preserve method-specific behavior in the metadata.

Separate rendered frontend pages, API handlers, public widgets, redirects,
layout-only routes and retired routes. A supplied archive is not proof of what
is deployed. Defer uncertain additions/deletions and domain linking unless
included in the user's scope; rerunning recon is not a guaranteed repair.

---

## Workflow 6 — Prune Junk

Recon picks up parked domains, vendor assets, and dead hosts. Removing them
keeps pentest budget on things that matter.

```bash
pensar apps endpoint-delete <endpointId>   # one endpoint
pensar apps delete <appId>                 # the app AND all its endpoints
```

Before proposing any delete, check what is attached and show the user the
count. If an app holds anything worth keeping, move it out first (Workflow 3).
When unsure whether something is real, prefer leaving it and flagging it —
deletion is unrecoverable, a stale record is merely noise.

---

## After Curating: Verify and Scan

Re-read affected endpoint details and compare the full inventory with the
backup. Verify changed fields, preserved fields, IDs, ownership and domain
links; report partial completion honestly. Check unscored target inclusion.
A successful curation batch does not authorize a scan. Once scan execution is
authorized, hand off to a pentest:

```bash
pensar apps --limit 200
pensar pentests dispatch --level full
```

`pensar pentests dispatch` costs real compute — always confirm first. Then
track it with `pensar pentests`, `pensar pentests get <id>`, and
`pensar targets <pentestId>` for per-endpoint agent logs (including endpoints
that came back clean). Triage from there belongs to `pensar-security`.

---

## Command Reference

Requires `pensar login`. Everything is scoped to the selected workspace.

| Command | Use it to |
|---|---|
| `pensar apps` | List apps (paginated) |
| `pensar apps get <appId>` | Full app detail incl. description, disallowedActions |
| `pensar apps create --name N --description D [...]` | Add a missed app |
| `pensar apps update <appId> [...]` | Fix name/description/type/framework/domain/disallowed-actions |
| `pensar apps delete <appId>` | Delete app **and all its endpoints** |
| `pensar apps endpoints <appId> [--type --min-risk --limit --offset]` | List an app's endpoints (no objectives) |
| `pensar apps endpoint <endpointId>` | Full endpoint detail **incl. objectives** |
| `pensar apps endpoint-create <appId> --endpoint E --description D [...]` | Add a missed endpoint |
| `pensar apps endpoint-update <endpointId> [--app ...]` | Edit fields, or reparent with `--app` |
| `pensar apps endpoint-delete <endpointId>` | Delete one endpoint |
| `pensar apps search <query> [--type --limit --offset]` | Find apps by substring |
| `pensar apps search-endpoints <query> [--app --type --min-risk --auth-required]` | Find endpoints workspace-wide |

App fields: `--name` `--description` `--type` `--framework` `--domain <id>`
`--disallowed-actions`

Endpoint fields: `--endpoint` `--description` `--type` `--location`
`--start-line` `--end-line` `--objective` (repeatable) `--auth-required` /
`--no-auth-required` `--auth-details` `--business-logic` `--threat-model`, plus
`--app <id>` on `endpoint-update` to move it.

**Version note.** Everything above ships in Apex **2.4.0**. Two additions are
canary-only at the time of writing: `pensar apps domains` /
`pensar apps domain-create <domain>` (list and idempotently create workspace
domains, created unverified and without starting recon), and `--transport`
on endpoints (`http`, `grpc`, `grpc_web`, `connect`; defaults to `http`).
Run `pensar upgrade` and check `pensar apps --help` — **the CLI's own help is
the source of truth**, and this skill's tables are a summary of it.

## Reading the JSON

```jsonc
// apps
{ "id", "name", "type", "framework", "workspaceId", "domainId", "domainUrl", "createdAt",
  "description", "disallowedActions" }        // last two: detail only

// endpoints
{ "id", "endpoint", "transport", "type", "applicationId", "location",
  "riskScore",        // 0–10, computed, read-only
  "authRequired", "createdAt",
  // detail only:
  "description", "objectives", "startLineNumber", "endLineNumber",
  "authenticationRequired": { "required", "details" },
  "riskScoreBreakdown": { "score", "explanation",
    "breakdown": { "exposure", "dataSensitivity", "functionCriticality", "securityIndicators" } },
  "businessLogic", "threatModel" }
```

## Troubleshooting

| Problem | Fix |
|---|---|
| `Your Pensar Console session has expired` | `pensar login` again |
| Commands act on the wrong workspace | `pensar login status`; re-run `pensar login` to switch |
| `409 An endpoint with this path and transport already exists` | Real duplicate — merge the two records and delete the leftover, don't rename the path |
| Endpoint has no `objectives` in output | You read a list response; use `pensar apps endpoint <endpointId>` |
| An objective you added wiped the others | `--objective` replaces the list — re-send all of them |
| `No update fields provided` (400) | The update had no recognized flags; check spelling against `--help` |
| `Invalid --type "..."` | Error lists the valid values; pick one |
| Deleted an app and lost its endpoints | Not recoverable — always move endpoints out before deleting |
| Only some records changed in a bulk edit | You stopped at page one; page until `hasMore` is `false` |
| `--transport` or `apps domains` unrecognized | Canary-only; `pensar upgrade` |
