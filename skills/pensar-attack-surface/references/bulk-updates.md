# Bulk updates and recovery

## Choose an execution style

If the user has not already chosen, ask once: "Would you prefer a reviewable
batch script or incremental edits as we work through the findings?" Explain
briefly that a script helps review and resume large/repetitive changes, while
incremental edits suit a small number of exploratory corrections. Keep doing
read-only analysis while waiting. Do not require a script for every curation
task or reopen a preference already established in the conversation.

For incremental work, describe each bounded change or group, retain its before
values, and apply within the user's authorized scope using the CLI. Read it
back before moving on, and keep a concise change log. Backups are on by default
here too; the user can opt out in ordinary language. For a sequence of edits,
one complete backup before the first write can cover that scope; back up newly
included records before editing them. Do not keep asking about backups or
permission for individual records already covered by approval. If the work
grows, offer a script without silently changing the agreed workflow.

The manifest, runner arguments and resumability requirements below apply to
scripted batches. Workspace checks, scope review, conflict detection, backup
policy and readback verification apply to both execution styles.

## Prepare a reviewable batch

Use a manifest with workspace name and UUID, stable operation keys, endpoint
IDs, identity, old values, new values, evidence and deferred items. Scope the
write fields explicitly. Separate metadata enrichment from path corrections,
moves, creates and deletes so approval and verification are unambiguous.
Provide a before/after preview; keep credentials out of artifacts and logs.

A runner should default to an offline preview, provide a read-only preflight,
and require an explicit apply mode. Inspect every page before mutations;
never paginate a shrinking source collection while moving records out of it.
Check both workspace name and UUID rather than trusting the active login alone.

## Backup policy: on by default, explicit opt-out

For a generated batch runner, make backup creation the default for apply mode.
Offer `--no-backup` to skip the recovery export and optionally `--backup-dir`
to select its destination. These are suggested **runner arguments**, not
existing `pensar` CLI flags. Show the policy and destination in the preview.
Do not add a separate backup confirmation prompt: proceed with the default
unless the user has explicitly opted out, including in ordinary conversation.
Do not select `--no-backup` on the user's behalf to save time or bypass an error.

When backups are enabled, a failed or incomplete export must stop the run
before any write. Do not silently fall back to no backup. An explicit opt-out
skips only the recovery export: retain preflight reads, old-value checks,
manifest, journal and readback verification. Record the opt-out in the journal
and completion report; make clear that no full recovery snapshot was created.
The manifest and journal may still contain old field values, so this option
does not mean "retain no data." Preserve the original snapshot when resuming;
any new snapshot must be separate and identified as potentially partially applied.

### Backup contents and limits

Export application details, the complete endpoint inventory and full details
for affected endpoints, including objectives. For broad restructuring, export
all endpoint details. Record timestamps, manifest digest and counts; verify the
backup is parseable, complete and internally consistent. Use repeated reads
when concurrent changes are suspected. An archive checksum proves integrity,
not completeness. Take a fresh apply-time backup even if an earlier export exists.

Be precise about restoration limits. Recreating deleted records may not restore
IDs, history or computed fields. Sparse CLI flags may not express null values
or an empty objective list. Check supported API clearing semantics before
promising an exact inverse. Do not describe a backup as transactional rollback.

## Apply, stop and resume

1. Validate the whole manifest, pagination, target identities, old-value
   preconditions and collisions before the first write.
2. Recheck relevant old values immediately before each mutation. Stop on drift.
3. Journal an operation before writing, then record the returned ID and verify
   by reading the endpoint back. A successful exit alone is insufficient.
4. Stop on a failed or ambiguous write; preserve the journal and report verified,
   pending and uncertain operations. Do not blindly retry creates.
5. On resume, recognize already-applied desired values while still checking
   unchanged identity fields. Require the same manifest and runner digest, or
   explicitly reconcile a changed batch. A timeout may follow a successful write.
6. Use argument arrays rather than shell interpolation. Validate complete JSON;
   if piped output truncates, capture it to a regular file before parsing.

Existing approval covers the reviewed batch and safe resume. New scope needs
review. A batch is not atomic: earlier successful writes remain after a stop.
An inverse update requires checking for subsequent edits so recovery does not
overwrite another user's work.

## Verify completion

Read affected details again and compare the complete inventory with the
preflight baseline and, when enabled, the backup. Without a backup, retain the
baseline in memory during the run; on resume, re-read it and report any limits
on verifying changes from earlier invocations.
Check desired fields and fields meant to be preserved, especially endpoint IDs,
paths, transport, application ownership, auth, domain links and risk scores.
Account for server-maintained timestamps. Report exact completion and unresolved
items; update preview/status artifacts to distinguish proposed from applied.

For a reusable runner, exercise failure cases with a fake CLI: drift, pagination,
identity collisions, backup failure, explicit backup opt-out, partial failures,
ambiguous responses, resume and enforced
field scope. Do not use live workspace writes to test runner behavior.
