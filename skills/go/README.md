# Pack: Go microservices

Writing and shipping clean-architecture Go services: internal layout, the dependency rule, data ownership, error handling, API and event contracts, observability, and the end-to-end procedure for standing up a new service.

## Skills

- [`go-conventions`](go-conventions/SKILL.md)
- [`new-microservice`](new-microservice/SKILL.md)
- [`api-and-events`](api-and-events/SKILL.md)
- [`observability-and-quality`](observability-and-quality/SKILL.md)

## Agents

- [`go-reviewer`](../../agents/go/go-reviewer.md)
- [`go-build-resolver`](../../agents/go/go-build-resolver.md)
- [`silent-failure-hunter`](../../agents/go/silent-failure-hunter.md)

Installed for tools that support subagents (Claude Code, Cursor). Skipped silently elsewhere.

## Expects

Nothing hard. `new-microservice` covers the deployment wiring at the level of capabilities and defers detail to the infra and cloud packs when they are installed.

## Soft companions

`infra`, `database` — companions are suggestions, not requirements. Every skill here works with the
companion pack absent; cross-pack references are written to degrade gracefully.

## Notes

Pairs well with `infra` + a cloud pack (deployment) and `database` (storage). Each is optional.

---

Install: `/plugin install go@engineering-skills`, or
`./scripts/install.sh <project> --packs go`, or ask your agent to install the
**go** pack from `glotyuids/engineering-skills`.
