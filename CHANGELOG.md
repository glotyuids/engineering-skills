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
- README: an agent-followable **update** procedure for bringing installed packs up to the
  library's current versions, built on the IN SYNC / STALE / MODIFIED / ORPHAN verdicts of
  `check-drift.sh`; hand-edited copies are never overwritten.
- Project templates: `AGENTS.template.md`, `CLAUDE.md`, `docs/` tree with ADR, runbook and
  postmortem templates, `Makefile`, `.secrets.example`, `.gitignore`.

### Changed

- `llm/llm-pipeline-rules` 0.1.1 → 0.1.2: the idempotency header goes on the wire only to a
  provider that documents it, because HTTP transports retry on it beneath the retry budget;
  the alias map may be admitted state rather than configuration; golden-set gates rely on
  executable scorers, and skipped judge rows are recorded, never passed.
- `process/security-guidelines` 0.1.0 → 0.1.1: identities asserted by a channel are bound to
  a principal by a recorded admit step, never believed; a token a third-party API forces into
  the URL path is contained by a client wrapper that never exposes the URL, wraps errors and
  refuses redirects.
- `process/integration-testing` 0.1.1 → 0.1.2: a single-principal product separates the
  instance instead of the identity; the delta states that the test identity is the owner.
- `go/go-conventions` 0.1.1 → 0.1.2: an approved secret path where the init system cannot
  carry one — `<NAME>_FILE` owner-only files or password-free DSNs.
- `go/api-and-events` 0.1.1 → 0.1.2: idempotency for polled feeds — update-id deduplication
  in the effect's transaction, derived downstream keys, single-use nonces.
- `go/observability-and-quality` 0.1.1 → 0.1.2: readiness without an orchestrator lists every
  loop and why a disabled one is off; refusal and parser messages never echo the content
  they rejected; the bounded wait that proves absence is the named exception to no-sleep;
  the gosec table moved to `references/gosec-patterns.md` and now covers G302, G703 and G704.
- `database/postgres-patterns` 0.1.1 → 0.1.2: tables are classified as source of truth,
  rebuildable projection or operational state; operational rows (processed ids, nonces,
  outbox, leases) live apart from projections and survive a rebuild.
- `database/database-migrations` 0.1.1 → 0.1.2: a lower-numbered migration merged later is
  silently skipped, so parallel branches take the next free number at merge, never a reserved
  range; a self-migrating service gets two roles and a tracker grant for readiness.
- `go/go-conventions` 0.1.0 → 0.1.1: the composition root may be a `New(deps)` package shared
  by `main` and tests; engine packages (interpreters, compilers) are a leaf layer with their
  own diagnostics; `domain` may import transport-free generated contract types when the
  contract is the record; `api/contracts/` for record-and-event schemas; library rows for
  YAML, CEL and protovalidate with their current module paths and the `tool` directive;
  data ownership generalised from `user_id` to the project's owner column; configuration
  split into deployment wiring (environment) and authority-bearing policy (data with
  provenance); a shared-module gate for several authors.
- `go/new-microservice` 0.1.0 → 0.1.1: owner column generalised from `user_id`, and the
  row-security block made re-runnable, matching `go-conventions` §6 and
  `database-migrations` §3.
- `go/api-and-events` 0.1.0 → 0.1.1: open versus closed contracts (tolerate versus reject
  unknown fields); the envelope field names demoted to an illustration; the proto3 JSON
  traps (64-bit integers as strings, `null` equals absent).
- `go/observability-and-quality` 0.1.0 → 0.1.1: approved patterns and a pre-approved
  suppression for gosec G204/G304 on CLIs and test infrastructure; verbatim assertion where
  a diagnostic's text is the contract; what the `recover()` rule requires before metrics
  exist and inside libraries.
- `database/postgres-patterns` 0.1.0 → 0.1.1: integer minor units accepted for money;
  `created_at DEFAULT now()` conditional on the database clock being the truth; the plan
  check scoped to request paths and growing tables; a gapless per-owner sequence already
  serialises that owner's writers, which limits where `SKIP LOCKED` helps; enumerating
  owners under forced row security through a directory table, with the `SECURITY DEFINER`
  caveat; the §8 diagnostic queries moved to `references/diagnostics.md`.
- `database/database-migrations` 0.1.0 → 0.1.1: drop-then-create for policies, since no
  `IF NOT EXISTS` form exists in any release; cluster-wide roles — provisioned with the
  database by default, otherwise a duplicate-object-guarded block, and a note that advisory
  locks are local to one database.
- `agents/database-reviewer`: money row aligned (`numeric` or integer minor units).
- `process/integration-testing` 0.1.0 → 0.1.1: new §11 for ephemeral, test-owned
  dependencies on the default path — template-cloned per-test databases, one cluster per
  test binary, the macOS socket-path limit — which fail rather than skip; "skip, do not
  fail" narrowed to the shared-environment gate; triage rows, definition of done and
  project delta extended.
- `llm/llm-pipeline-rules` 0.1.0 → 0.1.1: structured-output repair is a bounded, declared
  count (default one) instead of exactly one retry; the idempotency key may be run id +
  step id + attempt in a durable run, with the prompt hash stored alongside and replay
  refused on a mismatch.
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

### Fixed

- CI: the secret scan diffs the pushed commit range, which a shallow checkout cannot
  resolve; the checkout now fetches full history.
- Default branch renamed `master` → `main`. The README install procedure and the manifest
  schema `$id` already pointed at `main`, so both raw-file URLs now resolve; CI triggers on
  `main`.
