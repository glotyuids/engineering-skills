---
name: documentation-standards
description: What gets documented, where it lives, and the discipline that keeps documents true — the docs/ tree, the change-type-to-document routing table, the ADR contract (NNNN-kebab-title.md with Status/Date/Context/Decision/Consequences, amended never rewritten), the consolidated-index pattern, the planned/flag-gated/legacy/dropped status markers, the KNOWN_ISSUES honest-status pattern, and the rule that a behaviour change and its canonical-doc edit ship in the same commit. Use when creating or reorganising a docs tree, writing or amending an ADR, deciding where a change gets documented, writing a runbook or postmortem, recording a known gap honestly, auditing docs against code, or reviewing a change for a missing doc edit. Trigger phrases: "write an ADR", "where does this go in docs", "the docs are out of date", "docs drift", "add a runbook", "postmortem", "known issues", "is this shipped or planned", "document this decision".
license: Apache-2.0
metadata:
  source: glotyuids/engineering-skills
  version: 0.1.1
---

# Documentation standards — the tree, the routing, and the truth discipline

**Core rule: a sentence in a canonical document is a claim about what is live today. A
behaviour change and the edit to its canonical document ship in the SAME commit; anything
decided-but-unbuilt carries an explicit status marker.**

Documentation drift is a defect, not untidiness. Every later reader — including a fresh
agent session that is *instructed* to trust the docs — inherits the error, and the cost is
paid in re-discovering reality the repo already knew.

This skill defines only: the documentation tree and what belongs in each part; the routing
of a change to its document; the ADR contract; the status/honesty marker vocabulary; and
the lockstep discipline that keeps documents and code in agreement. It does not define
code comments, generated API reference output, end-user help content, or commit and branch
conventions (the `git-workflow` skill owns those).

## 1. The tree

| Path | Holds | Updated when |
|---|---|---|
| `README.md` (root) | What the project is, how to run it locally, how to deploy | Running or deploying changes |
| `ARCHITECTURE.md` (root) | Consolidated index that names its canonical sources (§4) | A canonical source is added, renamed or retired |
| `docs/README.md` | The docs index: one line per document, "start here" pointers, the conventions section | Any document is added or renamed |
| `docs/architecture/` | Canonical references on system shape: domain model, service decomposition, contracts, infrastructure | System shape changes |
| `docs/product/` | Product-facing references: jobs-to-be-done and flows, the message/copy catalogue, metrics definitions, pricing, safety policy | Product behaviour changes |
| `docs/specs/` | Implementation specs: requirements + traceability matrix, test plan (the WHAT) vs testing guide (the HOW), prompt/step and extraction schemas | A spec's subject changes |
| `docs/adr/` | One file per durable decision (§3) | A durable trade-off is made or amended |
| `docs/plans/` | Staged implementation plans, one stage per chapter, plus an append-only progress log | Work is planned or a stage lands |
| `docs/runbooks/` | Operational procedures, one per task, written to be followed under pressure | An operational procedure is added or changes |
| `docs/postmortems/` | One file per significant incident: root cause, impact, fix, follow-ups | After an incident |
| `KNOWN_ISSUES.md` (root) | Living list of confirmed gaps and open follow-ups (§6) | A gap is confirmed, resolved, or reclassified |
| `docs/repo-organization.md` | Top-level folder table, per-area rules, naming rules, the shared-code promotion criterion | Repo layout or naming conventions change |

Rules for the tree itself:

- **One canonical home per fact.** A second copy is an index entry with a link, never a
  duplicated paragraph. Two copies drift, and neither one announces that it lost.
- **Every directory earns its place.** Do not create `docs/runbooks/` before there is a
  runbook; create it with the first real document. An empty directory of aspirational
  headings is indistinguishable from a stale one.
- **The docs index is a document, not a directory listing.** Each entry carries a one-line
  description of what the reader will find and, where it matters, why they would start
  there. Bold the entry points.
- **Depth is one level.** `docs/<area>/<document>.md`. Deeper nesting hides documents from
  both people and search.

Beside a skill or a tool, longer material goes in `references/*.md` next to the file that
links it, one level deep, linked relatively — the same shape, applied locally.

## 2. Routing — change type to document

