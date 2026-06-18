# Skills

Public repository for Pensar Agent Skills.

Skills are folders of instructions, scripts, and resources that agents load dynamically to improve performance on specialized tasks. They teach agents how to complete specific tasks in a repeatable way — whether that's dockerizing an application, setting up CI/CD, or automating common development workflows.

For more information on the Agent Skills standard, see [agentskills.io](https://agentskills.io).

## About This Repository

This repository contains skills built by [Pensar](https://pensar.dev) for use with AI coding agents. Each skill is self-contained in its own folder with a `SKILL.md` file containing the instructions and metadata that agents use.

## Skills

| Skill | Description |
|-------|-------------|
| [pensar-security](skills/pensar-security/) | Security testing and penetration testing with the Pensar Apex CLI — autonomous scanning, targeted tests, operator mode, attack-surface management (apps & endpoints), and Console workspace operations |
| [dockerize-app](skills/dockerize-app/) | Dockerize an application with docker-compose, including all services, databases, data seeding, and AGENTS.md documentation |
| [repository-threat-model](skills/repository-threat-model/) | Analyze a repository's architecture and codebase to produce a STRIDE-based threat model in `.pensar/THREAT_MODEL.md` |

## Repository Structure

```
skills/          # All skills live here
  dockerize-app/ # Each skill is a self-contained folder
    SKILL.md     # Required — main instructions
template/        # Skill template for creating new skills
```

## Install

Install skills with the [skills CLI](https://skills.sh):

```bash
npx skills add pensarai/skills
```

Or install directly into a project's `.cursor/skills/`, `.claude/skills/`, or `.agents/skills/` directory.

## Creating a New Skill

Use the template in [`template/SKILL.template.md`](template/SKILL.template.md) as a starting point. Copy it into a new folder under `skills/` and rename it to `SKILL.md`. A skill only requires a folder with a `SKILL.md` file containing YAML frontmatter and instructions:

```yaml
---
name: my-skill-name
description: A clear description of what this skill does and when to use it
---

# My Skill Name

[Instructions that the agent will follow when this skill is active]
```

The frontmatter requires two fields:

- **name** — Unique identifier (lowercase, hyphens for spaces, max 64 chars)
- **description** — What the skill does and when to use it (max 1024 chars)
