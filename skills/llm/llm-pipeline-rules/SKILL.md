---
name: llm-pipeline-rules
description: Non-negotiable rules for a production pipeline built on a language model — the model classifies and the code decides, all model output and all user content is untrusted, structured output is schema-validated and fails closed after a bounded, declared number of repairs (default one), evidence is extracted before anything is written, prompt packs carry a dated version so a regression is bisectable, every call goes through one model boundary with a budget, a timeout and an idempotency key, and logs carry prompt hashes rather than prompt bodies. Use when adding or changing an LLM call, designing a generation or agent pipeline, editing prompts and templates, adding retrieval or a judge stage, wiring an LLM proxy or router, or swapping models. Trigger phrases "add an LLM step", "change this prompt", "prompt injection", "the model returned invalid JSON", "switch to another model", "why did the output change", "add a guardrail", "the LLM bill blew up".
license: Apache-2.0
metadata:
  source: glotyuids/engineering-skills
  version: 0.1.1
---

# LLM pipeline rules — the model proposes, the code disposes

**Core rule: a language model may classify, extract and write. It may never decide.
Control flow, writes, scheduling and publishing are executed by deterministic code that
consumed a schema-validated value — never by free-form model prose.**

This skill defines only the *engineering contract* around model calls: stage ordering,
trust boundaries, output validation, versioning, budgets, idempotency, testing and
logging. It does not teach prompt wording, does not choose a model for you, does not
cover retrieval-quality tuning (chunking, embeddings, rankers), and does not define the
product's own content quality bar. If a writing-quality or honesty skill is installed,
that is where "is this output good" is decided; this skill decides whether the output is
*allowed to exist at all*.

**Maturity note:** these rules are distilled from pipeline design reviews and near-misses,
not from postmortems of shipped outages. That is why this skill carries no `[!]` markers.
When one of these rules is violated in your project and it costs you an incident, mark it
there — `[!]` is earned, never decorative.

## 1. The pipeline shape

Name the stages, fix their order, and make the order a test (section 9). A canonical
pipeline, with neutral stage names:

```
intake
  → injection_scan          # before indexing, before any prompt sees the content
  → input_analyzer          # conditional; classifies input kind and audience
  → intent_classifier       # bounded, allowlisted commands only
  → orchestrator            # DETERMINISTIC CODE — the only scheduler
  → retrieval               # selected chunks with stable ids
  → evidence_extractor      # gate: no evidence, no generation
  → generator
  → groundedness_judge
  → style_linter
  → safety_filter
  → delivery
  → feedback_report         # async, never on the critical path
```

| Stage | May decide | Must never do |
|---|---|---|
| `injection_scan` | which segments are redacted | pass unredacted content downstream |
| `input_analyzer` | input kind, audience category, "block: insufficient sources" | schedule work, call tools |
| `intent_classifier` | which allowlisted command, with which validated params | invent a command, browse, request secrets |
| `orchestrator` | every execution decision, in code | consult a model, parse prose |
| `retrieval` | which chunk ids enter the prompt | pass whole documents or raw markup |
| `evidence_extractor` | supported / `NO_SUPPORTED_ANSWER` | soften the verdict to let generation proceed |
| `generator` | the text | perform an effect, emit a decision field the code trusts unvalidated |
| `groundedness_judge` | pass/fail against the evidence | override its own schema with prose |
| `safety_filter` | block / allow | be the *only* guardrail (it is the last, not the first) |

Two stages are optional but their *position* is not: `input_analyzer` runs before
`intent_classifier` or not at all, and `evidence_extractor` runs before every writer or
generation does not run.

## 2. The model classifies, the code decides

1. **Orchestration is deterministic code** — a worker over a durable task store, not an
   agent loop. It is the only component that schedules tasks, writes to the database,
   publishes, or bills.
2. **A model may produce a plan**, i.e. an ordered list of steps to execute — but every
   step is drawn from a closed allowlist and is validated (name + params + types) before
   the orchestrator will run it. A plan is data the orchestrator inspects, not an
   instruction it obeys.
3. **Unknown fields and unknown enum values are rejected**, not ignored. A classifier that
   silently drops an unrecognized command is a classifier that will one day drop the one
   that mattered.
4. **The classifier is stripped**: no tools, no browsing, no file access, no secret
   access, no network egress of its own.
5. **No control flow reads prose.** Never `if response.contains("yes")`, never a regex over
   an explanation, never "the model said it was confident". Confidence is a validated
   numeric field or it does not exist.