| The change | Where it is documented |
|---|---|
| Product behaviour, flows, user-visible copy | `docs/product/` |
| System shape: services, boundaries, data flow, deployment topology | `docs/architecture/` |
| A durable trade-off where a reasonable alternative existed | A new ADR in `docs/adr/` |
| API behaviour | The service's API contract document, plus any generated client surface, in the same commit |
| Database schema shape (as opposed to a single migration) | `docs/architecture/` + a migration note; the migration file itself is the record of *how* |
| An operational step someone will run at 3am | `docs/runbooks/` |
| Staged implementation work | `docs/plans/` + an entry in the progress log |
| An incident | `docs/postmortems/` + a `KNOWN_ISSUES.md` entry for anything left open |
| A confirmed gap with no fix yet | `KNOWN_ISSUES.md` (§6) |
| How to run or deploy | Root `README.md` |
| Repo layout, folder purpose, naming | `docs/repo-organization.md` |
| Nothing durable — a local implementation detail | Nowhere. Code and its tests are the record |

Routing rules:

- **Route once.** If two homes seem right, the fact is probably two facts; split it, or
  pick the more specific home and link from the other.
- **A plan is not a decision.** Plans record sequence and definition-of-done; the decision
  and its alternatives belong in an ADR that the plan cites.
- **A runbook is not architecture.** If a procedure needs three paragraphs of rationale to
  make sense, the rationale is an ADR and the runbook links to it.
- **The shared-code promotion criterion belongs in the repo-organization document.** Code
  moves into a shared module only when at least two consumers need it, or when it enforces
  a cross-cutting rule such as auth, metrics, sanitisation or ownership checks. Writing the
  criterion down is what gives the "just put it in shared" reflex an answer.

## 3. The ADR contract

**File name:** `NNNN-kebab-title.md`, zero-padded to four digits, allocated in the same
commit that adds the file. A number is permanent and is referenced by number everywhere
else; two files sharing a number breaks every by-number reference and has happened in
practice when two branches allocated in parallel. Check the directory, not your memory.

**Title is a full sentence stating the decision**, not a topic. `0060-merge-integrity-discipline.md`
opens with "Merge-integrity discipline — a concurrent refactor must not silently revert a
concurrent feature", so the index of titles is readable as a list of commitments. A title
that names only the subject ("caching", "auth") forces every reader to open the file.

**Shape** — lightweight, five parts, in this order:

```markdown
# ADR-NNNN: <full sentence stating the decision>

Status: Accepted | Proposed | Superseded by ADR-MMMM
Date: YYYY-MM-DD
Relates to: ADR-XXXX (<why>), <document> (<why>)   # optional, one line each

## Context
## Decision
## Consequences
```

- **Status carries provenance.** Where the decision came out of a specific review, audit or
  incident, say so on the Status line: `Proposed (YYYY-MM-DD; from the <date> <review name>)`.
  The reader then knows what evidence to weigh.
- **`Relates to:` is a real section, not decoration.** Name the ADRs this one extends,
  narrows or contradicts, and say in a clause why. This is how a reader of ADR-0041 learns
  that ADR-0037 applies the same doctrine to docs instead of code.
- **Context states the alternatives that were live**, including the ones rejected, and the
  constraint that decided between them. "Two common mechanisms exist: (a) …, or (b) …" is
  the useful form. Context without an alternative is a description, not a decision record.
- **Decision is written in imperative present tense** and is specific enough to check
  against code. Multi-part decisions get numbered clauses (`**D1 — …**`, `**D2 — …**`) so
  later documents can cite one clause rather than the whole ADR.
- **Consequences list the costs, not just the benefits**, and name the downstream
  obligations the decision creates — the migration template that must now include a block,
  the tool that becomes required, the skill or checklist that must be updated. An ADR whose
  consequences are all positive was not a trade-off.
