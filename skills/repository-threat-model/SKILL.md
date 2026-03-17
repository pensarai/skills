---
name: repository-threat-model
description: Analyze a repository's architecture and codebase to produce a structured threat model. Use when the user wants to identify security risks, create a threat model, assess attack surface, enumerate threats, or document security concerns for their project. Creates a THREAT_MODEL.md in the .pensar folder.
---

# Repository Threat Model

Analyze the repository's architecture, data flows, trust boundaries, and external integrations to produce a comprehensive threat model. The output is a `.pensar/THREAT_MODEL.md` file that documents assets, threat actors, attack surfaces, identified threats (using STRIDE), risk ratings, and recommended mitigations.

## Workflow

Copy this checklist and track progress:

```
Task Progress:
- [ ] Step 1: Analyze the codebase
- [ ] Step 2: Identify assets and trust boundaries
- [ ] Step 3: Map attack surfaces
- [ ] Step 4: Enumerate threats using STRIDE
- [ ] Step 5: Assess risk and prioritize
- [ ] Step 6: Write .pensar/THREAT_MODEL.md
```

### Step 1: Analyze the Codebase

Explore the repository thoroughly to build a mental model of the system. Gather:

- **Tech stack**: Languages, frameworks, runtimes (e.g., Node/Express, Python/Django, Go/Gin)
- **Architecture style**: Monolith, microservices, serverless, static site, CLI tool, library
- **Entry points**: HTTP/REST/GraphQL APIs, WebSocket endpoints, CLI commands, message queue consumers, cron jobs, webhook handlers
- **Authentication & authorization**: Auth mechanisms (JWT, sessions, OAuth, API keys), RBAC/ABAC, middleware/guards
- **Data stores**: Databases (SQL/NoSQL), caches (Redis, Memcached), file storage (S3, local disk), search indices
- **Sensitive data**: PII, credentials, tokens, payment info, health data — look at models/schemas, .env files, config
- **External integrations**: Third-party APIs, payment processors, email/SMS providers, analytics, CDNs, OAuth providers
- **Infrastructure hints**: Dockerfiles, Kubernetes manifests, Terraform/CloudFormation, CI/CD configs, cloud provider references
- **Existing security measures**: Input validation, rate limiting, CORS config, CSP headers, encryption at rest/in transit, dependency scanning

**Where to look:**

| What | Where to check |
|------|---------------|
| Entry points | Route definitions, controller files, `main.*`, `app.*`, `server.*`, API directories |
| Auth | Middleware folders, auth modules, passport/guard configs, JWT utilities |
| Data models | ORM models, schema files, migration directories, GraphQL type definitions |
| Secrets | `.env.example`, `.env.sample`, config files, secret manager references, `process.env` / `os.environ` usage |
| External calls | HTTP client usage (`fetch`, `axios`, `requests`, `http.Client`), SDK imports |
| Infra | `Dockerfile`, `docker-compose.yml`, `*.tf`, `*.yaml` in deploy/infra directories, CI configs |
| Dependencies | `package.json`, `requirements.txt`, `go.mod`, `Gemfile`, `Cargo.toml` — note security-sensitive packages |

### Step 2: Identify Assets and Trust Boundaries

Based on the analysis, identify:

**Assets** — things of value that need protection:
- User data (profiles, credentials, PII)
- Application secrets (API keys, DB credentials, signing keys)
- Business data (transactions, content, analytics)
- System resources (compute, storage, network)
- Source code and intellectual property

**Trust boundaries** — lines where the level of trust changes:
- Client ↔ Server (browser/mobile app to backend)
- Server ↔ Database (application to data store)
- Server ↔ External API (your service to third-party)
- Public network ↔ Internal network
- User roles (anonymous → authenticated → admin)
- Service ↔ Service (inter-service communication)

Draw these as a simple text diagram if the architecture is complex enough to warrant it.

### Step 3: Map Attack Surfaces

For each entry point and trust boundary, document the attack surface:

- **Network-exposed endpoints**: Every route/path the application serves, especially unauthenticated ones
- **Input vectors**: Request bodies, query parameters, headers, file uploads, WebSocket messages
- **Authentication surfaces**: Login, registration, password reset, token refresh, OAuth callbacks
- **Data egress points**: API responses, exports, logs, error messages that might leak info
- **Administrative interfaces**: Admin panels, debug endpoints, management APIs, database admin tools
- **Dependency surface**: Third-party packages with known vulnerability patterns, native modules
- **Infrastructure surface**: Exposed ports, default credentials, debug modes, verbose error pages

### Step 4: Enumerate Threats Using STRIDE

For each significant attack surface, apply the STRIDE model to systematically identify threats:

| Category | Question to ask |
|----------|----------------|
| **S**poofing | Can an attacker impersonate a user, service, or component? |
| **T**ampering | Can an attacker modify data in transit, at rest, or in processing? |
| **R**epudiation | Can actions be performed without adequate logging/audit trails? |
| **I**nformation Disclosure | Can sensitive data leak through errors, logs, APIs, or side channels? |
| **D**enial of Service | Can an attacker exhaust resources or make the service unavailable? |
| **E**levation of Privilege | Can an attacker gain unauthorized access to higher-privilege operations? |

**Focus on concrete, codebase-specific threats**, not generic ones. Reference actual files, routes, or patterns found during analysis. For example:

