# Pack: Database

PostgreSQL schema, query and concurrency patterns, plus migration discipline that survives a failed deploy.

## Skills

- [`postgres-patterns`](postgres-patterns/SKILL.md)
- [`database-migrations`](database-migrations/SKILL.md)

## Agents

- [`database-reviewer`](../../agents/database/database-reviewer.md)

Installed for tools that support subagents (Claude Code, Cursor). Skipped silently elsewhere.

## Expects

Nothing.

## Soft companions

none — companions are suggestions, not requirements. Every skill here works with the
companion pack absent; cross-pack references are written to degrade gracefully.

## Notes

The `database-reviewer` agent in this pack defers to these skills for detail; without them it reviews on general principles.

---

Install: `/plugin install database@engineering-skills`, or
`./scripts/install.sh <project> --packs database`, or ask your agent to install the
**database** pack from `glotyuids/engineering-skills`.