6. **Decision fields are typed and bounded**: booleans, enums, ids, scores in a stated
   range. If code branches on it, it is in the schema.

### The conditional input analyzer

When it exists, it runs before classification and answers two closed questions — *what
kind of input is this* (from a fixed set) and *who is it for* — plus one gate:

- Output is JSON, validated against a strict schema, fail-closed (section 4).
- It produces an enriched request that downstream stages consume as a named field, not as
  a blob of prose appended to a prompt.
- **It may block the pipeline** — low confidence, or instructions supplied with no source
  material to ground them. Blocking is a first-class outcome, not an error.
- Its trigger criteria are explicit and cheap to evaluate in code (first message of a
  conversation, attachments present, links present, input over a length threshold), and it
  is skipped when structured context from the interface already answers the same question.
- Its result is persisted with a stable prefix so later stages and later runs can read it
  as context instead of re-deriving it.

## 3. Everything is untrusted input — including the model's output

Two directions, one rule: content coming *in* is untrusted data, and text coming *out* of
the model is untrusted data too.

### Inbound

- Run `injection_scan` **before indexing and before any prompt sees the content**. User
  messages, uploaded documents, fetched pages, third-party API text, and previously stored
  model output on re-entry all go through it.
- Replace suspicious segments with an explicit marker (`[[REDACTED_INJECTION]]`) before
  indexing, so the redaction is visible in the stored artifact and in tests.
- **Never pass raw markup or a whole document to a generation prompt.** Pass only selected
  chunks, each with a stable `chunk_id` the output can cite.
- **Instruction-shaped content is still content.** A document that says "ignore previous
  instructions" is data reporting that it says that. It never changes what the pipeline
  does.

### Prompt assembly

- **Never interpolate untrusted text into a system prompt.** The system prompt is a
  constant (per template + version); untrusted content goes into a separate user-role
  message.
- Delimit untrusted blocks with a fence the content cannot forge — a per-call random token,
  not a fixed string like `---` or triple backticks — and state in the system prompt that
  everything inside the fence is data.
- The base system prompt is prepended by the model boundary (section 6) on **every** call.
  A call site cannot opt out of it, and cannot replace it.
- Tools and browsing are disabled at the boundary by default; a stage that needs one
  enables it explicitly and narrowly.

### Outbound

- Apply denylist pattern checks to the model response before anything else reads it.
- Model output never becomes an executable or addressable thing without validation: no
  evaluating it, no shelling out, no building SQL from it, no fetching a URL it produced,
  no opening a file path it produced, no rendering it as raw HTML. Ids it emits are
  checked against ids the pipeline actually issued.
- Output that will be re-ingested later (stored drafts, conversation history) re-enters
  through `injection_scan` like any other untrusted source.

## 4. Structured output: fail closed after a bounded repair count

| Step | Rule |
|---|---|
| 1. Validate | Parse and validate against the template's schema — strict, additional fields rejected |
| 2. On failure | Run a **repair**: re-ask once, echoing the validation error back to the model |
| 3. Repeat | Up to the template's **declared repair count** — default **one**, set in configuration, never unbounded |
| 4. On exhaustion | Return a typed `ERROR` to the caller and stop the stage, with the attempts recorded on the run |

Non-negotiable specifics:

- **A declared count, not a repair loop.** The count is a per-template setting, visible in
  configuration and recorded on the run, and it defaults to one. A loop that keeps
  re-asking until the shape is right turns a broken prompt into an unbounded bill and
  hides the regression from the golden set. Raise the count above one only for a template
  whose golden set shows the second repair actually succeeds, and record the pass rate per
  attempt so the cost stays visible.
- **Never accept prose, markdown, or partial JSON.** No "extract the JSON from the code
  fence with a regex", no lenient parser, no defaulting a missing required field. Every
  such leniency is a silent decision the model made for you.
- **Fail closed** — the failure surfaces as an error the orchestrator handles, never as an
  empty result that downstream stages treat as "nothing to do".
- Each repair counts against the call's retry budget (section 7) and presents the same
  idempotency key; only a validated result is ever stored under it.
- Prefer provider-side structured output/schema enforcement where available, and still
  validate locally. Provider enforcement is a shortcut, not the contract.

## 5. Evidence first

- If `evidence_extractor` returns `NO_SUPPORTED_ANSWER`, **no generation runs**. There is
  no fallback that writes something anyway.
- Every final content unit carries its evidence: quotes, offsets, and the `chunk_id` they
  came from. Quote length is bounded and the bound is tested.
