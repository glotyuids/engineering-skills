---
name: observability-and-quality
description: What a service must expose so a failure can be seen and explained — liveness vs readiness and why liveness must never check dependencies, structured logging with a correlation id propagated through the whole call chain, log levels, the never-log-secrets-or-personal-data rule and connection-string redaction, making silent failures observable, the metric set worth having (request rate/latency/errors, dependency latency, queue depth, consumer lag) with cardinality discipline, the linter set with the approved answers to gosec findings on CLIs and test code, health without an orchestrator, and the test policy. Use when adding a health endpoint, wiring a logger or metrics, or when the user says "the pod keeps restarting", "readiness is flapping", "we can't tell what happened in prod", "the metrics backend fell over", "what should we log", "what metrics do we need", "which linters do we run", "add tests for this", "why did this fail silently", or when reviewing observability before a first deploy.
license: Apache-2.0
metadata:
  source: glotyuids/engineering-skills
  version: 0.1.2
---

# Observability and quality

What a service must expose so that a failure is **visible**, **attributable** and
**explainable** after the fact — plus the quality gate that keeps it that way.

**This skill defines only the service's own output surface**: health endpoints, log
structure and content, the metric set and its label discipline, the linter set, and the
test policy. It does **not** define probe wiring, scrape configuration, dashboards or
alert routing — those belong to the infrastructure pack. It does not define how to
investigate a live incident (process pack), the clean-architecture layout or the
error-wrapping rules (`go-conventions` in this pack), or the API and event contract
(`api-and-events`). Where a project's own conventions already exist and differ, the
project wins.

Guiding principle: **an observable that only exists after someone adds it during an
incident is not an observable.** Everything below is written before the first deploy, not
during the first outage.

`[!]` marks a rule that caused a real production incident when it was missed.

---

## 1. Health endpoints

| Probe | Endpoint | Answers | Checks | On failure |
|---|---|---|---|---|
| liveness | `/healthz` | is this process still able to make progress | nothing external — success as soon as the HTTP server is serving | the orchestrator **restarts the container** |
| readiness | `/readyz` | can this instance serve traffic right now | every dependency the service cannot serve without | the instance leaves the load-balancer pool; the process keeps running |
| startup (optional) | `/healthz` | has boot finished | same as liveness | only delays liveness — use when boot is genuinely slow |

**Liveness must not check dependencies.** If `/healthz` touches the database, a
thirty-second database blip fails liveness on **every replica at once**; the orchestrator
restarts all of them, they come back cold with empty pools and no warm cache, and a
recoverable degradation becomes a full outage with a restart loop that outlives the
original blip. Readiness reports dependency health; liveness reports only "this process is
not wedged".

Readiness rules:

- **Check only what the service cannot serve without** — the primary database pool, a
  required downstream. An optional cache does not fail readiness: degrade, log at warn,
  and count it.
- **Bound every check with its own short deadline** (~1 s) and the handler with a deadline
  shorter than the probe timeout. A readiness handler that hangs is worse than one that
  returns false.
- **Cache the result for a few seconds.** Probe interval × replicas × dependencies is real
  load; a handler that opens a fresh connection per probe is a self-inflicted load test.
- **Never run an expensive query.** A pool ping or `SELECT 1`, never a count over a table.
- **Flip to not-ready first on shutdown**, then drain, then stop listening — so the load
  balancer stops sending new traffic before the listener closes. In-flight requests finish.
- **The status code is the contract; the body is for humans.** 200 or 503, plus a body
  naming which dependency failed:

```json
{"status":"unready","checks":{"postgres":"ok","cache":"dial: i/o timeout"}}
```

- Probes cannot authenticate: `/healthz` and `/readyz` stay unauthenticated. Keep them
  free of any detail worth hiding — dependency names are fine, versions and error strings
  from a driver are not.

If the infra pack's `kubernetes-helm` skill is installed, follow it for probe timings,
thresholds and scrape annotations; otherwise follow the project's own conventions.

**Without an orchestrator** — a daemon under launchd or systemd, a single binary on a host —
nothing probes these endpoints, and the process must not assume something will. Then:

- `/readyz` (or a `status` subcommand over a local socket) serves the **operator**: it is
  what a human runs to learn whether the process is doing its job, so the body carries the
  answer, not only the status code.
