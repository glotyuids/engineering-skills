---
name: bootstrap-project
description: Set up a repository so coding agents work well in it — create AGENTS.md with a filled project-context block, the CLAUDE.md pointer, the docs/ tree with ADR, runbook and postmortem templates, a root Makefile, the secrets contract and .gitignore, and record which skill packs are installed. Use when starting a new repository, when asked to "bootstrap this project", "set up agent instructions", "initialise the docs structure", "add AGENTS.md", "onboard this repo to the skills library", or when an existing repo has no agent guide at all.
license: Apache-2.0
metadata:
  source: glotyuids/engineering-skills
  version: 0.1.0
---

# Bootstrap a project

Turns a blank or unconfigured repository into one where every agent — Claude Code, Codex,
Cursor, Copilot, Gemini, Lovable — reads the same instructions and finds the same
structure.

**This skill sets up the always-on layer and the document tree only.** It does not write
application code, choose a framework, or provision anything.

Run it once per repository. Re-running is safe: it never overwrites a file that already
exists, it only reports what is missing.

## Phase 1 — Read the ground truth

Do not ask the user anything you can determine yourself.

- [ ] List the repository root. Note existing `AGENTS.md`, `CLAUDE.md`, `README.md`,
      `Makefile`, `docs/`, `.claude/`, `.cursor/`, `.agents/`.
- [ ] Identify the language(s) from manifest files present (`go.mod`, `package.json`,
      `pyproject.toml`, `Cargo.toml`, …) and the layout.
- [ ] Identify the runtime and deployment approach from what exists (`Dockerfile`,
      `infra/`, chart directories, CI config). If nothing exists, that is the answer:
      nothing is deployed yet.
- [ ] Check `git remote -v` and the default branch.
- [ ] Read `README.md` if present — it usually states what the project is.

## Phase 2 — Ask only what remains

Ask **all** remaining questions in one message, with your best guess pre-filled so the
user can confirm rather than compose. Never drip-feed questions.

Typical remainder: what the project is in one sentence; which cloud (or none); the cluster
context and namespace if deployed; the module or package prefix; which skill packs to
install.

If the user is unavailable or says "just do it", proceed with your inferences and mark
every uncertain value `TODO` in the output. Never invent a cluster name, namespace or
registry — a wrong value is worse than `TODO`.

## Phase 3 — Instantiate

Copy from the library's `templates/` directory. **Never overwrite an existing file** —
if one exists, leave it and note it in the report.

- [ ] `AGENTS.md` from `templates/AGENTS.template.md`, with the project-context table
      filled from Phases 1–2 and `<PROJECT>` replaced. Leave `TODO` where unknown.
- [ ] `CLAUDE.md` containing exactly `@AGENTS.md` — nothing else, ever. Two hand-maintained
      copies of the same rules always diverge, and the divergence is silent.
- [ ] `docs/README.md`, `docs/adr/0000-template.md`,
      `docs/runbooks/0000-runbook-template.md`,
      `docs/postmortems/0000-postmortem-template.md`.
- [ ] `KNOWN_ISSUES.md` from `templates/KNOWN_ISSUES.md`.
- [ ] `.gitignore` — merge the template's entries into an existing file rather than
      replacing it. The secret and tool-state entries are the point.
- [ ] `.secrets.example` from `templates/.secrets.example`, if the project has any secrets.
- [ ] `Makefile` from `templates/Makefile`, adapted to the detected language, **only if
      there is no Makefile**. If one exists, check it against the target contract
      (`help build test lint fmt check`) and report gaps rather than editing it.
- [ ] `ARCHITECTURE.md` — a short index that names its canonical chapters under
      `docs/architecture/`, not a copy of them.

## Phase 4 — Record what is installed

In `AGENTS.md`:

- [ ] A `Packs:` line listing the installed packs and their source.
- [ ] References to **installed packs only**. Never mention a skill that is not present —
      a dangling reference sends the next agent looking for a file that does not exist.
- [ ] For each installed skill, read its `## Project delta` section and make sure the
      project-context table answers it.

## Phase 5 — Verify and report

- [ ] `CLAUDE.md` contains only the import line.
- [ ] No secret values were written anywhere. The contract file has key names and
      generation commands only.
- [ ] Every path referenced in `AGENTS.md` exists.
- [ ] `make help` runs, if a Makefile was created.

Report, in this order: files created; files that already existed and were left alone;
every `TODO` left in the project-context table and who needs to answer it; each installed
skill's unmet `Project delta` fields; and the single next action.

## Rules

- **Never overwrite.** An existing file is a decision someone made.
- **Never invent infrastructure identifiers.** `TODO` is always better than a plausible
  wrong cluster name.
- **Do not copy skill content into `AGENTS.md`.** It is an index and a delta, not a
  summary. Skills are installed, not transcribed.
- **Do not create empty directories** to look complete. Add `docs/architecture/` when
  there is a chapter to put in it.
- If the repository already has a working convention that differs from the templates,
  keep the repository's convention and note the difference. This skill adapts to a repo;
  it does not convert one.

## Project delta

This skill needs nothing pre-supplied — establishing the delta is its whole purpose. It
writes these values into `AGENTS.md` for every other installed skill to read: what the
project is, primary language, cloud, runtime, cluster context, namespace, module prefix,
registry, secret manager, chart location, deploy entrypoint, and installed packs.
