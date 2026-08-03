# Documentation

Source-of-truth chapters rather than scattered notes. If something here disagrees with the
code, that is a bug in one of them — fix it in the same change, not later.

## Start here

- `../ARCHITECTURE.md` — the map. Every claim points at a canonical chapter below.
- `adr/` — binding decisions.
- `CONTINUE.md` — current state of play and the next step.

## Layout

| Directory | Holds | Update when |
|---|---|---|
| `architecture/` | canonical chapters: domain, services, infrastructure | the system shape changes |
| `adr/` | binding decisions, `NNNN-kebab-title.md` | a durable trade-off is settled |
| `runbooks/` | operational procedures, one task per file | an operation is performed twice by hand |
| `postmortems/` | incident write-ups, blameless | after any user-visible incident |
| `specs/` | requirements, test plans, data contracts | a contract is agreed |
| `plans/` | staged plans with definition-of-done, and a progress log | work is planned or a stage completes |
| `product/` | product-facing behaviour, copy, policy | product behaviour changes |

## Routing — where does this change get documented?

| Change | Goes to |
|---|---|
| Product behaviour | `product/` |
| System shape | `architecture/` |
| A durable trade-off | a new ADR |
| API behaviour | the API contract, plus its generated clients |
| An operational step | `runbooks/` |
| Staged work notes | `plans/` |

## Conventions

- ADRs: `NNNN-kebab-title.md` with Status / Date / Context / Decision / Consequences. Title
  is a sentence stating the decision. Amend with dated notes; never rewrite.
- Runbooks: `<verb>-<thing>.md`. Preconditions and a safety model before the first step;
  a rollback section at the end.
- Plans: `<kebab-title>-plan.md` with phases, dependencies and definition-of-done checkboxes.
- Skills: `skills/<name>/SKILL.md`, optional `references/` and `evals/`.
- A document that is a consolidated *reference* says so in its header and names the
  canonical source, so nobody mistakes a stale copy for the truth.
