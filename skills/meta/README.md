# Pack: Core

Bootstrap a repository and get the language-neutral planning and review agents.

## Skills

- [`bootstrap-project`](bootstrap-project/SKILL.md)

## Agents

- [`architect`](../../agents/core/architect.md)
- [`planner`](../../agents/core/planner.md)
- [`code-explorer`](../../agents/core/code-explorer.md)
- [`code-reviewer`](../../agents/core/code-reviewer.md)
- [`security-reviewer`](../../agents/core/security-reviewer.md)

Installed for tools that support subagents (Claude Code, Cursor). Skipped silently elsewhere.

## Expects

Nothing. This pack is the sensible starting point for any repository.

## Soft companions

none — companions are suggestions, not requirements. Every skill here works with the
companion pack absent; cross-pack references are written to degrade gracefully.

## Notes

The agents assume nothing about your stack. `code-reviewer` defers to a language-specific reviewer when one is installed, and otherwise reviews on general principles.

---

Install: `/plugin install core@engineering-skills`, or
`./scripts/install.sh <project> --packs core`, or ask your agent to install the
**core** pack from `glotyuids/engineering-skills`.
