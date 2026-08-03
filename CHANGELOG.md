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

- `frontend/react-conventions` 0.1.0 → 0.1.1: added the missing "Forms" section (controlled
  inputs, validation timing, submit-in-flight guarding, field-level server errors,
  labelling) that the skill's description already promised; sections renumbered accordingly.