- **Every background loop reports itself** in that body — running, with its last successful
  tick; or disabled, with the reason (no provider admitted, feature off, policy missing). A
  loop that silently does not run is the silent failure of §5 in another shape.
- Liveness is the init system's restart-on-exit, plus its watchdog where one exists
  (systemd's notify socket, for example): a wedged process must exit or stop feeding the
  watchdog, so bound every loop iteration with a deadline and treat a missed one as fatal.

## 2. Structured logging

Structured JSON (or key-value) through one logger, injected at startup and passed down.
No `fmt.Println`, no `log.Printf` — they bypass structure, level and redaction.

| Field | Value |
|---|---|
| `ts` | RFC3339 with milliseconds, UTC |
| `level` | see the table below |
| `msg` | short, static, lowercase. **No interpolated values** — values are fields, so the message stays searchable |
| `service` | service name |
| `version` | build version or commit — the only way to tell which release produced a line |
| `env` | environment name |
| `request_id` / `trace_id` | the correlation id (§3) |
| `user_id` | the subject identifier — never the email |
| `err` | on failures: the full wrapped chain, in its own field |

| Level | What belongs there |
|---|---|
| `debug` | developer detail, off in production by default: chosen branch, cache hit/miss, payload sizes. Volume is unbounded, so it must never be the level that carries a required signal |
| `info` | one line per externally meaningful event: request completed, job finished, message consumed, state transition, startup config summary (redacted) |
| `warn` | degraded but handled: retry, fallback taken, optional dependency down, an expected result that came back empty, a deprecated path used |
| `error` | the operation failed and someone must be able to find out why: a failure returned to a caller, a dropped message, a failed job |
| `fatal` / `panic` | startup only, and only where the process genuinely cannot run (missing required config). Never mid-request — a request-level panic is recovered, logged and counted |

Rules:

- **Level comes from configuration** (`LOG_LEVEL`), `info` in production, `debug` locally.
- **One event, one line.** The request middleware emits exactly one line per request:
  method, **route pattern**, status, `duration_ms`, bytes, request id, user id.
- **Route pattern, never the raw path.** `/api/<domain>/v1/items/{id}`, not the concrete
  id — otherwise log search by message is useless, and the same value would blow up a
  metric label (§6).
- **Log an error exactly once**, where it stops being propagated (the transport boundary,
  the job runner). Wrapping with `%w` on the way up carries the context; logging at every
  layer produces five lines for one failure and buries the cause.
- **Never log-and-continue.** If you log an error and proceed as if nothing happened, you
  have silently chosen a fallback — name it and count it (§5).
- Do not log an error **and** return it. Pick one; the boundary logs.
- Keep instrumentation in middleware and adapters. `domain` does not log.

If the `go-conventions` skill is installed, follow it for error wrapping and sentinel
errors; otherwise follow the project's own conventions.

## 3. The correlation id

One id, present on every line, carried through the whole call chain. Without it, logs are
a pile of unrelated lines and no incident procedure can start.

1. **Accept or generate at the boundary.** The first middleware reads the inbound header
   (`X-Request-Id`, or the trace-context header if tracing exists) and generates one if it
   is absent. **Validate it**: cap the length, restrict the charset — an id that flows into
   logs, headers and message envelopes is attacker-controlled input.
2. **Put it in `context.Context` immediately** and derive the request-scoped logger from
   it. Never carry a logger in a struct field where it should come from the context.
3. **Propagate outward, everywhere**: every outgoing HTTP call sets the same header, every
   published message carries it in its envelope, every enqueued job row stores it, and
   every worker restores it into its context on pickup. A chain that breaks at the queue
   boundary is the usual reason an async failure cannot be traced back to its request.
4. **Return it to the caller** in a response header, so a user-reported failure maps onto
   a log query.
5. **Long-running multi-step work also carries a stable business id** — an application,
   job or run id. A request id dies with the request; the business id joins the steps
   across services, retries and days.

If the process pack's `incident-response` skill is installed, this id is the correlation
key its procedure starts from; if the `integration-testing` skill is installed, tests
print the same id on failure.

## 4. `[!]` Never log secrets or personal data

**Never log**, at any level, including `debug`:

- credentials of any kind — passwords, tokens, API keys, JWTs (not even "just the
  header"), signed URLs, session identifiers;
- **connection strings and DSNs**, in any form: a config dump at startup, a "failed to
  connect" error, a struct printed with `%+v`;
- user free text — uploaded documents, message bodies, free-form answers, private
  motivation, anything the user wrote about themselves;
- contact and identity data — email addresses, phone numbers, names, precise location;
- request and response bodies of endpoints carrying any of the above, and the
  `Authorization` / `Cookie` headers;
- any field the product treats as private;
- **the content an error refused.** A parser, validator or adapter that rejects input must
  not quote the input in its message — not the page body that failed to parse, not the
  account id that was not admitted, not the line that broke the schema. The message names
  the reason class, the field or position, and a length or a hash; `invalid input: <input>`
  is the most common way the denylist above reaches a log.

**Log identifiers and shapes instead**: `user_id`, request id, byte counts, item counts,
enum outcomes, durations, error class.

Redaction is **enforced at the sink, not remembered at each call site**. A rule that lives
only in reviewer memory fails on the first hurried change.

- A redaction pass in the logger core, plus a masking `String()` on the config struct and
  on any DSN or secret type, so the unsafe form cannot be printed by accident.
- Wrap every DSN before it can reach a log line or an error message:

```go
// Keep scheme, host and database; drop the password.
func redactDSN(dsn string) string {
    u, err := url.Parse(dsn)
    if err != nil {
        return "<unparseable dsn>"
    }
    return u.Redacted() // scheme://user:xxxxx@host/db
}
```

- A driver's own connect error frequently embeds the raw DSN. Do not pass driver error
  text straight into a log field on a connection path: log your own message plus the
  redacted DSN, and keep the driver error for the wrapped chain only if it has been
  checked.

### Debugging in production without a data leak

A global "trace everything" flag cannot be switched on in production, because it would
capture every user's content. **Scope it to specific entities instead:**

- an environment variable carrying a short list of ids (`TRACE_IDS=<id>,<id>`), with
  `shouldTrace(x) = TRACE_ALL || x.id ∈ TRACE_IDS`, threaded into the step loggers;
- one job, run or conversation can then be traced in production, bounded to that single
  subject;
- the captured trace holds **derived values and step outputs**, never raw user input, and
  the field is omitted from the normal API response entirely;
- state the retention, and remove the ids when the investigation ends.

## 5. Making silent failures observable

A silent failure is a failure with no observable. The code shapes below are the ones that
produce them; each row names the observable that turns it into something findable.

| Code shape | What it looks like in production | Add this |
|---|---|---|
| discarded error — `_ = f()`, `v, _ := f()` | nothing at all: no log, no metric, no alert | handle it, or log at `warn` with the reason it is ignorable |
| `if err != nil { return nil }`, or a zero value returned on failure | an empty page or a missing field that a user reports weeks later | return the error; if a fallback is deliberate, count it |
| error logged, then execution continues | one line in a stream of millions; nothing fires | decide: fail, or take a **named** fallback and count it |
| error logged at every layer | five lines per failure, none of which is the cause | log once at the boundary; wrap with `%w` on the way up |
| an optional signal computed optimistically that yields empty when an input fails to resolve | the feature quietly stops working — no error, no alert, no failing test | when the inputs were present but the output is empty, log `warn` naming both raw inputs, and count it |
| `recover()` that swallows a panic | a 500, or worse a 200 with a partial body | re-surface or log with stack and request id; `panics_total` |
| consumer acks before the work succeeded | message loss with a perfectly green dashboard | ack after success; count nacks/requeues; alert on the dead-letter queue |
| network / DB / broker call with no deadline | a goroutine stuck for hours while the pod reports healthy | a context deadline on every I/O call; `timeouts_total{dependency}` |
| retry loop with no cap and no counter | a dependency outage amplified into a thundering herd | bounded retries with jitter; `retries_total{dependency}` |
| deferred `Close()` on a write path with the error dropped | truncated or lost data, no signal | check the error and surface it |
| transactional work with no rollback on the error path | partial writes that look like data corruption later | `defer` the rollback; count failed transactions |

Two rules follow from the table:

- **Every fallback is a named, counted event.** "It degrades gracefully" without a counter
  means "we will find out from a user".
- **An alert-worthy condition needs a metric, not a log line.** Logs explain after the
  fact; metrics are what fire.

**Before metrics exist, and inside libraries.** The observables above assume a service with
a metrics registry. Two common situations lack one:

- *No metrics yet* (a CLI, a service before its first deploy): the `recover()` handler still
  logs the stack with the request or run id and still surfaces the failure — a 500, or a
  typed error to the caller. Register `panics_total` and the other degradation counters
  with the **first** metrics registration; until then the log line is the observable, and
  the definition of done says so rather than claiming a counter that does not exist.
- *A library or engine* whose audit trail lives in its own state (an interpreter, a workflow
  runtime): it holds no logger and no registry. It returns the recovered panic as a typed
  result the caller can log and count, and records the event in its own trail if it keeps
  one. The service that embeds it owns the metric.

The go pack ships a `silent-failure-hunter` agent that greps for exactly these shapes —
run it after writing error-handling, adapter or consumer code.

## 6. Metrics

Keep the set small and deliberate. The list below, not a metric per function.

| Family | Metrics | Type | Labels |
|---|---|---|---|
| inbound traffic (rate, errors, duration) | `http_requests_total`, `http_request_duration_seconds`, `http_requests_in_flight` | counter, histogram, gauge | method, route pattern, status |
| outbound dependencies | `dependency_request_duration_seconds`, `dependency_errors_total` | histogram, counter | dependency, operation, outcome |
| database pool | in-use, idle, wait count, wait duration | gauge, counter | — |
| queue / broker consumer | `messages_processed_total`, `message_processing_duration_seconds` | counter, histogram | queue, outcome (`ok`/`retry`/`dead`) |
| backlog | `queue_depth`, `consumer_lag_messages` | gauge | queue or topic |
| jobs and pipelines | `job_runs_total`, `job_duration_seconds`, `job_step_duration_seconds` | counter, histogram | kind, step, outcome |
| degradation | `fallback_total{reason}`, `retries_total`, `timeouts_total`, `panics_total` | counter | bounded enums |
| runtime | goroutines, heap, GC pause, open file descriptors, build info | — | register the runtime collector; never hand-roll these |
| business outcomes | a handful of counters that map to what the product promises | counter | bounded enums only |

Naming and units:

- `<namespace>_<subject>_<unit>`, `_total` suffix on counters.
- **Base units only** — seconds, bytes, ratios in 0..1. Never milliseconds or megabytes;
  the dashboard converts, the metric does not.
- **Histogram buckets are chosen for the objective**, not copied from the defaults. If the
  target is 300 ms, the buckets need resolution around 300 ms or the percentile is fiction.
- One metric per meaning. `requests_from_web_total` is a label, not a metric name.

### Cardinality discipline

**Never label a metric with an unbounded value.** The series count is the *product* of
every label's distinct values, and every series occupies memory in the scraper and the
store. A single `user_id` label on one counter in a service with a million users is a
million series — it takes down the metrics backend rather than the service, and the
dashboards die exactly when they are needed.

| Never a label | Use instead |
|---|---|
| user id, session id, request or trace id, email | keep it in logs — searchable, and it ages out with retention |
| raw URL path containing identifiers | the route pattern (`/v1/items/{id}`) |
| error message or exception text | a small error-class enum |
| full SQL statement | the operation name |
| free text, or anything derived from user input | a bounded enum, or nothing |
| application / job / run / message id | logs, or a durable per-run record |
| timestamp, epoch, version-with-commit | one `build_info` gauge carrying the version as a label |

- **The test: can you write down the complete list of a label's values?** If not, it is not
  a label.
- Budget per service and multiply before shipping: five labels with ten values each is
  100 000 series on **one** metric.
- Status code or status class as a label is fine — both are bounded.
- The scrape target already adds pod and instance labels that churn on every deploy; a
  high-cardinality application label multiplies with them.

### Exposure

- `/metrics` on the application port for the scraper, and **not reachable from the public
  internet** — it enumerates internal route names, dependency names and error classes.
  Use a separate admin listener when the application port is publicly exposed.
- If the infra pack's `kubernetes-helm` skill is installed, follow it for scrape
  annotations and the port naming; otherwise follow the project's own conventions.

## 7. Stay ready for tracing

Do not adopt distributed tracing on day one; do not preclude it either.

- `context.Context` is the first parameter of anything doing I/O, and it is propagated —
  never replaced with `context.Background()` mid-chain.
- The correlation id lives in the context, not in a struct field.
- Instrumentation lives in middleware and adapters, never in `domain`.
- If an inbound trace id already exists, reuse it as the correlation id rather than
  inventing a second identifier.

Adding OpenTelemetry later is then a middleware plus a client wrapper — not a refactor of
domain logic.

## 8. Test policy

**Do not generate tests nobody asked for.** An unrequested test file inflates the diff,
freezes an interface the author had not settled, and tends to assert what the code
*currently does* rather than what it *should do* — which is worse than no test, because it
is now evidence. Say what is worth testing; write them when asked. A bug fix is the
exception: the reproduction test ships with the fix.

When asked:

- **Test domain and application logic first** — the rules that are expensive to get wrong.
  Adapters get a thin test that the mapping and the error translation work.
- **Table-driven**, one struct per case with a `name`, run through `t.Run(tc.name, …)`.
  Name cases after the behaviour, never `case1`.
- **Avoid over-mocking.** Mock the process boundary — the network, the clock, an external
  gateway — not your own layers. A test that mocks everything it touches asserts the mock.
  Prefer a real database in a container for repository logic; if the process pack's
  `integration-testing` skill is installed, follow it for how those run.
- An assertion library is fine where it earns its place; plain comparisons are the default
  in some repos. If the `go-conventions` skill is installed, follow its library table.
- **No `time.Sleep` for synchronization** — channels, `sync.WaitGroup`, or poll-with-
  deadline.
- **The one accepted wait: proving absence.** "No second send happened" cannot be asserted
  at an instant. Advance an injected clock past the point where the effect would have
  fired and assert the counter is unchanged; only where the clock cannot be injected, wait
  a bounded few loop ticks with a comment naming what the wait proves. A bare sleep with
  no assertion after it proves nothing.
- **Deterministic**: injected clock, seeded randomness. A flaky test is fixed or deleted,
  never retried in CI.
- Always `-race`.
- **Coverage is a diagnostic, not a target.** A coverage gate produces tests that execute
  lines without asserting anything.

### Assert behaviour and shared constants — never a retyped user-visible string

A test must not contain its own copy of a string the product shows to a user. Import the
constant.

```go
// BAD — a second source of truth. It drifts on the first wording change,
// and if the literal was typed wrong, both copies are wrong and the test is green.
if got := msg.Text; got != "Your report is ready. Want a different format?" { … }

// GOOD — assert the behaviour, or compare against the single source of the string.
if got := msg.Text; got != ui.ReportReadyPrompt { … }
if !msg.HasAction(ui.ActionRegenerate) { … }
```

Why it matters: a retyped literal makes copy-editing and translation work fail tests that
have nothing to do with the change, and it hides typos. Where the exact wording genuinely
carries a guarantee (a legal notice, an honesty disclaimer), assert against the exported
constant **and** test the rule separately — "a disclaimer is present whenever X" — so the
guarantee survives a rewording. If the frontend pack's `i18n-conventions` skill is
installed, the shared constant is the message key; otherwise follow the project's own
conventions.

**Exception: when the text is the contract.** A compiler or linter diagnostic, a CLI's
machine-parsed output, a protocol error string — text that tools, scripts or a spec depend
on verbatim — is asserted verbatim, against a golden file or the exported constant, and a
change to it is reviewed as a contract change. The rule above targets product copy a human
reads, where the wording is free to change and the *behaviour* is what the test must pin.
Say in the test which kind it asserts.

## 9. Linters

Assume `golangci-lint` with at least:

| Linter | Catches |
|---|---|
| `govet` | printf argument mismatches, lost struct tags, copied locks, unreachable code |
| `staticcheck` | the deep bug set: impossible conditions, stdlib misuse, dead branches |
| `errcheck` | unchecked returned errors — the highest-value linter for §5 |
| `unused` | dead identifiers |
| `gosimple` | simplifications (folded into `staticcheck` in recent versions — keep whichever the pinned version exposes) |
| `ineffassign` | assignments that are never read |
| `gosec` | hardcoded credentials, SQL built by concatenation, weak randomness, unchecked integer conversions, permissive file modes |

Worth adding once the codebase is clean: `errorlint` (`%v` where `%w` was meant, `==`
where `errors.Is` was meant), `bodyclose`, `noctx`, `contextcheck`, `rowserrcheck`. **Add
one at a time**, each with its own clean-up commit — five at once produces a thousand
findings and a `//nolint` habit.

- Write code that passes the set. **Do not relax the config to make a finding go away.**
- `//nolint:<linter> // <reason>` only: a named linter and a written reason. A bare
  `//nolint` is a silent suppression. Never suppress a `gosec` or `errcheck` finding
  without explicit approval.
- Beyond what the linters catch, watch for: default or hardcoded credentials, SQL
  assembled by string building instead of parameters, unsafe integer conversions,
  `math/rand` where `crypto/rand` is required, world-readable file permissions,
  unvalidated redirects, and TLS verification disabled "for now".

**`gosec` findings that fire on legitimate code.** Several rules trip on CLIs, test
infrastructure and API clients by design — G204 (subprocess with a variable), G302 (file
mode with `chmod`), G304 and G703 (a user-named path), G704 (a request to a variable URL).
Each has an approved restructuring, listed in
[`references/gosec-patterns.md`](references/gosec-patterns.md); apply the restructuring
first. Where it is applied and the finding still fires, the suppression is
**pre-approved** — in the form `//nolint:gosec // G304: path is rooted at <dir> via os.Root`,
rule id and reason both mandatory. (`gosec` run standalone rather than through
`golangci-lint` reads its own form, `//#nosec G304 -- <reason>`.) Every other `gosec`
finding keeps the explicit-approval rule above.

**Where the linter is invoked is not this skill's business.** The linter *set*, and the
expectation that the code passes it, live here. The `lint` target that runs it and the
fan-out across modules belong to the Makefile — if the infra pack's
`makefile-conventions` skill is installed, follow it for the target contract; otherwise
run `golangci-lint run` per module. The local verification gate as a whole is
`go-conventions` §10; this skill adds only that the linter is part of it.

## 10. Definition of done

- [ ] `/healthz` succeeds without touching any dependency.
- [ ] `/readyz` checks every dependency the service cannot serve without, each with its own
      deadline, result cached briefly, and flips to not-ready on shutdown before the
      listener closes.
- [ ] Without an orchestrator, the readiness body lists every loop as running or disabled
      with a reason.
- [ ] Logs are structured, one line per event, carrying service, version, env, level and
      correlation id on every line.
- [ ] The correlation id is accepted or generated at the boundary, held in the context,
      propagated to every outbound call, message and job, and returned to the caller.
- [ ] Redaction is enforced at the sink; no DSN, token or user content can reach a log
      line, including the startup config summary.
- [ ] No error or refusal message embeds the content it rejected.
- [ ] Every deliberate fallback is logged at `warn` **and** counted.
- [ ] `/metrics` exposes request rate/latency/errors, dependency latency, backlog where
      applicable, and the runtime collector — and is not publicly reachable.
- [ ] No metric label carries a user id, request id, raw path or error message; every
      label's value set is enumerable.
- [ ] Alert-worthy conditions are metrics, not log lines.
- [ ] The linter set runs clean; every `//nolint` names a linter and a reason.
- [ ] Tests assert behaviour and shared constants — no retyped user-visible string, and a
      diagnostic asserted verbatim is marked as contract text — and no test was added that
      nobody asked for.
- [ ] Tests pass with `-race` and contain no `time.Sleep` synchronization.

---

## Project delta

The consuming repository must supply:

1. **Health endpoint paths** if not `/healthz` and `/readyz`, and the readiness response
   shape.
2. **Which dependencies are readiness-critical** and which degrade instead, per service.
3. **The logger library and its configuration** — level variable, encoder, sampling.
4. **The correlation id header name**, and whether an inbound id is trusted or always
   regenerated.
5. **The private-field denylist** — what counts as user content in this product, and where
   the redaction pass lives.
6. **The metric namespace or prefix**, the label conventions, and the scrape path and port
   if not `/metrics` on the application port.
7. **Whether a scoped-trace mechanism exists** — the variable that carries the ids, what
   the trace captures, and its retention.
8. **The latency objective** the histogram buckets are chosen for.
9. **The `.golangci.yml` in force**, whether it is per-service or repo-wide, and any
   linter added or excluded beyond the set above, with the reason.
10. **The test layout**, the assertion library if any, and where shared user-visible
    string constants live.
11. **Where alert rules are defined** and who receives them.