- "The `/api/users/:id` endpoint does not verify the authenticated user owns the requested resource (IDOR) — see `routes/users.js:45`"
- "JWT secret is hardcoded in `config/auth.ts:12` rather than loaded from environment"
- "File upload at `/api/upload` does not validate file type or size — see `controllers/upload.js`"
- "SQL queries in `models/search.js` use string concatenation instead of parameterized queries"

### Step 5: Assess Risk and Prioritize

Rate each identified threat using a simple risk matrix:

**Likelihood**: How easy is it to exploit?
- **High**: Requires no special access or knowledge; automated tools exist
- **Medium**: Requires some knowledge, authenticated access, or specific conditions
- **Low**: Requires deep system knowledge, insider access, or rare conditions

**Impact**: What's the damage if exploited?
- **Critical**: Full system compromise, mass data breach, financial loss
- **High**: Significant data exposure, service takeover, major functionality loss
- **Medium**: Limited data exposure, partial service disruption, single-user impact
- **Low**: Minimal data exposure, cosmetic issues, negligible business impact

**Risk rating**: Combine likelihood and impact:

| | Impact: Critical | Impact: High | Impact: Medium | Impact: Low |
|---|---|---|---|---|
| **Likelihood: High** | Critical | Critical | High | Medium |
| **Likelihood: Medium** | Critical | High | Medium | Low |
| **Likelihood: Low** | High | Medium | Low | Low |

For each threat, also note a recommended mitigation — be specific and actionable, referencing libraries, patterns, or code changes.

### Step 6: Write .pensar/THREAT_MODEL.md

Create the `.pensar` directory if it doesn't exist, then write `.pensar/THREAT_MODEL.md` with the following structure:

```markdown
# Threat Model

> Auto-generated threat model for [repository name]. Last updated: [date].

## System Overview

[2-3 paragraph summary of the application: what it does, its architecture, tech stack, and deployment model]

### Architecture Diagram

\`\`\`
[Simple text/ASCII diagram showing major components, data flows, and trust boundaries]
\`\`\`

## Assets

| Asset | Description | Sensitivity |
|-------|-------------|-------------|
| [e.g., User credentials] | [What it is] | [Critical/High/Medium/Low] |

## Trust Boundaries

| Boundary | From | To | Controls |
|----------|------|----|----------|
| [e.g., API Gateway] | [Public internet] | [App server] | [TLS, rate limiting] |

## Attack Surfaces

| Surface | Entry Point | Auth Required | Data Exposed |
|---------|-------------|---------------|--------------|
| [e.g., REST API] | [/api/*] | [Mixed] | [User data, app data] |

## STRIDE Analysis

### Spoofing

| ID | Threat | Affected Component | Risk | Mitigation |
|----|--------|--------------------|------|------------|
| S-1 | [Description] | [File/component] | [Critical/High/Medium/Low] | [Specific fix] |

### Tampering

| ID | Threat | Affected Component | Risk | Mitigation |
|----|--------|--------------------|------|------------|
| T-1 | [Description] | [File/component] | [Critical/High/Medium/Low] | [Specific fix] |

### Repudiation

| ID | Threat | Affected Component | Risk | Mitigation |
|----|--------|--------------------|------|------------|
| R-1 | [Description] | [File/component] | [Critical/High/Medium/Low] | [Specific fix] |

### Information Disclosure

| ID | Threat | Affected Component | Risk | Mitigation |
|----|--------|--------------------|------|------------|
| I-1 | [Description] | [File/component] | [Critical/High/Medium/Low] | [Specific fix] |

### Denial of Service

| ID | Threat | Affected Component | Risk | Mitigation |
|----|--------|--------------------|------|------------|
| D-1 | [Description] | [File/component] | [Critical/High/Medium/Low] | [Specific fix] |

### Elevation of Privilege

| ID | Threat | Affected Component | Risk | Mitigation |
|----|--------|--------------------|------|------------|
| E-1 | [Description] | [File/component] | [Critical/High/Medium/Low] | [Specific fix] |

## Risk Summary

| Risk Level | Count | IDs |
|------------|-------|-----|
| Critical   | [n]   | [list] |
| High       | [n]   | [list] |
| Medium     | [n]   | [list] |
| Low        | [n]   | [list] |

## Methodology

This threat model was generated by analyzing the repository structure, source code, configuration files, and dependencies. Threats were identified using the [STRIDE](https://en.wikipedia.org/wiki/STRIDE_%28security%29) framework and assessed using a likelihood × impact risk matrix.
```

**Important guidelines for the output:**

- Be specific to the codebase — reference actual files, routes, and code patterns
- Don't include generic/boilerplate threats that don't apply to this specific project
- If a STRIDE category has no relevant threats, include the section header with a note that no significant threats were identified in that category
- Keep mitigations actionable — name specific libraries, configuration changes, or code patterns
- The threat model should be useful for developers, not just security auditors

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Repository is too large to fully analyze | Focus on entry points (routes, controllers, API handlers), auth modules, and data access layers first. Expand from there. |
| Cannot determine the tech stack | Check dependency manifests (`package.json`, `requirements.txt`, etc.), file extensions, and import statements |
| No clear entry points found | Look for `main` functions, `app.*` files, `server.*` files, route registrations, or framework-specific patterns (e.g., `@app.route` in Flask, `router.get` in Express) |
| Project is a library, not an application | Focus on: input validation of public API, dependency risks, potential for prototype pollution / injection if processing user data, and documentation of security considerations for consumers |
| `.pensar` directory conflicts with existing files | Check if `.pensar` already exists; if so, update the existing `THREAT_MODEL.md` rather than overwriting other files in the directory |
