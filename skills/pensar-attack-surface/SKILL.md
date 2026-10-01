---
name: pensar-attack-surface
description: >-
  Curate a Pensar workspace's attack surface through the Pensar CLI or MCP
  server: review what recon discovered, consolidate duplicate applications,
  move endpoints between apps, rewrite testing objectives and threat models,
  and add apps or endpoints recon missed. Use when the user says the attack
  surface is wrong, messy, duplicated, or incomplete, or wants to clean up their
  workspace, applications, endpoints, or scan objectives before a pentest.
metadata:
  author: pensarai
  version: "1.1"
---

# Curating the Pensar Attack Surface

Recon builds a workspace attack surface: **applications** that each own
**endpoints**. Pentests run off that model, so a wrong shape means testing the
wrong things. Recon is a first draft: it over-splits apps across hosts,
misfiles routes, misses internal services and writes generic objectives.

For running pentests and triaging findings, use `pensar-security`.

## Pick the interface

Use whichever Pensar interface is available: the `pensar` CLI or a Pensar MCP
server. Learn its real operations from `pensar --help` / `pensar apps --help`
or the MCP tool schemas. Do not invent commands, tools or flags, and do not
assume the two interfaces support the same operations. If the one you have
cannot do a step, say so and offer the other. A compact CLI summary is at the
end of this file.

Confirm the active workspace before anything else, and tell the user which
workspace you are about to change.

## What matters

- **Read fully before writing.** Page through every list until there are no
  more results. Objectives and other detail fields are often missing from list
  responses; read the endpoint detail before concluding anything is empty.
- **Know the write semantics.** Updates are usually sparse, but where an
  objective list is sent it typically replaces the whole list: read the
  current objectives and send the full intended set. Endpoints belong to one
  app, and identity is path plus transport within that app, so moves can
  collide. A collision is not proof two records behave the same; compare them
  before merging any context, and never rename to a fake path.
- **Deleting an app deletes its endpoints.** Consolidate by keeping one app,
  moving endpoints over, confirming the duplicates are empty, then deleting.
  Snapshot endpoint IDs first rather than paging a list that is shrinking.
- **Confirm bulk or destructive changes** with the user before running them.
- **Risk scores are computed, not curated.** The known curation CLI cannot
  set them; check what your interface supports. Metadata edits alone do not
  trigger scoring.
- **No automatic pentest.** Curation does not authorize a scan. Dispatch only
  when the user asks; it costs real compute.

## Writing good context

Objectives are the pentest agent's per-endpoint instructions, and the most
underused lever. Make them specific attacks reachable from that endpoint
(for example, an ownership bypass on an ID parameter rather than "check
authorization"), with the accounts, action and observable outcome needed.
Business logic covers actors, ownership rules and state changes; the threat
model covers what would hurt. Fix auth metadata while there, and set
disallowed actions on apps touching production, payments or destructive
operations. Preserve useful existing context and avoid boilerplate.

## CLI quick reference

Scoped to the workspace from `pensar login`; check `pensar login status`. The
CLI's own `--help` is the source of truth.

| Command | Use |
|---|---|
| `pensar apps [--limit --offset]` | List apps |
| `pensar apps get <appId>` | App detail |
| `pensar apps create` / `update <appId>` / `delete <appId>` | Manage apps (delete cascades) |
| `pensar apps endpoints <appId>` | List endpoints (no objectives) |
| `pensar apps endpoint <endpointId>` | Endpoint detail with objectives |
| `pensar apps endpoint-create <appId>` | Add an endpoint |
| `pensar apps endpoint-update <endpointId> [--app <id>]` | Edit fields or move |
| `pensar apps endpoint-delete <endpointId>` | Delete one endpoint |
| `pensar apps search` / `search-endpoints <query>` | Find records |

Lists return `hasMore`, `limit`, `offset`. Each `--objective` set replaces
the endpoint's list. A 409 on create or move means the path and transport
already exist in that app.
