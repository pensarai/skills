---
name: dockerize-app
description: Dockerize an application with docker-compose, including all services, databases, and data seeding. Use when the user wants to containerize their app, create a docker-compose setup, set up a reproducible dev environment, or prepare the project for sandbox/agent use.
---

# Dockerize App

Create a tested `docker-compose.yml` that spins up the full application stack — services, databases, seed data — so any developer or agent can run the entire dev environment with a single command.

## Workflow

Copy this checklist and track progress:

```
Task Progress:
- [ ] Step 1: Analyze the codebase
- [ ] Step 2: Create Dockerfiles
- [ ] Step 3: Create docker-compose.yml
- [ ] Step 4: Set up data seeding
- [ ] Step 5: Test the full stack
- [ ] Step 6: Update AGENTS.md
```

### Step 1: Analyze the Codebase

Explore the repository to determine:

- **Services**: What application services exist? (API server, frontend, workers, etc.)
- **Languages/runtimes**: Node, Python, Go, Ruby, etc. — drives Dockerfile base images.
- **Package managers**: npm, yarn, pnpm, pip, poetry, go mod, etc.
- **Databases**: PostgreSQL, MySQL, MongoDB, Redis, etc. Check for ORMs, migration files, connection strings, or `.env` references.
- **Existing Docker artifacts**: Any `Dockerfile`, `docker-compose.yml`, or `.dockerignore` already present.
- **Environment variables**: Check `.env.example`, `.env.sample`, config files, or code references to `process.env` / `os.environ`.
- **Seed data**: Look for seed scripts, fixtures, SQL dumps, or migration files that populate initial data.
- **Inter-service communication**: How do services talk to each other? (HTTP, gRPC, message queues, shared DB)

If the project has an existing `docker-compose.yml`, evaluate whether it needs updating rather than replacing it.

### Step 2: Create Dockerfiles

For each application service that needs one, create a `Dockerfile` in that service's root directory.

**Principles:**
- Use specific version tags for base images (e.g., `node:20-slim`, not `node:latest`)
- Use multi-stage builds when a build step is needed (compiled languages, frontend asset builds)
- Copy dependency manifests first, install, then copy source — maximizes layer caching
- Run as a non-root user in the final stage
- Use `.dockerignore` to exclude `node_modules`, `.git`, `.env`, etc.

**If a Dockerfile already exists**, leave it as-is unless it's broken or clearly outdated.

Create a `.dockerignore` in each service root if one doesn't exist:

```
node_modules
.git
.env
.env.*
*.log
dist
build
.cache
```

Adapt the ignore list to the language/framework.

### Step 3: Create docker-compose.yml

Create `docker-compose.yml` at the repository root.

**Requirements:**
- Every application service gets its own `services:` entry, built from its Dockerfile
- Databases and infrastructure (Postgres, Redis, etc.) use official images with pinned versions
- Use named volumes for database persistence
- Use a shared network so services can communicate by service name
- Map host ports for local access (avoid conflicts with common local services)
- Use `env_file` pointing to `.env` or inline `environment` vars with sensible defaults
- Set `depends_on` with `condition: service_healthy` where health checks are defined
- Add health checks for databases and critical services

**Template structure:**

```yaml
services:
  db:
    image: postgres:16
    environment:
      POSTGRES_USER: ${DB_USER:-app}
      POSTGRES_PASSWORD: ${DB_PASSWORD:-password}
      POSTGRES_DB: ${DB_NAME:-app_dev}
    volumes:
      - db_data:/var/lib/postgresql/data
    ports:
      - "${DB_PORT:-5432}:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER:-app}"]
      interval: 5s
      timeout: 3s
      retries: 5

  app:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "${APP_PORT:-3000}:3000"
    env_file: .env
    depends_on:
      db:
        condition: service_healthy
    volumes:
      - .:/app
      - /app/node_modules

volumes:
  db_data:
```

Adapt this to the actual project — the above is just a starting point for a typical Node + Postgres setup.

### Step 4: Set Up Data Seeding

The goal: after `docker-compose up`, the app is ready to use with realistic sample data.

**Strategy (pick the best fit):**

1. **ORM seeds/migrations exist** → Run them automatically.
   Add a `seed` service or an entrypoint script that waits for the DB, runs migrations, then seeds.

2. **SQL dump available** → Mount it into the DB container's init directory.
   For Postgres: mount `.sql` files into `/docker-entrypoint-initdb.d/`.
   For MySQL: mount into `/docker-entrypoint-initdb.d/`.

3. **No seed data exists** → Create a minimal seed script.
   Write a script that inserts reasonable sample data. Place it in `scripts/seed.sh` or `scripts/seed.sql`.

**Entrypoint pattern for auto-seeding:**

Create a `scripts/docker-entrypoint.sh` for application services that need to run migrations + seeds on startup:

```bash
#!/bin/sh
set -e

echo "Waiting for database..."
# Use wait-for-it, dockerize, or a simple loop
until nc -z db 5432; do sleep 1; done

echo "Running migrations..."
# npm run migrate / python manage.py migrate / etc.

echo "Seeding database..."
# npm run seed / python manage.py seed / etc.

echo "Starting application..."
exec "$@"
```

Make sure the entrypoint is executable and referenced in the Dockerfile or docker-compose `entrypoint`.

### Step 5: Test the Full Stack

Run the stack and verify everything works:

```bash
# Build and start all services
docker compose up --build -d

# Watch logs for errors (wait ~30s for services to stabilize)
docker compose logs --tail=50

# Verify all containers are running/healthy
docker compose ps

# Test the main service endpoint
curl -s http://localhost:${APP_PORT:-3000}/health || curl -s http://localhost:${APP_PORT:-3000}/

# If there's a frontend, check it too
curl -s http://localhost:${FRONTEND_PORT:-5173}/ | head -20
```

**If something fails:**
1. Check `docker compose logs <service>` for the failing service
2. Common issues: missing env vars, port conflicts, DB not ready before app starts
3. Fix and re-run `docker compose up --build -d`
4. Repeat until all services are healthy

Once verified, bring it down cleanly:

```bash
docker compose down
```

### Step 6: Update AGENTS.md

Create or update `AGENTS.md` at the repository root with dev environment instructions. This file tells future agents how to spin up and use the environment.

**If `AGENTS.md` doesn't exist**, create it with this structure:

```markdown
# AGENTS.md

## Dev Environment

### Prerequisites
- Docker and Docker Compose

### Starting the Environment
\`\`\`bash
docker compose up --build -d
\`\`\`

### Services
| Service | URL | Description |
|---------|-----|-------------|
| app     | http://localhost:3000 | Main application |
| db      | localhost:5432 | PostgreSQL database |

### Seeded Data
Describe what sample data is available (users, test accounts, etc.)

### Stopping the Environment
\`\`\`bash
docker compose down        # Stop containers
docker compose down -v     # Stop and remove volumes (reset DB)
\`\`\`
```

**If `AGENTS.md` already exists**, add a `## Dev Environment` section (or update the existing one) with the same information. Do not remove existing content.

Also create a `.env.example` if one doesn't exist, documenting all environment variables used in `docker-compose.yml` with their defaults.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Port already in use | Change the host port mapping in `docker-compose.yml` or set the env var override |
| DB connection refused on startup | Ensure `depends_on` with `condition: service_healthy` is set, or use an entrypoint wait loop |
| Seed script fails | Check if migrations need to run first; ensure the DB is fully ready |
| Permission errors on mounted volumes | Set `user:` in docker-compose or fix file ownership in Dockerfile |
| Container keeps restarting | Check `docker compose logs <service>` — usually a missing env var or failed command |