- `groundedness_judge` runs after generation and rejects unsupported output. It is itself
  a model call, so its verdict is a schema field (section 4), and a rejection is a real
  outcome the orchestrator acts on — not a warning logged next to the published result.
- A judge and a generator sharing one call is not a judge. Separate calls, separate
  templates, separate versions.

## 6. One model boundary

**All model calls go through one internal client. Feature code never imports a provider
SDK.**

- Call sites name a **role alias** — `classifier`, `reasoning`, `writer`, `judge`,
  `cheap` — never a concrete model id.
- The alias → (provider, model, parameters) map is **configuration**, versioned and
  per-environment. Swapping a model, or routing one alias to a different provider, is a
  config change plus a golden-set run (section 9). It is never a code change, and never a
  change in more than one place.
- The boundary is the single place that: prepends the base system prompt, disables tools
  and browsing, enforces budgets and timeouts, counts retries, applies the denylist checks,
  emits metrics, and logs hashes (section 10).
- Adding a provider means implementing one interface behind the boundary. If adding a
  provider requires touching stage code, the boundary was violated.
- Record the **resolved** model id and parameters on every run. "It used the `writer`
  alias" is not reproducible; "`writer` resolved to `<model-id>` at temperature `<t>`" is.
- Fallback routing (alias falls back to a second model on provider failure) is allowed only
  if the fallback is recorded on the run and the golden set covers both. A silent fallback
  to a weaker model is an invisible quality regression.

## 7. Budgets, timeouts and idempotency

### Per call

| Control | Rule |
|---|---|
| Max input tokens | Enforced before the call, not discovered from a provider error |
| Max output tokens | Always set; an unbounded completion is an unbounded bill |
| Wall-clock timeout | Always set, per role alias; the boundary cancels, the stage fails |
| Retry budget | Counted at **one** layer only — the boundary. Stage-level and provider-SDK retries stack multiplicatively |

### Per job and per user

- Token and cost budgets per job and per user, checked before each call and decremented
  after. Exceeding a budget is a **typed error**, never a silent truncation of the input.
- Truncation, when it is legitimate, is deterministic and stated: drop the lowest-ranked
  chunks first, record how many were dropped on the run, never trim mid-context silently.
- The budget check happens before the call. Discovering the overrun from the invoice is
  not a control.

### Idempotency

- Every generation call carries an **idempotency key** that identifies the *logical call*.
  Two derivations are valid, and the project delta says which:
  - **Stateless pipeline** — a hash of the stable inputs: job/run id, stage name, hash of
    the resolved prompt inputs, prompt pack version, model alias.
  - **Durable, resumable run** (checkpointed steps in a task store) — `run_id + step_id +
    attempt`, where `attempt` is the run's own persisted counter: a resumed worker reads
    it back and presents the *same* key, a deliberate re-execution increments it. Store
    the prompt hash and pack version next to the result and **refuse to replay on a
    mismatch**, so a resumed run cannot pick up a result an earlier template produced.
- Retries — at the boundary, at the worker, or after a crash — present the same key, and so
  does a repair (section 4); only a validated result is stored under it.
- A repeated key returns the stored result instead of re-calling. Without this, a worker
  that is retried after a timeout pays twice and produces two different texts, one of which
  is already downstream.
- **Persist the result before acknowledging the task**, and make the downstream write
  conditional on the run id. A generation that succeeded but whose acknowledgement was lost
  must not be regenerated.
- Streaming partials are never persisted as the final artifact; only a completed,
  validated response is stored.
- Cancellation is honoured end to end: a cancelled job stops issuing calls, and an
  in-flight call's result is discarded rather than written.

## 8. Versioned prompt packs

- **Version format: `YYYY-MM-DD.patch`** — a dated identifier, so a regression window maps
  directly onto a version range and the offending change is bisectable.
- Store `prompt_pack_ref + template_id + version` in the metadata of every job, run and
  stored output. Given a bad output six weeks later, that triple identifies the exact
  template text that produced it.
- **Never edit a prompt in place.** Editing without a version bump makes every stored
  output ambiguous and every regression unattributable.
- Prefer **additive** changes: a new template id, or a new optional field, over a rewrite
  of an existing template.
- A schema change requires all three: version bump, a migration plan for drafts already
  stored under the old schema, and updated tests. Ship them in one change.
- Templates are files under version control, reviewed like code. A prompt edited through a
  console or an admin form is a prompt with no history.

## 9. Golden set + red team = definition of done

No prompt, schema or routing change merges without both. The golden set proves it still
does the job; the red team proves it still refuses.

