# Changelog

All notable changes to this library. Versions follow the library `version` in
`manifest.json`; individual skills carry their own `metadata.version`.

## [Unreleased]

### Added

- Initial library: `core`, `process`, `infra`, `cloud-yandex`, `go`, `database`,
  `frontend`, `llm`, `writing`, `lang-ru` packs.
- Three-layer skill model (generic → cloud vendor → project delta) with a capability
  contract shared by `infra` and `cloud-*` packs.
- Agent-driven install procedure in README, `manifest.json` pack index, `install.sh`,
  `check-drift.sh`, `validate.sh`.
- Project templates: `AGENTS.template.md`, `CLAUDE.md`, `docs/` tree with ADR, runbook and
  postmortem templates, `Makefile`, `.secrets.example`, `.gitignore`.

### Changed

- `process/kanban-md` 0.1.0 → 0.1.1: distinguished durable author/owner from active agent
  claims, added attributed multi-agent handoffs and claim recovery, and replaced an unverified
  cross-process atomicity assumption with serialized board writes after reproducing duplicate
  claims in CLI 0.36.1. Documented dependency-ID validation and the coordinator/worker protocol.
- `frontend/react-conventions` 0.1.0 → 0.1.1: added the missing "Forms" section (controlled
  inputs, validation timing, submit-in-flight guarding, field-level server errors,
  labelling) that the skill's description already promised; sections renumbered accordingly.
- `lang-ru/ru-ui-strings` 0.1.0 → 0.1.1: the worked example is now an invented carpooling
  app throughout (glossary, plural tables, enum-agreement and casing examples); same
  grammar, no real-product domain.
- `process/documentation-standards` 0.1.0 → 0.1.1: the `Relates to:` illustration now uses
  arbitrary ADR numbers.
- `scripts/validate.py`: patterns that are themselves private (project names, namespaces)
  moved out of the public source into git-ignored `scripts/private-patterns.txt`, loaded
  when present. CI keeps every generic check.
