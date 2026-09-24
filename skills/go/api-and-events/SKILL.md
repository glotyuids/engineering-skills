---
name: api-and-events
description: HTTP and asynchronous message contracts between services — versioned public routes and a separate internal path space, the internal API-key header and its mandatory strip at the edge, OpenAPI as the source of truth with generated clients, status codes and error bodies, pagination, idempotency keys (and update-id deduplication for polled feeds), contract versioning, and messaging rules (versioned event contracts, open versus closed contracts, the proto3 JSON traps, idempotent consumers, ack-after-durable, dead-letter handling, and when a broker is justified at all). Use when adding or changing an endpoint, writing or updating an OpenAPI spec, choosing a status code or error shape, paginating a list, making a POST retry-safe, breaking or versioning a contract, exposing an internal route, configuring the edge proxy, publishing or consuming an event, defining a message schema, or asking "should this be a queue", "why did we process this message twice", "what belongs in the dead-letter queue".
license: Apache-2.0
metadata:
  source: glotyuids/engineering-skills
  version: 0.1.2
---

# API and event contracts

How services talk to each other and to the outside world: the shape of the HTTP surface,
the specification that defines it, and the rules for asynchronous messages.

**This skill defines only the contract between processes** — path shapes, the internal
authentication header, the OpenAPI spec and its generated clients, status codes and error
bodies, pagination, idempotency, contract versioning, and message/event contracts. It does
**not** define service-internal layout, the dependency rule, handler code style or the
verification gate — those belong to `go-conventions` in this pack. It does not define
ingress objects, TLS, certificates, secret storage or how the edge is deployed; if the
`kubernetes-helm` and `secrets-management` skills are installed, follow them for that,
otherwise follow the project's own conventions. Where a project already has an established
contract style that differs, the project wins — be consistent with the existing surface
rather than introducing a second dialect.

---

## 1. Transport choice

**Synchronous request/response over HTTP is the default**, both for external clients and
for service-to-service calls. A message broker is introduced deliberately, not by habit.

Introduce a broker only when at least one of these is true, and say which one:

| Justification | Example |
|---|---|
| The work outlives a request deadline | long document processing, batch export |
| Fan-out to consumers the producer must not know about | audit, search indexing, notifications |
| The producer must keep working while a consumer is down | ingestion that cannot drop input |
| Bursts must be smoothed against a slow or rate-limited downstream | third-party API with a quota |
| Work is scheduled, delayed or retried over long windows | retry after an hour, nightly reconciliation |

"It feels more decoupled" is not a justification. A broker adds a delivery-semantics
problem, a schema-evolution problem, a dead-letter problem and an ordering problem to every
consumer that touches it. A service whose asynchronous work is a task queue plus an
in-process runner needs no broker at all.

Record the decision where the project records architecture decisions, with the trigger from
the table above.

## 2. Path space: public and internal are separate

Two disjoint route spaces, never interleaved:

| Space | Shape | Reachable from | Authentication |
|---|---|---|---|
| Public / external | `/api/<domain>/v1/...` | the internet, through the edge | end-user credential (token/session) |
| Internal (service-to-service) | `/api/<domain>/internal/...` | inside the cluster network only | internal API-key header |
| Operational | `/healthz`, `/readyz`, `/metrics` | platform and scrape targets only | none, but never exposed publicly |

Rules:

- The **public space is versioned in the path** (`/v1/`). The version is part of the
  contract, not a header, so it is visible in logs, routing rules and client code.
- The **internal space carries no public version**; it evolves under the compatibility
  rules in §6. It is a separate space precisely so that internal endpoints are never
  reachable by an external client that guesses a URL.
- Never place an internal-only capability behind a public path "protected" by an
  undocumented parameter. Path space is the boundary.
- Resource paths are plural nouns; the verb is the HTTP method. Actions that are genuinely
  not CRUD get a sub-resource (`POST /api/<domain>/v1/orders/{id}/cancel`).
- Route-level middleware, not per-handler checks, enforces which space a handler is in. A
  handler must not be registered in both spaces.

## 3. The internal API-key header

Service-to-service calls carry an internal API-key header — written here as
`X-Internal-API-Key`; the exact spelling is a project delta. The receiving service verifies
it in middleware mounted on the whole internal route space, using a constant-time
comparison, and rejects with `401` when it is absent or wrong.