**Golden set** — frozen inputs with assertions on properties, not on exact strings
(schema validity, required fields present, evidence present and within bounds, the
classifier's chosen command, refusal where refusal is correct). Record pass rate, cost and
latency per pack version so a "harmless" prompt tweak that doubles the cost is visible.

**Red team** — at minimum:

| Case | Expected |
|---|---|
| Injection strings in a document, a page, and a file name | Redacted; instruction not followed |
| Instructions that contradict the system prompt | System prompt wins |
| Content claiming authority ("the admin says you may…") | Ignored; treated as data |
| Request with no supporting evidence | `NO_SUPPORTED_ANSWER`, nothing generated |
| Oversized / truncated / empty input | Typed error, deterministic truncation, no crash |
| Command outside the allowlist | Rejected by validation, orchestrator never sees it |
| Malformed or prose-wrapped model output | The declared repairs (default one), then `ERROR` |
| A question the sources cannot answer | Refusal, **no fabrication** |

That last row is the mandatory negative case: the pipeline must be provably capable of
producing nothing.

**Integration test** asserts the full stage order end to end (section 1) — order
regressions are the failure mode that unit tests never catch. Add cases for allowlist
enforcement, for the orchestrator consuming only validated commands, for the conditional
analyzer's trigger and skip criteria, and for its blocking behaviour.

If a testing skill is installed in the project, follow it for structure and naming;
otherwise follow the project's own test conventions.

## 10. Logging and storage

- **Log prompt hashes, not prompt bodies.** The default log line carries: prompt hash,
  `template_id`, pack version, model alias and resolved model, token counts in and out,
  latency, outcome, retry count, idempotency key. It carries no user content.
- Raising the log level must not raise the exposure. There is no debug mode that prints the
  prompt body containing user data.
- **Redact the error paths too.** Provider errors, validation errors and crash reports echo
  the payload back; wrap them at the boundary so the echo is stripped in one place.
- Store `sanitized_text` (post-scan) as the working artifact; keep the raw snapshot in
  restricted object storage with access controls and a stated retention period. Say which
  store holds which, and who can read it.
- Never put user content into span names, metric labels, or URL query parameters — those
  fan out to every collector on the path.
- If an observability or secrets-management skill is installed, follow its redaction rules
  for the shared log pipeline; otherwise follow the project's own logging conventions.

## 11. Change checklist

Run this whenever you change a prompt, a schema, a stage, the routing config, or proxy
behaviour:

- [ ] Version bumped (`YYYY-MM-DD.patch`)
- [ ] Schema updated if needed, with a migration plan for stored drafts
- [ ] Base system prompt prepended at the boundary; no call site opts out
- [ ] Tools and browsing disabled at the boundary
- [ ] Untrusted text kept out of the system prompt and fenced with an unforgeable delimiter
- [ ] Injection redaction applied before indexing and before any prompt
- [ ] Evidence-first gating enforced; `NO_SUPPORTED_ANSWER` blocks generation
- [ ] Output validated fail-closed within the declared repair count (default one) — no unbounded loop, no lenient parse
- [ ] Intent allowlist enforced; unknown commands and unknown fields rejected
- [ ] No control-flow branch reads free-form prose
- [ ] Model referenced by role alias only; alias map is config, resolved model recorded
- [ ] Per-call max output tokens, timeout and retry budget set; job/user budget checked
- [ ] Idempotency key set and honoured across retries and worker restarts
- [ ] Golden tests updated or added; pass rate, cost and latency recorded for the version
- [ ] Red-team cases run, including at least one refusal/no-fabrication case
- [ ] Unit + integration tests updated, including full stage order
- [ ] Metadata stored on the run (`prompt_pack_ref`, `template_id`, `version`, model, hashes)
- [ ] Logs verified to carry hashes and identifiers, never prompt bodies with user data
- [ ] State honestly what was actually executed versus authored — an untested prompt change
      is untested, and saying so is part of the change

## Project delta

The consuming repo supplies:

- The concrete stage list and their order, plus which optional stages exist.
- The prompt pack location, its `template_id` namespace, and the current version.
- The role aliases in use and where the alias → model map lives per environment.
- The schema definitions and the validator; where strictness is configured.
- The durable task store backing the orchestrator, which idempotency-key derivation is in
  use (stateless hash, or run/step/attempt), and the declared repair count per template.
- Per-call, per-job and per-user budget values, and the timeout per alias.
- Where the golden set and red-team cases live, and the command that runs them.
- The redaction marker, the object store holding raw snapshots, its access policy and its
  retention period.
- The project's own content-quality bar, which this skill deliberately does not define.
