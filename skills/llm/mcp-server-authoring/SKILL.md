---
name: mcp-server-authoring
description: Design and ship a Model Context Protocol (MCP) server that agents use well — whether a server beats a CLI or a library, choosing the primitive (tools for actions, resources for readable context, prompts for user-invoked flows), a small well-named tool surface whose descriptions are the whole interface, validated input schemas, outputs shaped for a model rather than a human, errors that tell the agent how to recover, destructive operations gated behind explicit confirmation, idempotency, pagination and state handles under a stateless protocol, stdio versus HTTP transports, authorization and never taking a credential as a tool argument, versioning the tool surface, and testing against a real agent loop. Use when writing or reviewing an MCP server, adding or renaming a tool, writing a tool description or input schema, deciding tool versus resource versus prompt, or asking "should this be an MCP server", "why does the model keep calling the wrong tool", "how do I authenticate an MCP server".
license: Apache-2.0
metadata:
  source: glotyuids/engineering-skills
  version: 0.1.0
---

# Authoring an MCP server

An MCP server is a contract with a reader you never meet: a language model, in a host you
do not control, with your tool list already resident in its context. This skill covers how
to design that contract so the model picks the right tool, fills it correctly, recovers
from failure, and cannot be talked into destroying something.

**This skill defines only the server side of the protocol** — whether to build one at all,
which primitive to expose, tool naming, descriptions, schemas, result shapes, error
contracts, consent gating, state and idempotency, transport choice, authorization,
surface versioning, and how to test. It does **not** define how a *host* should treat tool
output once it arrives (if the `llm-pipeline-rules` skill is installed, follow it for
that), how to write agent-facing instructions in general (`skill-authoring` in this pack),
where credentials are stored (if the `secrets-management` skill is installed, follow it;
otherwise the project's own conventions), or the language and layout of the implementation.

**Maturity:** this skill is written against the published specification and the failure
modes of consuming MCP servers, not against an operated fleet of them. Statements about the
wire protocol are checkable against the spec; statements marked `Verify:` are not. The
current revision at the time of writing is `2026-07-28`
([specification](https://modelcontextprotocol.io/specification/latest)); pin a revision
before designing anything, as several sections below assume `2026-07-28` or later.

---

## 1. Is an MCP server the right answer?

MCP is not a packaging format. It costs context on every single turn: every tool
definition you publish is resident in the model's prompt whether or not it is used. Ten
tools with fat schemas is a permanent tax on every request in every conversation.

| Consumer | Right shape |
|---|---|
| Your own code | a library / SDK |
| An agent that already has a shell and a filesystem | a CLI with `--help` (it composes, pipes and filters without protocol overhead) |
| Other services | a plain HTTP API and its specification |
| Agents in hosts you do not control, or hosts with no shell | **an MCP server** |

An MCP server earns its cost when at least one of these is true, and you should be able to
say which:

- The capability must reach agents running in third-party hosts (a desktop assistant, an
  IDE, a chat product) that will never install your CLI.
- The host must be able to gate the action behind user consent, and needs a typed,
  inspectable description of what is about to happen.
- Discovery matters: the agent must be able to *find out* what is possible without you
  writing that into a system prompt.
- The data is genuinely remote and the credential must stay server-side.

"We want an AI integration" is not a reason. If the agent already runs shell commands in
the same trust boundary, a well-documented CLI usually beats an MCP server and costs no
resident context. And use an official SDK: the JSON-RPC framing, header mirroring and
version negotiation are exactly the parts that break silently against untested hosts.

## 2. What the stateless revision changed

Revision `2026-07-28` removed the `initialize` handshake and protocol-level sessions.
Every request is self-contained: it carries the protocol version and the client's
capabilities in `_meta`. A server processes each request independently.

Consequences that bite server authors:

| Assumption from older revisions | What is true now |
|---|---|
| "I can stash per-connection state after `initialize`" | There is no session and no handshake. State spanning calls must be an explicit handle passed as an argument (§8). |
| "My tool list can depend on who connected" | List results **MUST NOT** vary per connection. They **MAY** vary by the authorization presented on the request — that is the sanctioned way to hide tools a caller may not use. |
| "I'll send the client a request mid-call" | Servers no longer initiate requests. Needing input mid-call means returning an `InputRequiredResult` (`resultType: "input_required"`) and being retried with `inputResponses` — the Multi Round-Trip Request pattern. |
| "The stream will resume after a blip" | No resumability. A broken response stream loses the request; the client re-issues it with a **new** id. Design for that (§8). |
| "I'll push updates whenever" | Change notifications flow only on a `subscriptions/listen` stream the client opened and opted into. |

Also: every result carries a required `resultType` (`"complete"` for ordinary results);
list and read results carry `ttlMs` and `cacheScope`; tool lists should be returned in a
**deterministic order** so clients can cache them and prompt caches keep hitting. Roots,
sampling and logging are deprecated — do not build on them in a new server.

## 3. Choose the primitive

| Primitive | Who decides it happens | Use for | Failure if misused |
|---|---|---|---|
| **Tool** | the model | actions and queries the model must choose to perform | a read-only lookup exposed only as a tool cannot be attached as context without spending a model turn |
| **Resource** | the host application (or the user picking from a list) | addressable, readable context: documents, schemas, records, configuration | an action modelled as a resource is invisible to the model when it needs to act |
| **Prompt** | the user, explicitly | a whole parameterised workflow the user invokes (a slash command) | a prompt that only says "use my tools" is noise in every host's command palette |

Rules of thumb:

- If the model must decide *when* it happens, it is a tool. If a human triggers a
  multi-step routine, it is a prompt, and it takes arguments.
- Read-only data the host should be able to pin into context on its own is a resource:
  a URI, a `mimeType`, listed and read via `resources/list` / `resources/read`.
  Parameterised families are resource *templates* (`<scheme>://orders/{order_id}`).
- A tool may return `resource_link` blocks instead of inlining a large payload — the model
  gets a handle, the host fetches the bytes. That is the bridge between the two.
- Most servers are "tools, plus a few resources"; shipping all three is not a goal, and one
  capability behind two primitives is one more thing for the model to get wrong.

## 4. The tool surface

**Few, well-named tools beat many overlapping ones.** The most common design error is
mirroring an existing REST API one endpoint per tool. Endpoints are organised around
resources; tools must be organised around the *workflow the agent performs*.

- Consolidate. One `schedule_event` that resolves attendees and finds a slot beats
  `list_users` + `list_availability` + `create_event`: the three-call version spends three
  model turns and three chances to go wrong.
- Split anything whose blast radius differs. One tool per operation; never an
  `action: "create" | "delete"` switch — it hides a destructive branch inside something
  that looks safe and makes the behaviour hints in §9 meaningless.
- **The overlap test:** if you cannot write a one-sentence rule that picks tool A over
  tool B, the model cannot either. Merge them, or rename until the rule is obvious.
- Keep the argument count small — around eight or fewer. More usually means the tool is
  really a workflow that should have been decided server-side.

Names: `[A-Za-z0-9_.-]`, 1–128 characters, case-sensitive, unique within your server. Use
a consistent prefix so related tools cluster and survive being merged into one namespace
with other servers' (`<service>_orders_search`, `<service>_orders_refund`). Pick
`object_verb` or `verb_object` and hold it across the whole surface.

**The description is the entire interface.** It is the only documentation the model reads,
and it is read cold. Write it the way you would brief a new hire who has your permissions
and none of your context:

1. What it does, in one sentence, in the imperative.
2. When to use it — and explicitly when *not* to, naming the sibling tool that is usually
   the right one instead.
3. What it returns, in outline.
4. Anything irreversible, rate-limited, expensive or slow. First sentence, not last.

Ambiguity in a description shows up as a wrong tool call, not a compile error. Treat
description text as production code: review it, diff it, version it.

## 5. Inputs: a real schema, and nothing secret

`inputSchema` is a JSON Schema object (2020-12 by default) and **MUST** be a valid object
schema, never `null`. For a tool with no parameters use
`{"type": "object", "additionalProperties": false}`.

- **Every property carries a `description`.** An undocumented parameter is a guess.
  Unambiguous names: `user_id`, not `user`; `start_date`, not `start`.
- Constrain: `enum` instead of free text, `format`/`minimum`/`maxLength` where they apply,
  explicit defaults for anything optional. Every constraint declared is a class of wrong
  call the model never makes.
- **Validate server-side anyway.** The schema steers a model; it enforces nothing. Reject
  unknown fields on writing tools. Servers **MUST** validate all tool inputs.
- Keep schemas local and shallow: `$ref` values resolving to a network URI **MUST NOT** be
  dereferenced automatically, and deep composition (`anyOf`/`allOf`/`$defs` nests) is a
  denial-of-service vector against the validator on the other side.
- On HTTP transports, `x-mcp-header` mirrors a parameter into an `Mcp-Param-*` header for
  routing. Use it only for routing-relevant primitives (a region, a tenant); never for
  anything sensitive — headers are visible to every hop.

**Never accept a credential — password, API key, token, card number — as a tool
argument.** Tool arguments are authored by the model, echoed in transcripts, stored in
host logs, shown in consent dialogs, and on HTTP transports may be mirrored into headers.
A credential that enters the tool surface has been disclosed. The protocol says the same
thing from the other side: form-mode elicitation **MUST NOT** request passwords, API keys,
access tokens or payment credentials — that is what URL-mode elicitation and a page on
your own domain are for (§9), and on stdio it is what the environment is for (§10).

## 6. Outputs: shaped for a model to reason over

A tool result is not an API response and not a UI. It is the next thing in a context
window, and it will be reasoned over by something that cannot scroll.

- **Return meaning, not just identifiers.** A row of opaque ids forces another call.
  Return the human-readable name *and* the id when the id is needed downstream.
- **Concise by default, detailed on request.** Give the tool a `response_format` enum
  (`concise` | `detailed`). The concise projection carries the fields a decision actually
  needs; the detailed one carries everything. The difference is routinely several-fold in
  tokens, on every call, forever.
- **Use `structuredContent` with a declared `outputSchema`** when results have a stable
  shape: servers **MUST** then conform to it and clients can validate. Also serialise the
  same data into a text block — some clients only read `content`.
- **Never return an unbounded list.** Paginate with opaque cursors (`nextCursor`; page size
  is the server's choice and clients **MUST NOT** assume one), or truncate with an explicit
  marker saying how many were omitted and how to narrow the query. Silent truncation
  teaches the model a false total. Large payloads become `resource_link`s, not inline blobs.
- **Do not pass upstream JSON through.** Every field you forward that the model cannot act
  on is pure cost. Strip internal bookkeeping, null-heavy metadata and duplicated nesting.
- **Never return secrets, tokens or PII that were not asked for** — results are logged and
  persisted far longer than a request lives. If the `llm-pipeline-rules` skill is installed,
  follow it for how output is treated on the consuming side; sanitise what you emit.

## 7. Errors that tell the agent how to recover

Two mechanisms, and choosing wrong wastes a whole turn.

| Situation | Mechanism | Why |
|---|---|---|
| Unknown tool, malformed request, unsupported protocol version, header/body mismatch, internal fault | JSON-RPC **error response** | The model cannot fix these; clients may not even surface them |
| Bad argument value, out-of-range date, upstream API failure, business-rule violation, expired handle, insufficient permission for the requested item | **tool execution error**: normal result with `isError: true` | Clients **SHOULD** feed these back to the model so it can self-correct |
| Resource does not exist | JSON-RPC `-32602` (older revisions used `-32002`) | Never return an empty `contents` array — it is ambiguous |

An error the agent cannot act on is a defect. Every tool execution error states, in order:
**what failed, which argument was responsible, what a valid value looks like, and which
tool to call to obtain one** — for example, *"Invalid `order_id`: \"ORD-1\" is not a known
order. Order ids look like \"ord_\" plus 12 characters. Call orders_search with a customer
email or a date range to find one."* Not `ERR_NOT_FOUND`, not a stack trace, and never
SQL, driver text, internal hostnames, upstream URLs or anything from a token.

Partial success is not success: when a batch tool completes some items and fails others,
say exactly which failed and why. Summarising a partial result as done is how an agent
confidently reports work it did not do.

## 8. State, retries and long-running work

There is no session. Anything spanning calls is an explicit handle: a creation tool
returns one, later tools take it as an ordinary argument, and the model is responsible for
carrying it forward.

- Handles are **opaque and high-entropy**, with a bounded lifetime stated in the creating
  tool's description ("valid for 24 hours of inactivity") so the model sees the cost of
  creating state before it does. An expired or unknown handle returns a tool execution
  error saying so, so the agent creates a new one instead of looping.
- **Possession of a handle is not authentication.** Bind it server-side to the
  authenticated principal — store under `<subject>:<handle>` where the subject comes from
  the verified token, never from an argument — and reject it for anyone else.

**Assume every call may arrive twice.** The model retries after an ambiguous result; the
client re-issues a request whose stream broke, with a new request id; a user asks again. So
creation tools take an idempotency key, or deduplicate on a natural key, and return the
existing entity rather than making a second one — if the `api-and-events` skill is
installed, follow it for the key's storage and TTL, otherwise the project's conventions.
Updates are stated as target state ("set status to X"), not deltas ("increment"), unless a
delta is genuinely what the domain means. Set `idempotentHint` honestly where this holds.

**Long-running work must not block a connection.** Beyond a few seconds, intermediaries
and client timeouts will kill it. Either return a job handle plus a `..._status` tool, or
adopt the tasks extension (`io.modelcontextprotocol/tasks`): the server returns a task
handle with a poll interval and a TTL, the client polls `tasks/get` until a terminal
status (`completed` / `failed` / `cancelled`), and mid-flight input arrives via
`tasks/update`. Only return a task to a client that declared the extension in its
per-request capabilities. Progress on an ordinary call flows as progress notifications on
that request's own response stream.

## 9. Destructive operations are never inferred

Only ever destroy what the user explicitly asked to destroy — not what the request implied,
not what would tidy things up, not what the model concluded was obsolete. Make that
structurally hard to get wrong:

1. **Separate tool, separate name.** Deletion never rides along inside an update tool.
2. **Explicit targets only.** Take identifiers, never a wildcard or a filter expression. A
   `delete` that accepts a query is a mass-deletion tool with a friendly name.
3. **Validate, then commit.** Where a real dry run is possible, expose it as the default
   mode (`mode: "validate" | "apply"`) and report exactly what would change. Publishing,
   sending, charging and deleting are all better with a rehearsal.
4. **Declare behaviour hints honestly** — `readOnlyHint`, `destructiveHint`,
   `idempotentHint`, `openWorldHint`. They let a host raise a confirmation dialog or apply
   policy. They are **hints**: clients treat them as untrusted unless the server is
   trusted, and they enforce nothing. Your own authorization checks are the enforcement.
5. **Cascades go in the first sentence of the description** — "deletes the folder and
   everything inside it, permanently".
6. **Confirmation inside a call** is an elicitation returned as an `InputRequiredResult`,
   never a self-answered question — and never a form-mode one for anything secret.
7. **Frozen or immutable states get a named error and a documented path forward** ("this
   record has been finalised; create a new version with `..._create`"), so the agent stops
   retrying and does the right thing instead.

The host's consent dialog is a courtesy, not an access control. Rate-limit invocations and
authorize every one of them yourself.

## 10. Transports

| | **stdio** | **Streamable HTTP** |
|---|---|---|
| Who runs it | the client, as a subprocess | you, as a service |
| Trust boundary | the user's machine, the user's privileges | the network |
| Credentials | from the environment | OAuth 2.1 (§11) |
| Multi-tenant | no | yes — every request independently authorized |
| Framing | newline-delimited JSON on stdin/stdout | one HTTP POST per JSON-RPC message to a single endpoint |
| Cancellation | `notifications/cancelled` | the client closes the response stream |

**stdio**

- **`stdout` is the wire.** A single stray `print`, banner, progress bar or third-party
  library log line on stdout corrupts the stream and takes the server down for the whole
  session — with an error that points nowhere near the culprit. Every diagnostic goes to
  `stderr`; audit dependencies that log by default and route their output before you ship.
- One message per line; messages **MUST NOT** contain embedded newlines. Exit promptly when
  stdin closes or reads EOF — the only portable shutdown signal.
- A local server runs with the user's full privileges and may be reachable by other
  processes on the machine. Assume it will not be sandboxed.

**Streamable HTTP**

- One endpoint, POST only. Answer GET or DELETE with `405`; ignore a `Mcp-Session-Id` or
  `Last-Event-ID` header from an older client rather than honouring it.
- Requests mirror body fields into headers (`MCP-Protocol-Version`, `Mcp-Method`,
  `Mcp-Name`, any `Mcp-Param-*`). Validate that headers match the body and reject
  mismatches with `-32020` / `400`. **Never act on the header when the body disagrees** —
  that split is how a proxy and a server end up enforcing policy on different values.
- Respond with either a single JSON object or an SSE stream scoped to that request; send no
  independent requests on it. Add `X-Accel-Buffering: no` so proxies stop buffering, and
  emit periodic SSE comments as keep-alives on long-lived streams.
- **Validate the `Origin` header on every connection and answer `403` when it is
  invalid; bind a locally-run HTTP server to the loopback interface only.** Without both,
  any web page the user visits can drive the server through DNS rebinding — the documented
  reason the requirement is normative. TLS everywhere that is not loopback.

## 11. Authorization

**stdio servers should not implement OAuth.** They take credentials from the environment,
which is the client's job to supply.

**HTTP servers are OAuth 2.1 resource servers.** The shape:

- Implement Protected Resource Metadata (RFC 9728). Answer an unauthenticated request with
  `401` and a `WWW-Authenticate` carrying `resource_metadata` and the `scope` needed.
- **Validate the token on every single request.** There is no session in which to have
  validated it once.
- **Bind the audience.** The token **MUST** have been issued for *this* server, identified
  by its canonical URI via the resource indicator (RFC 8707).
- **Token passthrough is forbidden.** Never accept a token that was not issued for you,
  and never forward a client's token to a downstream API. Doing either turns your server
  into a confused deputy: downstream logs attribute the call to you, your rate limits and
  validation are bypassed, and a stolen token from an unrelated service becomes an
  exfiltration path through you. Hold your own downstream credentials, bound to the
  verified subject.
- Third-party authorization goes through URL-mode elicitation to a page on your own domain
  — the third party's credentials never transit the client — and you **MUST** verify that
  the user who opens that URL is the user the elicitation was minted for, or one user can
  hand another user's authorization to themselves.
- Authorization decisions use the verified subject from the token. Never a `user_id`
  argument, never a self-reported client identity: `clientInfo` and `serverInfo` are
  unverified display metadata and **SHOULD NOT** drive behaviour or security decisions.
- **Scopes stay minimal.** No `*`, no `full-access`. Publish the minimum for basic
  functionality and challenge for more per operation — emitting *all* scopes an operation
  needs in a single `403` / `insufficient_scope` challenge, not one at a time. Filter
  `tools/list` by granted scopes rather than failing at call time where you can.

## 12. Versioning the tool surface

The surface is a published contract whose consumers cached it and cannot be recalled.

| Change | Safe? |
|---|---|
| New tool | yes |
| New **optional** argument with a safe default | yes |
| New output field (consumers tolerate unknown fields) | yes |
| Widening an enum in an input | usually — the model may not know the new value exists until the list is re-fetched |
| Renaming or removing a tool or argument | no |
| Making an optional argument required, or tightening validation | no |
| Changing what a tool *does* under the same name | no — the worst kind |

Semantic drift under a stable name is the failure nothing catches: no error is raised, the
agent simply does something other than what its description promises. Treat a change of
meaning as a rename.

Migrating: add the new tool alongside the old one; rewrite the old one's description to say
it is deprecated, what replaces it and when it goes; emit `notifications/tools/list_changed`
when the set changes; remove after a stated window. Never reuse a retired name for different
behaviour, and prefer a better name to a `_v2` suffix.

## 13. Testing against a real agent loop

Unit tests prove the handler works. They say nothing about whether the tool is *usable*:
every interesting failure lives in the model's decision, not your code — wrong tool or none,
a plausible-but-wrong argument, a loop on an unrecoverable error, a blown context window.

So the primary test is a harness that runs a real agent loop against the running server on
realistic, multi-step tasks, and measures: task success, number of tool calls, wrong-tool
rate, tokens consumed, and recovery rate after an induced error. Run it with a realistic
competing tool list — your server is never alone in the context. Then **read the
transcripts**: wherever the model hesitated, apologised or re-tried is a sentence in a
description that is wrong.

Alongside it, contract tests that are cheap and catch regressions:

- [ ] Every declared `outputSchema` validates against real responses.
- [ ] Every documented error path is reachable and its message names a recovery action.
- [ ] `tools/list` is deterministic in order and does not vary per connection.
- [ ] Tool and argument descriptions are non-empty and mention the "when not to use it".
- [ ] A destructive tool refuses a wildcard target and requires an explicit identifier.
- [ ] stdio: nothing but protocol messages on stdout, under load and on error. HTTP: a
      token minted for another audience and a mismatched header are both rejected.

Include at least one **negative case**: a task where the correct behaviour is to refuse,
or where no tool applies and the server must not invent one. If the `integration-testing`
skill is installed, follow it for where these live; otherwise the project's conventions.

`Verify:` client behaviour varies. Confirm that the hosts you actually ship to surface
tool execution errors to the model, honour behaviour hints, and support the extensions you
rely on, before designing around any of them.

## 14. Worked example

A read tool with a token-budget control, its destructive sibling, and a recoverable error.

```json
{
  "name": "<service>_orders_search",
  "title": "Search orders",
  "description": "Find orders on the authenticated account by customer email, status or date range. Returns up to 20 matches, newest first, plus a cursor. Use it to resolve a customer's description of an order into an order id before calling any other <service>_orders_* tool. Do NOT use it to fetch one known order — call <service>_orders_get, which is cheaper and returns line items.",
  "inputSchema": {
    "type": "object",
    "additionalProperties": false,
    "properties": {
      "customer_email": { "type": "string", "format": "email", "description": "Exact email on the order. Case-insensitive." },
      "status": { "type": "string", "enum": ["pending", "shipped", "delivered", "refunded"], "description": "Filter by status. Omit for any." },
      "response_format": { "type": "string", "enum": ["concise", "detailed"], "default": "concise", "description": "concise: id, customer, status, total. detailed: adds line items, addresses, timestamps. Start concise." },
      "cursor": { "type": "string", "description": "Opaque cursor from a previous next_cursor. Omit for the first page." }
    }
  },
  "outputSchema": {
    "type": "object",
    "required": ["orders", "next_cursor"],
    "properties": {
      "orders": { "type": "array", "items": { "type": "object" } },
      "next_cursor": { "type": ["string", "null"], "description": "Pass back as `cursor`; null when there are no more." }
    }
  },
  "annotations": { "readOnlyHint": true, "idempotentHint": true, "openWorldHint": false }
}
```

Its destructive sibling — narrow, explicit, rehearsable:

```json
{
  "name": "<service>_orders_refund",
  "title": "Refund an order",
  "description": "Refunds a single order by id. Money movement is IRREVERSIBLE once mode is \"apply\"; a refunded order cannot be un-refunded. Defaults to mode \"validate\", which reports the exact amount and destination without moving anything. Use mode \"apply\" only when the user has explicitly asked for this order to be refunded.",
  "inputSchema": {
    "type": "object",
    "additionalProperties": false,
    "required": ["order_id"],
    "properties": {
      "order_id": { "type": "string", "description": "Exact order id, e.g. \"ord_8f3c21ab90de\". No wildcards or filters." },
      "mode": { "type": "string", "enum": ["validate", "apply"], "default": "validate", "description": "validate: dry run. apply: performs the refund." },
      "idempotency_key": { "type": "string", "description": "Reuse when retrying so a refund is never issued twice." }
    }
  },
  "annotations": { "readOnlyHint": false, "destructiveHint": true, "idempotentHint": true, "openWorldHint": false }
}
```

A tool execution error the agent can act on — `{"resultType": "complete", "isError": true,
"content": [{"type": "text", "text": …}]}` where the text reads:

> Cannot refund ord_8f3c21ab90de: its status is "pending", and only "shipped" or
> "delivered" orders can be refunded. To stop a pending order instead, call
> `<service>_orders_cancel` with the same order_id.

## 15. Definition of done

- [ ] The reason this is a server rather than a CLI, a library or an API is written down,
      and it is one of the reasons in §1; the protocol revision is pinned; an SDK is used.
- [ ] Each capability is on the right primitive (§3) and on only one; no pair of tools
      fails the overlap test.
- [ ] Every tool description says what, when, when-not (naming the sibling) and what it
      returns; irreversibility is in the first sentence.
- [ ] Every input property has a description, a constrained type where possible and an
      unambiguous name; inputs are validated server-side regardless of the schema.
- [ ] No tool argument, anywhere, carries a credential.
- [ ] Results are concise by default with an explicit detailed mode; every list is
      paginated or explicitly truncated; large payloads are resource links.
- [ ] Every failure the model can fix is a tool execution error naming the recovery action;
      no internal detail leaks in any message.
- [ ] Destructive tools are separate, take explicit identifiers, default to a dry run and
      carry honest behaviour hints.
- [ ] Cross-call state is an opaque handle bound server-side to the verified subject with a
      stated lifetime; creation is idempotent under retry; slow work returns a handle or a
      task rather than holding a connection.
- [ ] stdio: nothing but protocol messages on stdout, ever. HTTP: `Origin` validated,
      loopback-bound when local, TLS otherwise, header/body agreement enforced.
- [ ] HTTP: tokens validated per request and audience-bound; no token is accepted or
      forwarded that was not issued for this server; scopes are minimal.
- [ ] A surface change is additive, or a rename with a deprecation window and a
      `list_changed` notification.
- [ ] An agent-loop evaluation exists, including one negative case, and its transcripts
      have been read.

---

## Project delta

The consuming repository must supply:

1. **The server's identity** — its name, the tool-name prefix, and the canonical URI it is
   addressed by (HTTP) or the launch command (stdio).
2. **The protocol revision implemented**, which older revisions are supported, the SDK and
   language, and where tool definitions live in the tree.
3. **The capability inventory** — which tools, resources and prompts exist, and the
   one-sentence selection rule for any pair that could be confused.
4. **The transport(s) shipped**, and for HTTP: the endpoint path, the allowed `Origin`
   values, and the TLS termination point.
5. **The authorization model** — authorization server, scope vocabulary, the claim used as
   the subject, and where downstream credentials are held.
6. **The state store** for handles and idempotency keys, and their TTLs.
7. **Response-size budgets** — default page size, the concise field set per tool, and the
   truncation marker's wording.
8. **The error vocabulary** — stable codes or phrasings, and the recovery action each one
   names — plus the deprecation window for a retired tool or argument.
9. **Where the agent-loop evaluation lives**, how it is run, and its current pass rate.