**The edge MUST strip this header from every inbound request before it reaches any
service.** If the edge (`LB`, ingress or API gateway) forwards a client-supplied
`X-Internal-API-Key`, an external caller can set the header themselves and reach the entire
internal route space of every service behind it. A missing strip is a complete
authentication bypass, not a hardening gap.

The rule in full:

1. The edge deletes the header on every inbound request, on **all** public routes,
   unconditionally — not only on the routes that currently exist.
2. Stripping is configured once at the edge and asserted by a test, not assumed. The test
   sends a forged header from outside and expects `401`/`404`, never `200`.
3. Services still verify the header themselves. The edge strip and the middleware check are
   two independent layers; neither is allowed to be the only one.
4. The key value comes from `SECRET_MANAGER` through the environment. It is never a default
   in code, never in a chart's plain values, never logged, and never echoed in an error.
5. Rotation is two-phase: accept old **and** new, roll every caller, then drop the old.
6. The header is not an authorisation decision. It says "this call came from inside"; it
   does not say which end user it acts for. Propagate the subject explicitly.
7. `Verify:` if the project's edge configuration is not in this repository, confirm the
   strip exists before treating internal endpoints as protected, and say plainly that it is
   unverified if you cannot.

Apply the same treatment to any other trust-carrying header the platform injects (for
example a forwarded subject or trace-trust header): strip inbound, set internally.

## 4. OpenAPI is the contract

Every HTTP API — public **and** internal — is described by an OpenAPI document.

- Location: `api/openapi/`, one document per service (split with `$ref` when it grows).
- **The spec is updated in the same change as the handler.** A merged change whose spec
  no longer matches its handlers is a broken contract, not a follow-up task.
- The spec is the source of truth for clients and, where the toolchain supports it, for
  server stubs. Generate; do not hand-write a client that will drift.
- Generated code is either committed or produced by the build — pick one per repo and be
  consistent. CI regenerates and fails on a diff, which is what makes "spec is the source
  of truth" true rather than aspirational.
- Never hand-edit generated files. Change the spec and regenerate.
- Shared components (`Error`, `Page`, `Problem`) are declared once under `components/` and
  referenced, so every endpoint returns the same shapes.
- Examples in the spec are real, valid payloads. They are what consumers copy.

Working order for any endpoint change: **spec → regenerate → implement → test → review the
spec diff as the contract change it is.**

## 5. Requests, responses and errors

- JSON over HTTPS, `application/json; charset=utf-8`, `snake_case` or `camelCase` chosen
  once per project and never mixed.
- Timestamps are RFC 3339 in UTC with an explicit offset. Durations are explicit units in
  the field name (`timeout_ms`), never bare numbers.
- Identifiers are opaque strings to clients. Do not expose auto-increment primary keys.
- Money is an integer minor unit plus a currency code, never a float.
- Unknown request fields are rejected on write endpoints; unknown **response** fields must
  be tolerated by clients (see §6). Message contracts choose per file between the same two
  behaviours — open or closed, §7.

### Status codes

| Situation | Status |
|---|---|
| Read succeeded | `200` |
| Resource created | `201` + `Location` |
| Accepted for asynchronous processing | `202` (with a way to poll the result) |
| Succeeded, nothing to return | `204` |
| Malformed body, bad parameter, failed validation | `400` |
| Missing or invalid credential | `401` |
| Valid credential, not permitted | `403` |
| Unknown resource, **or a resource owned by someone else** | `404` |
| Conflict: duplicate, version mismatch, illegal state transition | `409` |
| Idempotency key reused with a different body | `409` |
| Payload too large | `413` |
| Rate limited | `429` + `Retry-After` |
| Unhandled server fault | `500` |
| Dependency unavailable or timed out | `503` / `504` |

`404` for a not-owned resource is deliberate: `403` confirms the resource exists and leaks
it. Pick either `400` or `422` for semantic validation failures and use it everywhere; do
not mix.

### Error body

One shape for every error the service can return, declared once in the spec:

```json
{
  "error": {
    "code": "validation_failed",
    "message": "field 'title' must not be empty",
    "details": [{ "field": "title", "reason": "required" }],
    "request_id": "01J8ZQ4M4T2C6K9V3W1XN0YB7Q"
  }
}
```

