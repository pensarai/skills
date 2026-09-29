# Source-grounded attack-surface context

## Reconcile coverage before adding records

Record the source revision or archive identifier in the private audit artifacts.
Trace router registration and mount prefixes, client base URLs and generated
route definitions. Distinguish active pages, API handlers, public widgets,
redirects, layouts and retired routes. Search every application for existing
records before proposing additions. Count method/path registrations separately
from unique platform identities: application, path and transport. Do not invent
paths to represent multiple HTTP methods; describe method-specific behavior.

Treat source availability, deployment and reachability as separate facts. A
source route is not proof that the current deployment exposes it. A failed
recon discovery does not prove a route is absent. Keep uncertain items explicit.

## Build each record from evidence

Read the handler or page, actual authorization dependencies, shared base
classes, relevant service calls and tests where available. Record file/line
references and the source revision in the review artifact. Check that cited
files and lines exist, but separately verify that they support the claim.
Reading tests is not the same as running them.

- **Business logic:** actors, accepted inputs, resource ownership or capability
  rules, read/write behavior, state transitions, side effects and invariants.
- **Threat model:** assets, entry points, trust boundaries, attacker access,
  abuse hypotheses and consequences. Hypotheses are not confirmed findings.
- **Objectives:** required accounts/fixtures, the precise action, a positive
  control and the observable outcome. Include prerequisite state and cleanup
  or mocked providers where relevant. Do not prescribe real external sends,
  paid calls or destructive actions merely to test a hypothesis.

Preserve useful existing context. Reuse descriptions only where behavior is
actually shared, then add method- and action-specific differences. Do not
optimize for length or inflate every endpoint with the same security checklist.
For uncertain policy, ask the tester to establish intended behavior and compare
it with observed behavior rather than assert an unsupported expected denial.

## Semantic review

For substantial batches, independently recheck representative high-impact
records and shared assumptions. Document review scope; sampling is not an
exhaustive review. If one shared template is wrong, inspect every record using
it. Particularly check:

- UI gating versus server authorization; staff versus organization roles;
  intentional cross-organization access versus unintended disclosure.
- Public capability links versus authenticated ownership checks; token expiry,
  clock-skew allowances, replay rules and claim types.
- Guards conditional on supplied fields, omitted versus null values, enum
  casing, normalization and partial-update semantics.
- Shared base-class behavior only where the handler actually inherits it;
  missing explicit middleware at one layer is not proof of missing protection.
- Redirect origin validation versus full-URL validation, and normalization
  before checking a destination.
- Read/preview actions that create records, refresh credentials, contact
  providers or change state; cancellation may be cooperative rather than final.

Keep customer evidence in the engagement's private artifacts. Reusable skills,
examples, commits and PR descriptions must contain only generic workflow
lessons, never customer names, hosts, IDs, routes, code excerpts or counts.
