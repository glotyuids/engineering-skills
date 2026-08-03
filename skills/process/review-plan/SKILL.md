---
name: review-plan
description: Systematic review of an implementation plan before any code is written — gather read-only evidence from the repo and the running system to test the plan's assumptions, check it across four dimensions (correctness and logic, architecture and principles, missing parts, ambiguity and double meaning), rank every finding in a severity table, and batch all open questions, each with researched options and a recommendation, into one block at the end. Use when the user says "review the plan", "validate the approach", "check this plan for issues", "is this plan complete", "poke holes in this", "review before implementation", when a plan or design doc is pasted for critique, or when an agent has finished planning and is about to start executing. Language- and stack-neutral. Reviews plans; never implements them.
license: Apache-2.0
metadata:
  source: glotyuids/engineering-skills
  version: 0.1.0
---

# Review a plan before it is implemented

A plan is the cheapest place to fix a design error: nothing has been built, so a finding
costs a sentence instead of a refactor. This skill is the procedure for that review — read
the plan, gather evidence that tests its assumptions, check it along four dimensions, rank
what you found, and ask every open question once, at the end, with options already
researched.

The review is **read-only from start to finish.** It ends before the first line of code.

## Scope

This skill defines only: **what evidence to gather before analysing a plan, the four
dimensions to check the plan against, how to rank findings, how to handle open questions,
and the shape of the review output.**