- `code` is a stable, machine-readable vocabulary defined in the spec. Clients branch on
  `code`, never on the prose in `message`.
- `message` is for a human reading a log or a developer console.
- `request_id` is the correlation id and is also returned on success responses; it is what
  makes a user's report traceable. If the `observability-and-quality` skill in this pack is
  installed, follow it for how the id is generated and propagated.
- **Never leak internals**: no SQL, no stack traces, no driver text, no internal hostnames
  or upstream URLs, no PII echoed back. Log the detail, return the code.
- Map domain errors to status codes in exactly one place at the transport boundary, not per
  handler.

### Pagination

- Every collection endpoint is paginated from day one. An unpaginated list is an outage
  waiting for the table to grow.
- **Cursor pagination is the default** for anything large, append-heavy or concurrently
  mutated. Offset pagination is acceptable only for small bounded sets and must be
  documented as such — offsets skip and duplicate rows under concurrent writes.
- Response envelope is uniform: `{"items": [...], "next_cursor": "…" | null}`. `items` is
  always present and never `null`.
- `limit` has a default and a hard maximum; clamp server-side and never trust the client.
- Sort on a stable key with a tiebreaker (`created_at, id`). A non-unique sort key silently
  drops or repeats rows across pages.
- Cursors are opaque, signed or encoded — never a raw offset the client can craft into a
  scan of somebody else's data.

### Idempotency

- `GET`, `PUT` and `DELETE` are idempotent by definition — implement them that way.
- Any `POST` that creates a resource or moves money, credits or quota accepts an
  `Idempotency-Key` header. The server stores key → (request fingerprint, response) scoped
  to the authenticated subject, replays the stored response on retry, and returns `409` if
  the same key arrives with a different body. Give stored keys an explicit TTL.
- Clients retry only on `408`, `429`, `5xx` and network failures, with exponential backoff
  and jitter, honouring `Retry-After`. Never retry a `4xx` other than `429`.
- Every outbound call has a timeout derived from the caller's context. No unbounded call
  ever, in either direction.
- **A pulled feed is a consumer.** When the service polls an external API for updates (a
  bot long-poll API is the typical example) there is no header to send: the provider's
  per-update id is the deduplication key. Record it in the processed-ids table in the same
  transaction as the effect, exactly as §7 requires of a broker consumer; derive the
  idempotency keys of every downstream call from that id, so a re-delivered update cannot
  fan out twice; give every callback or interactive control a single-use nonce spent in
  the same transaction; and treat the acknowledged offset as at-least-once — after a crash
  between effect and acknowledgement the provider re-sends everything since it.

## 6. Contract change rules

Additive changes are safe within a version; everything else is a new version.

| Change | Safe within `v1`? |
|---|---|
| New endpoint | yes |
| New **optional** request field with a safe default | yes |
| New response field | yes — provided consumers ignore unknown fields (an **open** contract, §7); a **closed** contract needs a new version |
| New enum value in a response | only if consumers have a documented fallback |
| Removing or renaming a field | no |
| Changing a field's type, units or meaning | no |
| Making an optional request field required, or tightening validation | no |
| Changing which status code an outcome returns | no |

- Breaking changes ship as a new path version, with both versions served for a documented
  deprecation window, and the old one instrumented so the switch-off is evidence-based.
- Rename with expand/contract: add the new field, write both, migrate consumers, stop
  writing the old, remove it. Three releases, never one.
- **Internal endpoints follow the same rules whenever publisher and consumer deploy
  independently** — which, under a rolling deployment, is almost always. Only a change that
  ships atomically with every caller may skip the dance.
- Deprecation is announced in the spec (`deprecated: true` plus a note saying what replaces
  it and when it goes), not in a chat message.

## 7. Message and event contracts

### Where they live

- `api/events/v<n>/` — one file per message type, versioned by directory, so `v1` and `v2`
  of a message can coexist while consumers migrate.
- JSON Schema or protobuf. Whichever the project picks, the contract file is authoritative
  and the producer's struct is generated from or validated against it.