- **Scope the negative.** State what the decision is *not* ("this is defense in depth, not
  a replacement for application checks") — it prevents the next reader over-applying it.

**When to write one.** Any choice that will still constrain the codebase in six months and
that a competent engineer could reasonably have made differently. Not: a library version
bump, a naming preference, a refactor with one obvious shape.

**Amendment — ADRs are amended, never rewritten.** The ADR body is the historical record of
what was decided and why; rewriting it destroys the only evidence of the reasoning a later
reader needs.

1. When later work changes a decision's operative content — a command removed, a flag
   retired, a delivery point moved — add a **dated amendment note on the Status line**
   (`Amended YYYY-MM-DD by ADR-MMMM: <what changed>`), and cite the amending ADR in place.
2. When a decision is replaced wholesale, mark the old one `Superseded by ADR-MMMM` and
   write the new ADR. Do not edit the old body to describe the new world.
3. Correcting a typo, a broken link or a factual error about the past is fine. Changing
   what the ADR decided is not.
4. The Status line is the living pointer; everything below it is frozen.

## 4. The index-not-source pattern

A consolidated reference (a root `ARCHITECTURE.md`, a "start here" overview) is valuable
and it is also the document most likely to go stale, because nothing breaks when it does.
Neutralise that by making it structurally incapable of claiming authority:

1. **Declare its status in the first line**: "Status: consolidated reference. Canonical
   sources are the split documents under `docs/architecture/`; this file is the map."
2. **Name the canonical sources explicitly**, as a block near the top, one line per
   concern with a relative link. A reader who wants detail is routed away in one hop.
3. **Every section ends in an arrow to its canonical source.** A paragraph with no arrow
   is an unowned claim — either give it a source or delete it.
4. **Keep it short enough to be re-read.** One or two sentences per numbered concern. The
   moment the index starts explaining, it has become a second copy.

The point is that a stale index cannot masquerade as truth: its own text tells the reader
where truth lives, so the worst failure mode is a slightly out-of-date map, not a
confidently wrong reference.

## 5. Status markers — shipped-by-default reading

**A canonical sentence describing behaviour is read as shipped and live unless it carries
an explicit marker.** Design-time prose reads as shipped forever, which is precisely how
documents come to promise features that exist only as a dead code path. Closed vocabulary:

| Marker | Means | Requires |
|---|---|---|
| `planned` | Decided (ADR ratified) but not built | The ADR reference |
| `flag-gated (FLAG_NAME, default-off)` | Built, dormant in production | The exact flag name and its default |
| `legacy` | Kept only for backward compatibility or unstick paths | What replaced it |
| `dropped` | Decided against after the fact | The amending ADR |

- Any section describing unbuilt or dormant behaviour MUST carry one.
- **Bare future tense without a marker is drift.** "The system will retry…" tells the
  reader nothing about today.
- When a flag flips default or is removed, the marker is updated in the same change (§7).
- The vocabulary is closed. Projects may render the markers with an emoji or a badge, but
  do not invent a sixth state — "partially shipped" is `flag-gated` or it is two sentences.

## 6. Honest status — the `KNOWN_ISSUES.md` pattern

A living list of **confirmed gaps**, not a roadmap and not a backlog. Its job is to stop
the next reader from mistaking authored-but-inert machinery for working machinery.

Each entry is a heading plus three parts, in this order:

1. **What exists** — the code, manifests or scripts that implement the designed path.
2. **What is true today** — what actually runs in production instead, and why. This is the
   part every other document omits.
3. **Resolution path (not yet done)** — the concrete steps, in order, with the guardrail
   that says the step worked.

Two prefixes carry most of the value:

- **`Verify:`** — a claim that is probably true but has never been executed or observed.
  "Verify: whether an image lifecycle policy actually exists — if not, every push
  accumulates images indefinitely with nothing pruning old tags." Use it for anything
  authored without a local way to confirm it (lint configs mirrored from another project,
  a cleanup policy configured by hand outside IaC).
- **`Not an issue:`** — a thing that *looks* like drift and is deliberate. Two registries
  for two deploy paths, two similar-looking identifiers, a duplicated-looking module.
  Recording it costs three lines and saves the next reader an investigation.

Worked skeleton (capability names, not vendor services):

```markdown
## Secret sync path is authored but inert

`infra/<secrets>/` and `scripts/<sync>.sh` implement the designed flow — SECRET_MANAGER →
sync operator → runtime secret → pod env — but the operator is **not installed on the live
cluster**: its controller image is hosted on a registry the cluster's nodes cannot reach.
A known networking/mirroring gap, not a code bug in this repo.

In practice, today, live secrets are written directly by `scripts/<direct>.sh`, which
creates plain secret objects from IaC outputs and bypasses SECRET_MANAGER entirely.

**Resolution path** (not yet done): mirror the controller image into REGISTRY, point the
install at that mirror, then switch day-to-day rotation to the designed command. See
`infra/<secrets>/README.md` for the full design.

## TFSTATE_BACKEND: remote state migration hasn't been run yet

The environment now declares a remote backend, but the live state is still local on the
operator's machine — that migration is authored, not executed. Guardrail: immediately
after `init -migrate-state`, `plan` MUST show zero changes; if it doesn't, stop and
reconcile before running anything else.
```

The honesty rule generalises: **if something is authored but never executed, say so.**
Never write "deployed", "wired" or "enforced" about a path that has not run. If the
`incident-response` skill is installed, resolved entries graduate into a postmortem there;
otherwise close them out in the project's own incident notes.

## 7. Docs-truth discipline

**D1 — The doc edit rides the change.** A change that alters user-visible flow, commands,
state machines, endpoints, generation steps, copy keys, or feature-flag defaults is **not
done** until the affected canonical section is updated **in the same commit or PR**. A
review that sees a behaviour change with no doc edit flags it.

**D2 — Name the canonical set.** The project maintains an explicit, closed list of which
documents are canonical (§ Project delta). "Everything in `docs/`" is not a list; it makes
D1 unenforceable, because nobody can tell which file was supposed to change.

**D3 — Classify every contradiction you find.** When code observed during a session
contradicts a document, it is exactly one of three things, and each has a different action:

| Class | Situation | Action |
|---|---|---|
| **(a)** | Code shipped per a binding decision, doc is stale | Update the doc, cite the ADR |
| **(b)** | Doc describes decided-but-unbuilt behaviour | Keep the text, add the §5 status marker |
| **(c)** | Genuine conflict — the doc may be right and the code wrong | Do **not** edit either side. Record it in the drift register as an open question for the owner; it is a candidate ADR |

Never leave a contradiction unrecorded, and never silently resolve a (c) by editing
whichever side is easier to change.

**D4 — Periodic drift audit.** A register at `docs/plans/docs-code-drift-audit-<YYYY-MM>.md`,
refreshed at least once per stage boundary or monthly, whichever comes first, and after any
multi-decision implementation program lands. The audit diffs documents' behavioural claims
against reality: commands and callbacks, state machines, config flags, copy keys, service
endpoints, pipeline steps. No tooling is mandated — a grep checklist is an acceptable
implementation; a CI gate is a later upgrade, not a prerequisite.

**D5 — Lockstep is visible in the log.** The progress-log entry for a behaviour-changing
change carries a `Docs lockstep:` line naming the documents updated. This adds no artifact;
it makes an existing habit auditable, and an entry missing the line is a review flag.

`[!]` **Never inline a digest of decisions into an always-on agent file** (`AGENTS.md`,
`CLAUDE.md`, a system prompt, a root README section). It goes stale silently and nothing
fails: one repo's agent file enumerated decisions up to number 57 while the ADR directory
had reached 66, so every session that trusted it worked from a nine-decision-old view of
the project. Always-on files link to `docs/adr/` and state the rule ("decisions in
`docs/adr/` are binding, read the directory"); they never summarise the contents. The same
applies to any generated or hand-maintained "current state" block inside a file that
nothing validates.

## 8. Naming conventions

- ADRs: `NNNN-kebab-title.md`; the title is a sentence (§3).
- Plans: `kebab-title-plan.md`, structured as phases with a definition-of-done and
  dependencies per phase.
- Runbooks and postmortems: `kebab-title.md`; postmortems prefix the date
  (`YYYY-MM-DD-kebab-title.md`) because chronology is how they are read.
- Drift registers and audits: `kebab-title-<YYYY-MM>.md`.
- Documents use kebab-case; no spaces, no uppercase except the root files that convention
  fixes (`README.md`, `ARCHITECTURE.md`, `KNOWN_ISSUES.md`).
- Skills, where the project ships them, follow `skills/<name>/SKILL.md` with frontmatter,
  plus optional `evals/` and `references/`. If the `skill-authoring` skill is installed,
  follow it; otherwise follow the project's own convention.

## 9. Definition of done

For a behaviour-changing change:

- [ ] The canonical document for the changed behaviour is edited in the **same** commit.
- [ ] Anything described but not shipped carries a §5 status marker with its flag name or
      ADR reference.
- [ ] A durable trade-off got an ADR, with alternatives in Context and costs in
      Consequences.
- [ ] No existing ADR body was rewritten; changes to a past decision are a dated Status
      note or a new superseding ADR.
- [ ] The docs index lists any new document, with a one-line description.
- [ ] Any consolidated index that mentions the changed area still points at the right
      canonical source.
- [ ] Contradictions found along the way were classified (a)/(b)/(c) and acted on.
- [ ] Nothing claims a path is live that has not actually run; unexecuted work is in
      `KNOWN_ISSUES.md` with a `Verify:` prefix or a resolution path.
- [ ] The progress-log entry carries its `Docs lockstep:` line.

For a new document:

- [ ] It has exactly one home, and every other mention of the subject links to it.
- [ ] It states its own scope boundary in the opening paragraph.
- [ ] It is reachable from `docs/README.md`.

## Project delta

The consuming repo supplies:

- **The canonical set** — the explicit, closed list of documents that D1 binds.
- **The docs root and area names** if they differ from `docs/architecture|product|specs|adr|plans|runbooks|postmortems`.
- **The progress-log location** and whether a `Docs lockstep:` line is required on every
  entry or only on behaviour-changing ones.
- **Marker rendering** — the emoji, badge or plain-text form the four §5 markers take, and
  where the vocabulary is published.
- **The drift-audit cadence** and register path.
- **The shared-code promotion criterion** for this repo (how many consumers, which
  cross-cutting rules count).
- **Who owns class (c) conflicts** — the person or role that resolves a genuine doc-vs-code
  contradiction.