It does not define: how to author a plan in the first place, how to review a diff or a pull
request after the code exists, or how to implement an accepted plan. Reviewing produced code
is a different job — if a code-review skill or reviewer agent is installed, use that for
diffs. The architecture rules the plan is judged against come from the consuming repo (see
[Project delta](#project-delta)).

## When to use

- A plan, design doc, or step list is pasted or linked for review.
- Before starting implementation of anything multi-step.
- The user says "review the plan", "validate the approach", "check for issues", "what am I
  missing", "poke holes in this".
- An agent has just finished planning and is about to execute — review the plan first.

## When not to use

| Situation | Do instead |
|---|---|
| The "plan" is one obvious step | Say so and proceed; a review section longer than the plan is noise |
| The plan is already implemented | Review the diff, not the plan |
| There is no plan — only a goal | Ask for the goal and constraints, or produce a plan first (a planning skill or agent, if one is installed), then review it |
| The user asked for implementation, not review | Implement; do not silently convert the request into a review |

---

## Phase 1 — Gather evidence before analysing

Do not review a plan against your own assumptions about the system. Check the assumptions
against the system. Gather first, analyse second: findings that arrive after the analysis is
written tend to be quietly ignored.

### 1.1 Repository evidence

| Signal needed | Where to look |
|---|---|
| Does the code the plan touches look the way the plan says? | Read the named files and packages before commenting on them |
| Prior art / an existing pattern for the same thing | Search for the closest existing implementation; a plan that reinvents a house pattern is a finding |
| Architecture constraints and past decisions | The project's architecture docs and ADRs — a plan contradicting an accepted ADR is a Critical finding until the ADR is superseded |
| Known issues and accepted debt | The project's known-issues list; a plan may be re-solving something deliberately deferred |
| Test surface | Existing test layout and naming — the plan's test strategy must fit it |
| Schema / migration history | The migration directory: current schema version, whether the plan's change is additive |
| Contract surface | API specs, event schemas, generated clients — who breaks if the plan changes them |
| Recent related work | `git log` on the touched paths: someone may have tried this already |

### 1.2 Runtime evidence (only when the plan touches a deployed system)

When the plan depends on runtime behaviour or production state, query it. **The signal in
the left column is the requirement; the right column is an illustration only** — commands as
they would look on a project that runs a container orchestrator, a chart-based release tool,
a push-based configuration tool and a relational database. On a project with a different
stack, obtain the same signals with whatever it actually runs. Every command shown is
read-only. Substitute the project's own values for `<namespace>`, `<release>`, `<service>`,
`<deployment>`, `<inventory-path>`.

| Signal needed | Command examples (illustration) |
|---|---|
| Pod status, restarts, ages, resource use | `kubectl -n <namespace> get pods`, `kubectl -n <namespace> top pods` |
| Deployed image tags and workload shape | `kubectl -n <namespace> get deploy -o wide`, `kubectl -n <namespace> describe deploy/<deployment>` |
| Config actually in effect | `kubectl -n <namespace> get configmap <name> -o yaml` |
| Recent errors, panics, restarts-in-logs | `kubectl -n <namespace> logs -l app.kubernetes.io/name=<service> --tail=200 --since=1h` |
| Release values as installed | `helm -n <namespace> get values <release>`, `helm -n <namespace> list` |
| Whether a secret exists (never its value) | `kubectl -n <namespace> get secrets` |
| Schema state, row counts, data shape | A one-off client pod running **read-only queries only**: `kubectl -n <namespace> run tmp-psql --rm -it --restart=Never --image=<db-client-image> -- psql "<DSN from the project's secret>"` — `SELECT` and `\d` only, then let the pod delete itself |
| Deployment topology, hosts, variables | `ansible-inventory -i <inventory-path> --list`, and read the variable files directly |

If the `kubernetes-helm` skill is installed, pin the cluster context on every invocation the
way it requires; otherwise follow the project's own conventions. If a `secrets-management`
skill is installed, follow it for how a DSN is obtained — never paste a secret value into
the review.

### 1.3 Rules for gathering

- **Read-only only.** Observing verbs only — read, list, describe, inspect, tail logs,
  `SELECT` (e.g. `get`, `describe`, `logs`, `top`, `helm get/list/status`,
  `ansible-inventory --list`). Never a verb that mutates — create, apply, delete, scale,
  patch, restart, upgrade, roll back, run a playbook, or any DDL/DML. A review that changes
  the system is no longer a review.
- **Gather before analysis.** Run the queries early so the findings are informed by them.
- **Cite evidence.** When a finding rests on gathered data, quote the output and name the
  command that produced it — e.g. "the ConfigMap has no `FEATURE_GATE` key (confirmed via
  `kubectl -n <namespace> get configmap <name> -o yaml`), so plan step 4's assumption that
  the flag is already deployed is false."
- **Never invent evidence.** If a command was not run, or failed, do not describe its
  output. Absence of data is itself a reportable state.
- **Do not block on infrastructure.** If there is no cluster access, no credentials, or no
  network, note the gap explicitly, mark the affected findings as unverified, and continue
  the review with that caveat.
- **Redact.** No secret values, tokens, connection strings, personal data or customer data
  in the review output. Report the shape ("the secret exists and has key `database-dsn`"),
  never the content.

---

## Phase 2 — The four review dimensions

Work through all four. A plan that passes three and fails one is not ready.

### 1. Correctness and logic

- [ ] **Dependencies.** Is the step order right? Are prerequisites satisfied before they are
      used? No circular or impossible sequences.
- [ ] **Edge cases.** Failure paths, empty states, partial success, retries, timeouts,
      concurrency — addressed or explicitly out of scope?
- [ ] **Assumptions.** Are the implicit assumptions written down? Challenge every "obvious"
      and unstated one, and **validate against the gathered evidence** — does the config,
      schema, or deployed version actually contain what the plan assumes?
- [ ] **Completeness.** Does the plan reach all of the stated outcome, with nothing left
      implicit ("and then wire it up")?
- [ ] **Verifiability.** Does each step have an observable done-condition — something a
      person or a test can check — rather than "implement X"?
- [ ] **Reversibility.** If a step goes wrong halfway, what state is the system in, and how
      does it get back?

### 2. Architecture and principles

- [ ] **Layering.** If the project uses a layered or clean architecture, does the plan
      respect it — no business rules in transport handlers or in infrastructure adapters, no
      inward dependency on an outer layer?
- [ ] **Service and module boundaries.** Do the changes stay inside the owning bounded
      context? No cross-context reach-through, no shared mutable state introduced between
      services.
- [ ] **Single responsibility and inversion.** No god module, no new package that exists
      only as a dumping ground, dependencies pointed at interfaces the consumer owns.
- [ ] **Reuse over reinvention.** Does the plan rebuild something the repo already has?
- [ ] **Project constraints.** Alignment with the project's architecture docs, ADRs and
      stated engineering rules (e.g. no panics in runtime paths, no silently swallowed
      errors, no unbounded goroutines/threads/tasks). If a language-conventions skill for
      the project's stack is installed, judge against it; otherwise use the project's own
      conventions.
- [ ] **Blast radius.** Which other services, teams, or consumers are affected, and does the
      plan acknowledge them?

### 3. Missing parts

- [ ] **Tests.** Is the test strategy defined — which levels, which cases, what proves the
      change works? If an integration-testing or e2e skill is installed, does the plan match
      the level it prescribes?
- [ ] **Migrations.** Schema or data changes? Is there a migration path, a backfill plan for
      existing rows, and a rollback that does not lose data? Additive-first?
- [ ] **Configuration and secrets.** New config keys, new secrets, new env vars — is every
      one of them threaded through to every environment the service runs in?
- [ ] **Docs.** README, ADR, runbook, changelog, API spec — which need updating? If a
      documentation-standards skill is installed, follow its routing table for where each
      kind of change is written down.
- [ ] **Observability.** Logs, metrics, traces, health/readiness behaviour for the new
      paths. How will anyone know this broke?
- [ ] **Security.** Authentication, authorisation, input validation, output encoding, PII
      handling, rate limits, and what new attack surface the change opens.
- [ ] **Rollout and rollback.** Feature flag, staged rollout, deploy order between services,
      and the explicit undo. Deploy-order dependencies between two services are a classic
      omission.
- [ ] **Performance and cost.** New N+1 queries, new hot loops, new external calls per
      request, new storage growth.

### 4. Ambiguity and double meaning

- [ ] **Terminology.** Are terms used consistently and defined once? Watch for near-synonyms
      that mean different things in the codebase (e.g. "user" vs "account", "job" vs "task",
      "session" vs "connection").
- [ ] **Vague verbs.** Replace "handle", "process", "manage", "support", "improve" with the
      concrete action and object.
- [ ] **Unclear scope.** "Update X" — which fields, which endpoints, which callers, which
      environments?
- [ ] **Multiple interpretations.** Could a competent implementer read a step two ways and
      build two different things? If yes, that step is a finding, not a nitpick.
- [ ] **Unowned steps.** Steps written in the passive voice with no actor and no artifact
      ("the data is migrated") hide the hard part.

---

## Phase 3 — Rank every finding

Every finding gets a location, a severity, and a suggested fix. A finding without a
proposed fix is an observation, not a review.

| Severity | Meaning |
|---|---|
| **Critical** | Implementing as written produces a wrong, unsafe, or data-losing result; or the plan contradicts an accepted architecture decision. Must be resolved before any code. |
| **High** | The plan will need significant rework once discovered — a missing migration path, an unhandled failure mode, a broken contract for an existing consumer. |
| **Medium** | A real gap that costs time but is fixable in place — missing tests, missing observability, unclear scope on one step. |
| **Low** | Polish: wording, naming, ordering preference, optional hardening. |

Two more axes, both reported alongside severity:

| Axis | Values | Meaning |
|---|---|---|
| Difficulty | Low / Medium / High | Effort to apply the fix *now, in the plan* |
| Architecture impact | None / Localized / Cross-cutting | How far the fix reaches: nothing structural, one module, or several services and contracts |

Rules for reporting:

- **Cite the plan.** Quote the step being criticised: "Step 3: 'Update game state' — unclear
  which fields are written and by whom."
- **Separate fact from judgement.** "The ConfigMap has no such key" is a fact; "this will
  break on deploy" is the consequence you draw from it.
- **State confidence.** If a finding is unverified because evidence could not be gathered,
  say so in the row rather than presenting a guess as a fact.
- **Do not pad.** Three real Critical findings beat twenty Low ones. If the plan is good,
  the correct review is short.

---

## Phase 4 — Open questions: research first, ask once

**Before asking the user anything, research the options and present them with analysis.**
A bare question hands the work back to the user; a question with options hands them a
decision.

For each open question:

1. **Identify the options** — enumerate every reasonable variant, not two.
2. **For each option, give**: a short description, the benefits, the restrictions and
   trade-offs, and when it is the right choice.
3. **Recommend one**, with the justification, or state explicitly that the choice is the
   user's to make and why.
4. **Only actually ask** when the decision is genuinely user-dependent — product, UX,
   policy, cost, priority. Technical questions you can answer with evidence, answer.

### Ordering

- Ask questions **only after** the full analysis and all findings are presented.
- If the tool in use has a question or dialog affordance, use it; otherwise put the
  questions in one clearly delimited block at the end.
- **All questions go in one batch.** Never drip-feed them one at a time across turns — that
  turns a review into an interrogation and loses the user's context between answers.

### Example

**Bad** (asking without options):

> "Should we use polling or WebSockets for real-time updates?"

**Good** (options with analysis, one decision to make):

> **Real-time updates — options**
>
> | Option | Benefits | Restrictions | Prefer when |
> |---|---|---|---|
> | WebSocket | Low latency, bidirectional, fits the existing realtime gateway | Connection state to manage, more complex to scale and test | Live interactive events, chat |
> | Server-Sent Events | Simpler than WebSocket, one-way push over plain HTTP | No client→server channel; proxy buffering caveats | Notifications, log tailing |
> | Polling | Simple, stateless, trivially scalable, easy to debug | Higher latency, more requests, wasted load when idle | Low-frequency updates, fallback path |
>
> **Recommendation**: WebSocket — the project already runs a realtime gateway, and the
> events in scope require sub-second delivery. Keep polling as the documented fallback.
>
> Confirm WebSocket, or say which constraint I have wrong.

---

## Phase 5 — Output format

Produce the review in this structure. Omit sections that are genuinely empty rather than
writing "none" six times, but never omit a section to make the plan look better.

```markdown
## Plan review summary

**Plan**: <brief title>
**Reviewed**: <date>
**Verdict**: Ready to implement / Ready after the fixes below / Not ready — see Critical
**Evidence gathered**: <what was queried, or what could not be and why>

### Critical issues (must fix before implementation)
- [ ] Issue 1 — <step cited> — <what is wrong> — <suggested fix>
- [ ] Issue 2 — ...

### Gaps / missing parts
- [ ] Missing 1 — <what is absent> — <what to add>
- [ ] Missing 2 — ...

### Ambiguities (disambiguate before implementation)
- [ ] Ambiguity 1 — "<current wording>" → "<clarified wording>"
- [ ] Ambiguity 2 — ...

### Architecture / principle concerns
- [ ] Concern 1 — <what violates what> — <how to align>
- [ ] Concern 2 — ...

### Summary table (after the details)
Every problem from the sections above, one row each.

| Problem | Severity | Difficulty | Architecture impact | Notes |
|---|---|---|---|---|
| Issue 1 (short) | Critical/High/Medium/Low | Low/Medium/High | None/Localized/Cross-cutting | Key fix or rationale |
| Issue 2 (short) | ... | ... | ... | ... |

### Strengths
- What the plan gets right — briefly, and only if true.

### Revised plan (optional)
If the changes are substantial, give a corrected or annotated version of the plan rather
than making the user reassemble it from the findings.

### Open questions (with options)
For each: the options table, then the recommendation. Ask them all together, at the end.
```

---

## Hard constraints

- **Do not** approve a plan that has Critical issues or unresolved ambiguities without
  flagging them, however much the user wants to start.
- **Do not** ask the user a question without first researching options and giving a
  recommendation, and do not ask questions one at a time.
- **Do not** contradict the project's architecture docs or accepted ADRs without saying so
  explicitly and getting the user's acceptance.
- **Do not** run any mutating command during the review — anything that creates, applies,
  deletes, scales, patches, restarts, upgrades, rolls back, or writes to a database,
  whatever the project's tooling calls it.
- **Do not** start implementing. Reviewing and implementing are separate turns; wait for an
  explicit go-ahead.
- **Do not** report data you did not gather, or output a command you did not run.
- **Do** gather evidence — logs, config, schema, code, git history — to test the plan's
  assumptions before finalising findings.
- **Do** cite the specific plan step in every finding.
- **Do** say plainly when the plan is good. A clean review is a valid result.

---

## Quick checklist (copy one per review)

| Dimension | Check |
|---|---|
| Evidence gathered (code, docs, ADRs, git history) | |
| Runtime evidence gathered, or gap noted | |
| Dependencies and step order | |
| Edge cases, failure paths, concurrency | |
| Assumptions validated against evidence | |
| Each step has an observable done-condition | |
| Layering, boundaries, single responsibility | |
| Reuse over reinvention | |
| Tests, migrations, docs | |
| Config, secrets, per-environment threading | |
| Observability and security | |
| Rollout, rollback, deploy order | |
| Terminology consistent | |
| Vague verbs replaced with concrete actions | |
| Every finding has location + severity + fix | |
| Summary table produced | |
| Questions batched, each with options + recommendation | |
| Nothing mutated, nothing secret quoted | |

## Project delta

The consuming repo supplies:

- Where the architecture rules live (architecture docs, ADR directory, engineering rules
  file) — the authority a plan is judged against.
- The known-issues / accepted-debt list, so the review does not re-litigate deferred work.
- The namespace, release names, inventory path, and cluster-context convention used in the
  runtime-evidence commands, plus how read access is obtained.
- Which environments exist, and which of them a plan must account for.
- The house severity vocabulary, if it differs from Critical/High/Medium/Low.
- Where a completed review is written down, if it is persisted rather than delivered in
  chat.
