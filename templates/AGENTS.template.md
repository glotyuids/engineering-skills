# Agent guide — <PROJECT>

Instructions for every coding agent working in this repository (Claude Code, Codex,
Cursor, Copilot, Gemini, Lovable). Claude Code reads this through `CLAUDE.md`, which
contains only `@AGENTS.md` — keep it that way; never maintain two copies of these rules.

## Project context

The installed skills read these values as their "project delta". Fill every line; leave
`TODO` where you genuinely do not know yet rather than guessing.

| Key | Value |
|---|---|
| What this is | TODO — one sentence |
| Primary language(s) | TODO |
| Cloud | TODO — e.g. `yandex-cloud`, or `none` |
| Runtime | TODO — e.g. managed Kubernetes, single VM, serverless |
| Cluster context | TODO — the exact `--context` value, or `n/a` |
| Namespace / environment | TODO |
| Module / package prefix | TODO |
| Registry | TODO |
| Secret manager | TODO |
| Chart / manifest location | TODO |
| Deploy entrypoint | TODO — e.g. `make deploy ENV=prod` |
| Packs installed | TODO — e.g. `infra, cloud-yandex, process` |

## Golden rules

- Build it right — no shortcuts that a later refactor has to undo. Say so when you choose
  duplication to preserve a clean boundary.
- Decisions recorded in `docs/adr/` are binding. Do not relitigate them; add a *new* ADR
  when the decision changes.
- Verify before claiming done: build, test and lint must pass. Report failures with their
  output rather than describing them.
- Never invent facts about the system. If you did not read it or run it, say so.
- Secrets are referenced by key name only. Never paste a secret value into chat, a commit,
  a document, or a tool configuration.
- Update the canonical document in the same change that alters the behaviour it describes.

## Canonical documents

Read these rather than reconstructing their content. Keep this list short — it is an
index, not a summary.

- `README.md` — what the project is and how to run it
- `ARCHITECTURE.md` — the map; canonical chapters live under `docs/architecture/`
- `docs/adr/` — binding decisions
- `docs/runbooks/` — operational procedures
- `KNOWN_ISSUES.md` — honest current state: what is broken, what is authored but inert

## Installed skills

Skills installed from `glotyuids/engineering-skills` cover the shared patterns. This file
carries only what is specific to this repository. Do not copy skill content in here, and
do not hand-edit installed skills — fix them upstream and reinstall.

<!-- The installer lists installed packs here. Reference only packs that are installed. -->

## To continue work

`docs/CONTINUE.md` holds the current state of play and the next step.