- **Protobuf JSON is not plain JSON.** The proto3 JSON mapping encodes every 64-bit integer
  (`int64`, `uint64`, `fixed64`, `sint64`, `sfixed64`) as a decimal string, does not emit
  `null`, and on parsing treats `null` as "unset" — indistinguishable from an absent
  field. So: an example that shows a bare number for a 64-bit field will not match what
  the producer emits; a consumer written against hand-drawn JSON breaks on the first id
  above 2^53; and "present but null" is not a state the contract can express — model a
  tri-state value explicitly (a wrapper message, or an `optional` field with presence),
  never as `null`.
- Every field documents its semantics, whether it is required, its units and its enum
  values. A field named `status` with undocumented values is not a contract.
- Routing (topic/queue/subject names, keys, bindings) is part of the contract and is
  written down next to the schema, not only in deployment configuration.

### Open and closed contracts

Declare, per contract file, which of the two it is — the consumer rules differ:

| Kind | Unknown fields | Evolution | Typical use |
|---|---|---|---|
| **Open** | tolerated by consumers, never depended on | additive within a version | notifications with many independent consumers |
| **Closed** | rejected — an unknown field fails validation | any change is a new version | a domain contract that is also a stored record; anything carrying authority (grants, limits, epochs, revisions) |

A closed contract exists because silently accepting a field you do not understand is a
way to accept a meaning you did not check. When one schema is both the stored record and
the event payload — `api/contracts/` if the `go-conventions` skill is installed, otherwise
wherever the project keeps domain contracts — it is closed.

### Envelope

Every message carries one envelope, whatever the broker. The names below are an
**illustration, not a standard**: a project with an existing envelope — one carrying a
fencing epoch, an expected revision, a causation id — keeps its own and names its fields
in the project delta. What is not negotiable is that each *role* below is filled by some
field:

| Role (illustrative name) | Meaning |
|---|---|
| `event_id` | unique per emission — the deduplication key |
| `event_type` | fully qualified name, e.g. `<domain>.order.created` |
| `event_version` | schema version of the payload |
| `occurred_at` | RFC 3339 UTC, when the fact happened (not when it was published) |
| `producer` | emitting service name |
| `subject_id` | the aggregate the event is about — also the ordering/partition key |
| `correlation_id` | trace/request id carried from the originating call |
| `payload` | the typed body defined by the contract |

**Never put secrets or PII in a message payload.** Messages persist in broker storage,
mirrors, dead-letter queues and operator dumps far longer than a request does. Pass an
identifier and let the consumer fetch what it is entitled to see.

### Consumers

- **Consumers MUST be idempotent. Redelivery is normal, not exceptional** — it happens on
  ack loss, consumer restart, rebalance, timeout and retry. Delivery is at-least-once;
  exactly-once is a marketing claim, not a runtime guarantee.
  Achieve it by either:
  1. recording `event_id` in a processed-messages table with a unique constraint, inserted
     in the **same transaction** as the effect, so a duplicate loses the insert and the
     handler returns early; or
  2. making the effect naturally idempotent — an upsert keyed by `subject_id`, or a state
     transition guarded by its precondition.
- **Acknowledge only after the work is durable.** Commit the transaction, then ack. Never
  ack on receipt and process afterwards: a crash in between destroys the message with no
  trace. Ordering is commit-then-ack, always.
- **Be explicit about ack / nack / requeue per handler**, in code and in the contract doc:
  which failures are transient (nack, retry with capped attempts and backoff) and which are
  permanent (do not requeue — dead-letter immediately).
- **Validate defensively at the boundary.** Parse and validate the envelope and payload
  before touching domain state. A malformed or unknown-type message is a permanent failure:
  dead-letter it, do not spin. On an **open** contract tolerate unknown fields (forward
  compatibility); on a **closed** one reject them. Reject missing required fields on both.
- **Bound prefetch and concurrency.** A consumer that holds more unacked messages than it
  can finish inside the broker's visibility/ack timeout manufactures its own duplicate
  storm.
- **Do not assume ordering.** Order holds, at best, per partition/queue and per key. If
  order matters, key by `subject_id` and make handlers tolerate out-of-order arrival with a
  sequence or version check — do not rely on the broker.
- A consumer is an adapter. It translates the message into a use-case call and does nothing
  else; business rules stay out of the subscriber.

### Dead letters

- **Every subscription has a dead-letter destination.** A message is never silently
  dropped and never retried forever.
