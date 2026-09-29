# Bulk updates and recovery

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

## Backup before writes

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

Read affected details again and compare the complete inventory with the backup.
Check desired fields and fields meant to be preserved, especially endpoint IDs,
paths, transport, application ownership, auth, domain links and risk scores.
Account for server-maintained timestamps. Report exact completion and unresolved
items; update preview/status artifacts to distinguish proposed from applied.

For a reusable runner, exercise failure cases with a fake CLI: drift, pagination,
identity collisions, partial failures, ambiguous responses, resume and enforced
field scope. Do not use live workspace writes to test runner behavior.
