# Pack: LLM engineering

Building on top of language models without the usual failure modes: deterministic orchestration, untrusted input, prompt versioning, MCP servers, and authoring skills that actually trigger.

## Skills

- [`llm-pipeline-rules`](llm-pipeline-rules/SKILL.md)
- [`mcp-server-authoring`](mcp-server-authoring/SKILL.md)
- [`skill-authoring`](skill-authoring/SKILL.md)

## Expects

Nothing.

## Soft companions

none — companions are suggestions, not requirements. Every skill here works with the
companion pack absent; cross-pack references are written to degrade gracefully.

## Notes

`skill-authoring` is the meta-skill: use it to write skills for this library or your own.

---

Install: `/plugin install llm@engineering-skills`, or
`./scripts/install.sh <project> --packs llm`, or ask your agent to install the
**llm** pack from `glotyuids/engineering-skills`.