- Cap attempts; on exhaustion route to the DLQ with the failure reason, attempt count and
  original routing metadata attached.
- **Monitor and alert on DLQ depth.** A dead-letter queue nobody watches is data loss with
  extra steps. Non-zero depth is a page-worthy or ticket-worthy signal, decided per project.
- The runbook is written before the first message lands there: inspect, classify, fix the
  cause, replay to the original destination. Replay is only safe because consumers are
  idempotent — which is why the consumer rules above make it mandatory.
- Never schedule blind automatic replay from a DLQ. That converts one poison message into a
  permanent load generator.

### Publishing

- Publish **after** the transaction commits, never inside it — a publish that succeeds
  before a rollback announces a fact that never happened.
- When the message must be published if and only if the state change committed, use a
  transactional outbox: write the event row in the same transaction as the state change,
  and let a relay publish it and mark it sent, at-least-once. If the `postgres-patterns` or
  `database-migrations` skills are installed, follow them for the outbox table and its
  migration; otherwise follow the project's own conventions.
- Without an outbox, the failure mode (committed state, unpublished event) is real —
  document it and add reconciliation, or adopt the outbox. Do not pretend it cannot happen.
- Producers own their contract's compatibility: additive changes only within a version;
  anything else is a new `event_version` and a new directory, with both published until
  consumers have migrated.

## 8. Definition of done

For an HTTP change:

- [ ] Route is in the correct space (public versioned vs internal) and mounted behind the
      matching middleware.
- [ ] OpenAPI updated in the same change; clients/stubs regenerated; CI diff clean.
- [ ] Status codes and error bodies follow §5, including `404` for not-owned resources.
- [ ] Collections paginated with a stable sort and a clamped limit.
- [ ] Creating `POST`s accept an idempotency key; a polled feed dedupes on the provider's
      update id; outbound calls have timeouts.
- [ ] The change is additive, or it is a new version with a deprecation plan.
- [ ] For any new public route: the edge still strips `X-Internal-API-Key`, asserted by a
      test. If the `integration-testing` skill is installed, follow it for where that test
      lives; otherwise follow the project's own conventions.

For a messaging change:

- [ ] Contract file added or updated under `api/events/v<n>/`, with routing documented.
- [ ] The contract file says whether it is open or closed, and the consumer's unknown-field
      behaviour matches.
- [ ] Envelope complete; no secrets or PII in the payload.
- [ ] Consumer is idempotent, with the dedupe mechanism named and tested by redelivering
      the same `event_id` twice.
- [ ] Ack happens only after the work is durable.
- [ ] Transient vs permanent failure classification is explicit; retries are capped and
      backed off.
- [ ] Dead-letter destination exists, is alerted on, and has a replay runbook.
- [ ] Publisher's commit/publish ordering is correct, or an outbox is in place.

---

## Project delta

The consuming repository must supply:

1. **Route domain segments** — the `<domain>` values used in `/api/<domain>/v1/…` and
   `/api/<domain>/internal/…`, and the current public version.
2. **The exact internal header name**, the middleware or shared package that verifies it,
   and how its value reaches the process from `SECRET_MANAGER`.
3. **The edge component** (`LB`, ingress or gateway), the configuration that strips the
   header inbound, and the location of the test that proves the strip.
4. **Spec location and toolchain** — path under `api/openapi/`, the generator, and whether
   generated code is committed or produced by the build.
5. **Error contract** — the JSON shape, the `code` vocabulary, and the domain-error → status
   mapping in force.
6. **Case convention** for JSON fields, and the choice between `400` and `422` for semantic
   validation failures.
7. **Pagination style** (cursor or offset), default and maximum `limit`, and the cursor
   encoding.
8. **Idempotency-key storage** — where keys are persisted and their TTL; for a polled feed,
   the processed-update table and the offset it acknowledges.
9. **Whether a broker exists at all**, which one, and the recorded justification.
10. **Event contract directory and format** (JSON Schema or protobuf), whether each
    contract is open or closed, and the envelope field names actually used.
11. **Deduplication store** — the processed-messages table and its retention.
12. **Dead-letter naming, maximum attempts, alert route and replay runbook location.**
13. **Deprecation window** for a superseded API or event version.
