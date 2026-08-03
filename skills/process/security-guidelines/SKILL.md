---
name: security-guidelines
description: The application-security rules to follow while writing code — authorisation enforced at the data access layer with the subject taken from the verified credential, allowlist validation at the boundary, output encoding at every interpreter crossing, TLS with certificate verification, deny-by-default and fail-closed behaviour, rate limits and resource bounds, dependency scanning, and the personal-data denylist for logs, errors, analytics and third parties. Use when adding an endpoint, handler, query, job or webhook that touches user-owned data, handling uploads or external input, shelling out, building a query, deciding what to log, adding a dependency, or acting on a security finding. Triggers on "is this secure", "can another user read this", "IDOR", "SQL injection", "sanitise this input", "what am I allowed to log", "PII in logs", "rate limit this endpoint", "certificate verification fails", "we leaked a token".
license: Apache-2.0
metadata:
  source: glotyuids/engineering-skills
  version: 0.1.0
---

# Security guidelines

**This skill is what you follow while writing the code, not what you check afterwards.** It is
prescriptive: each rule names the shape to write, so the defect never exists. A review checklist
is the mirror image — it names the shape to look for once the defect is already in the diff. If
the `core` pack's `security-reviewer` agent is installed, it audits against these same rules; a
clean review is not a substitute for building it right, because a reviewer only sees what the
diff shows.

This skill defines only **application-level** security: authorisation, input handling, output
encoding, transport, safe defaults, resource bounds, dependency hygiene and personal-data
handling. It does not define:

- **Where secret values live**, how they sync or rotate — if the `secrets-management` skill is
  installed, follow it; otherwise follow the project's own convention. This skill only says a
  secret must never be hardcoded, logged or returned.
- **The API edge contract** — path spaces, the internal service-to-service header and its
  mandatory strip at the edge. If the `api-and-events` skill is installed, those rules are
  binding and are not repeated here.
- **What happens after an exploit** — if the `incident-response` skill is installed, §9 hands
  off to it.
- Cryptographic protocol design, infrastructure hardening, network policy.

It assumes no language, no framework and no cloud provider.

## 1. Authorisation is enforced at the data access layer

Authentication answers *who is calling*. Authorisation answers *may this caller touch this
row*. They are separate, and a valid token is not permission.

### 1.1 The subject identifier comes from the verified credential

`[!]` **Never take the subject identifier from the request body, the query string, a path
segment or a client-set header.** It comes from the verified credential — the session, the
validated token claim, the authenticated connection identity — resolved once by the
authentication layer and passed explicitly down the call stack.

A subject identifier read from request-supplied data is the classic broken-object-level
authorisation defect (IDOR): any authenticated caller reads, edits or deletes everyone else's
data by changing one number, and the code looks correct in review because the parameter is
named exactly like the real thing. It survives every test the author writes, because the author
only ever sends their own identifier.

The same rule covers every claim the caller would like to control: role, tenant, plan, quota,
`is_admin`, "verified" flags. If it decides access, it comes from the server side.

### 1.2 Every user-owned query is subject-scoped

Put the scope in the query signature, not in a handler check:

```text
BAD   GetOrder(ctx, orderID)                       -- authorisation is somewhere else, or nowhere
GOOD  GetOrder(ctx, subjectID, orderID)            -- WHERE id = $1 AND owner_id = $2
```

- A repository/query function that touches user-owned data takes the subject as a **required**
  parameter and puts it in the `WHERE` clause. Then forgetting it is a signature error, not a
  silent hole.
- A handler-level `if` is the wrong place: the next handler, the next background job, the next
  export script and the next admin tool each have to remember it independently. One of them
  will not.
- This applies to **every** verb — read, list, update, patch, delete, export, count — and to
  bulk operations, which are the ones most often written without the scope.
- Nested resources are reached only through a parent the subject owns. Do not look a child up
  by its own id and then trust the parent pointer inside it.
- An identifier in a URL is an **address, not a permission**. Unguessable identifiers (UUIDs,
  random tokens) are not authorisation either; they only make enumeration slower.

### 1.3 Not yours and not there look identical

A row the caller does not own must be **indistinguishable from a row that does not exist**:
same status code, same body, same timing. Returning `403` for someone else's record and `404`
for a missing one turns the endpoint into an existence oracle — an attacker enumerates which
identifiers, accounts, e-mail addresses or documents exist without ever reading one.

Deliberate exceptions exist (a shared workspace where "you need access to this document" is the
product), and they are exactly that: deliberate, written down, and applied to a resource class
whose existence is not itself sensitive.

### 1.4 Positive checks, every request

| Situation | Required shape |
|---|---|
| Elevated capability (admin, support, internal tooling) | a **positive** check for a server-side role/scope claim — never the absence of a user check |
| Multi-tenant data | tenant scope in the query, from the credential, on every statement |
| State-changing request | re-authorise on the request that changes state, not only on the one that rendered the form |
| Long-running job acting for a user | carries the subject explicitly; a job is not exempt from scoping |
| Cached authorisation decision | keyed by subject **and** resource, with a short TTL; never cached client-side as authority |

## 2. Input validation at the boundary, with an allowlist

Validate where untrusted data enters the process — HTTP request body and parameters, message
payload, webhook, uploaded file, CLI argument, environment value, third-party API response.
Convert to internal types **once**, at that boundary; everything inside the boundary is entitled
to assume the type it received is valid.

- **Allowlist, never denylist.** Enumerate what is permitted: a closed set of enum values, an
  anchored pattern, a length range, a numeric range, a known content type, a known field set.
  Denylists — stripping known-bad characters, blocking `../`, filtering keywords — fail on the
  first input nobody thought of, and every one of them has been bypassed in public.
- **Reject, do not repair.** A structurally invalid request gets a clear failure naming the
  field. Silently trimming, coercing or "sanitising" a bad value produces a value nobody
  designed and hides the attack.
- **Bound everything a caller controls**: request body size, string length, array/collection
  length, object nesting depth, page size, file size, decompressed size, number of files,
  regex input length. An unbounded field is a memory-exhaustion primitive.
- **Canonicalise before checking, use the canonical form afterwards.** Resolve a file path,
  *then* prefix-check it against the allowed root, and open the resolved path. Parse a URL,
  *then* check its host against an allowlist, and request the parsed URL. Checking one form and
  using another is how path traversal and server-side request forgery both work.
- **Client identifiers are opaque.** Never derive a filesystem path, table or column name, cache
  key, redirect target, template name or command argument from client input except through a
  fixed allowlist map.
- **Deserialisation is code execution** in many stacks. Deserialise into a fixed, known type
  with known fields; never let the payload choose the type; reject unknown fields where the
  format allows it.
- **Uploads**: decide the type from content inspection, not the supplied filename or content
  type; generate the stored name yourself; store outside any directory that is served or
  executed.

If the `integration-testing` skill is installed, boundary validation is exactly the layer worth
a real test with a hostile payload rather than a mock.

## 3. Output encoding at every interpreter crossing

Data is dangerous when it crosses into another interpreter. Encode **at the crossing point**,
for **that destination**, not earlier and not "once, on input" — the same value is safe in one
destination and an injection in the next.

`[!]` **Never build a query or a shell command by string concatenation or interpolation.** Not
for the `WHERE` clause, not "just for the sort column", not for a value that came from the
database, not for internal traffic, not temporarily while debugging. This is the single most
exploited defect class in the industry, it is trivially avoidable, and the concatenated version
usually works in testing — which is why it ships.

| Destination | Safe construction | Never |
|---|---|---|
| SQL / any query language | driver-bound parameter placeholders; identifiers (table, column, sort key, direction) resolved through a fixed allowlist map | any concatenation or interpolation of a value into the statement |
| Shell / subprocess | execute a fixed binary with an argument vector, no shell interpreter | handing a built string to a shell; passing input as flags |
| HTML / DOM | a context-aware template engine with auto-escaping on; text nodes and attribute APIs | raw-HTML insertion, `innerHTML`-style sinks, disabling auto-escaping |
| URL | proper percent-encoding of each component; host allowlist for outbound | building URLs by concatenation; putting data in a path by hand |
| Log line | structured key/value fields | interpolating raw input into the message (see also §7) |
| JSON / CSV / YAML / XML | a serialiser for the format | hand-built strings; a CSV cell starting with a formula character, unprefixed |
| File path | join, canonicalise, then prefix-check | concatenating a client-supplied name |
| Template / expression evaluator | templates from a fixed set; data passed as arguments | compiling a template whose source contains input |
| Header / e-mail field | an API that rejects control characters | writing raw input into a header value |

**"Trusted" is a claim about provenance, and it needs an owner.** A value from the database, from
another internal service, from a message queue or from a model response is input too: it is
trusted only if you can name who validated it and when. Encoding is chosen by the destination,
never by how trustworthy the source feels. If the `llm-pipeline-rules` skill is installed, its
treatment of model output as untrusted input applies here unchanged.

## 4. Transport

- All traffic that leaves the process runs over TLS, with **certificate and hostname
  verification on**.
- **Never disable certificate verification to make something work.** Every ecosystem has the
  flag — skip-verify, `verify=False`, `rejectUnauthorized: false`, `-k`, "trust all
  certificates" — and every one of them turns an encrypted channel into an unauthenticated one
  that any network position can read and rewrite. A verification failure is a real signal: fix
  the trust store, the certificate chain, the hostname/SAN mismatch, or the machine clock. In
  local development, install a development CA instead. If a bypass switch must exist at all, it
  is config-gated, defaults to off, is impossible to enable in a production environment, and
  logs loudly when active.
- **No sensitive data in a URL** — not tokens, not identifiers of other people, not personal
  data. Query strings survive in access logs, proxies, referrer headers, browser history and
  error trackers. Sensitive values travel in the body or an appropriate header.
- **Cookies**: `Secure`, `HttpOnly`, an explicit `SameSite`, narrow path/domain, and a short
  lifetime for anything that authenticates.
- **Redirects**: a redirect target derived from input is allowlisted, or the feature does not
  ship. Open redirects are the standard phishing accelerator.
- **CORS**: enumerate allowed origins explicitly. Never reflect the request's origin, never
  combine a wildcard with credentials.
- **Network position is not authorisation.** An endpoint reachable only "from inside" still
  authenticates its caller. If the `api-and-events` skill is installed, its internal-header
  rules — including the mandatory strip at the edge — govern how that is done; this skill does
  not restate them.

## 5. Safe defaults

- **Deny by default.** A newly added route, topic, job or RPC is authenticated and authorised
  unless it is explicitly listed as public, and that public list lives in one reviewable place.
  If the framework mounts routes as public unless annotated, invert it with a catch-all
  middleware — otherwise the one route someone forgot to annotate is the breach.
- **Fail closed.** When token verification, the authorisation lookup, the policy store, the
  rate limiter or the feature flag service errors or times out, **deny**. A `catch` that returns
  "allowed" on error converts any dependency outage into a total authorisation bypass, and it is
  usually written as a resilience improvement.
- **No debug surface in production**: profiling and heap endpoints, admin consoles, schema
  introspection where it is not a product feature, verbose stack traces returned to clients,
  seeded or default accounts, impersonation tooling, request/response echo endpoints. Gate each
  on configuration that is off by default, and make production refuse to start with it on.
- **Error responses carry a stable code and a correlation id; details go to the log.** Never
  return SQL text, stack traces, driver messages, internal hostnames, file paths or dependency
  versions to a caller. If the `observability-and-quality` skill is installed, use its
  correlation-id conventions.
- **Least privilege for the service's own identity**: narrow IAM scopes, a database role without
  rights it never uses, per-service credentials rather than one shared credential, read-only
  where reads are all that happen.
- **Secure by construction beats configuration**: prefer the helper that cannot be called
  unsafely over the convention that it must be called correctly. When you find yourself writing
  a comment that says "remember to pass the subject here", write a type or a signature that
  makes forgetting impossible.

## 6. Rate limits and resource bounds

Anything a stranger can reach needs a limit; anything expensive needs one even behind
authentication.

| Surface | Bound to apply |
|---|---|
| Authentication, password reset, MFA, signup, invite acceptance | strict per-credential **and** per-source limits, plus progressive backoff or lockout |
| Any public read/write endpoint | per-credential and per-source limits — credentials are free to create, so per-credential alone is not a limit |
| Search, export, report, aggregation | limits plus a hard result cap and a query timeout |
| Uploads and anything that decompresses | size cap before reading, decompressed-size cap while reading, count cap |
| Outbound work triggered by a caller (mail, webhook, model call, third-party API) | per-caller quota and a global circuit breaker — this is where a cheap request becomes an expensive bill |
| Every outbound call, without exception | an explicit timeout; unbounded waits exhaust the pool and take the service down |

Also:

- Cap concurrency and queue depth; shed load rather than accumulating it.
- Compare secrets (tokens, signatures, reset codes) with a **constant-time** comparison.
- Authentication failures return one generic message. Do not reveal whether the account exists —
  in the message, in the status code, or in the response time. The same applies to signup and
  password reset ("if that address is registered, we have sent a link").
- Verify webhook signatures over the **raw** body before parsing it, with a timestamp window and
  replay protection.

## 7. Personal data: the denylist

Classify a field when you add it, not when someone logs it. The rule is one sentence: **listed
data never reaches a log, an error message, an analytics or telemetry event, a crash report, a
URL, a cache key, a filename, or any third party.**

### 7.1 Never in clear, in any of those sinks

| Class | Examples |
|---|---|
| Credentials and tokens | passwords and their hashes, session and API tokens, refresh tokens, signing keys, MFA and recovery codes, connection strings with a password |
| Government and financial identifiers | national ID numbers, passport numbers, card numbers, bank accounts |
| Precise location | exact coordinates, addresses, per-request location traces |
| Contact details | e-mail address, phone number, postal address, and any handle that resolves to a person |
| User-authored free text | message bodies, notes, uploaded documents, prompts, support-ticket contents |
| Special categories | health, biometric, sexual orientation, religion, political or trade-union affiliation, precise age of a minor |
| Whole payloads | full request/response bodies of any endpoint carrying the above — "log the payload for debugging" is how all of this leaks at once |

**Safe to log instead**: the subject's internal opaque id, resource ids, counts, sizes,
durations, outcome and error codes, coarse categories, boolean shapes ("document had 3
sections"). The test: enough to reconstruct what happened, not enough to identify anyone or to
reconstruct what they wrote.

### 7.2 Make redaction a property of the type

Redaction that depends on every call site remembering will fail at the one call site that
forgets. Give sensitive values a type whose string representation prints a placeholder, so an
accidental interpolation is harmless; keep the raw value reachable only through an explicitly
named accessor. Apply the same to structures that carry personal data.

- **Wrap errors from lower layers before they are logged or returned.** Driver, HTTP and parser
  errors routinely embed the input that failed — a connection string, a token in a URL, a row's
  contents. Log the message *you* wrote, with fields you chose.
- **Third-party egress is a decision, not a detail.** Sending personal data to a new monitoring
  tool, analytics platform, support system or model provider is a change that gets stated out
  loud. Send the minimum field set; never send a whole object because it was convenient to pass.
- **Copying personal data into a new store creates a new deletion obligation** — a search index,
  a cache, an export bucket, a data warehouse, a third party. Note it in the same change, and
  make the delete path reach it. If the `documentation-standards` skill is installed, that note
  belongs where it says data flows are documented.
- Retention: give personal data an expiry when you create the table, not later.

## 8. Dependency hygiene

- Adding a dependency is a decision: what it costs in maintenance, transitive footprint, release
  activity and licence, and whether the standard library already does it. An unmaintained
  package is a finding even with no known vulnerability.
- **Pin.** Lockfiles are committed; container base images and build tools are pinned by version
  or digest, never a floating `latest`.
- **Scanning runs in the pipeline, not on someone's laptop**: a dependency vulnerability scan, a
  static analysis pass, and a secret scan on every push and every pull request. The job **fails**
  the build; a warning nobody must act on will not be acted on.
- A suppression is temporary by construction: it names the finding, the reason, and an expiry
  date. A permanent blanket ignore is how a scanner becomes decoration.
- Never fetch-and-execute from an unpinned source during build or run (piping a downloaded
  script into a shell, installing from a mutable tag). Verify checksums where the ecosystem
  offers them.
- Rebuild and redeploy for patched base images on a schedule, not only when a feature ships.
- `Verify:` if the project has no scanner wired at all, adding one is part of the first change
  that touches security-sensitive code — do not assume a pipeline is already checking.

## 9. Critical-finding protocol

A **critical** finding is one where an unauthenticated or wrong-subject caller can reach data or
capability that is not theirs, a secret is exposed, or remote code execution is plausible. When
you find one — in your own diff, in existing code, or while doing something unrelated:

1. **Stop.** Do not keep building the feature on top of it, and do not fold the fix quietly into
   an unrelated branch.
2. **Report before fixing.** State the location (`file:line`), the vulnerability class, a
   concrete exploit path in one or two sentences, whether it is reachable in production right
   now, and what data or capability it exposes. The report comes first because a human, not the
   agent, decides about rotation, disclosure and whether this is an incident.
3. **Fix minimally.** The smallest change that closes the hole, in its own commit, with no
   refactor riding along — this commit needs to be reviewable and revertable on its own.
4. **Rotate anything exposed.** A secret that reached a log, a repository, a ticket, a browser,
   a screenshot or a third party is burned. Rotate the value first; deleting the log line or
   rewriting history is cleanup, never the remediation.
5. **Sweep for the pattern, do not fix only the instance.** The one you found is a sample. Search
   for every sibling: every other query missing the subject scope, every other caller of the
   unsafe helper, every other handler reading an identifier from the body, every other place the
   same value is logged. Fix them, or list the ones you cannot fix and say so explicitly.
6. **Add the regression test** that fails without the fix — one subject requesting another
   subject's resource and expecting the not-found response; the injection payload that used to
   work.
7. **If it was exploited, or data was exposed, this is an incident, not a bugfix.** If the
   `incident-response` skill is installed, hand off to it at this point.

Never verify an exploit against production, against real user data, or against a third party's
system. Reproduce it locally or in a test environment.

## 10. Definition of done

- [ ] Every subject identifier used for access decisions comes from the verified credential;
      none is read from the body, query, path or a client-set header.
- [ ] Every query touching user-owned data takes the subject as a required parameter and scopes
      the statement by it — reads, lists, writes, deletes and bulk operations alike.
- [ ] Another subject's resource is indistinguishable from a missing one.
- [ ] Every new route/consumer is authenticated and authorised by default; any public exception
      is in the single reviewable list.
- [ ] All external input is validated at the boundary against an allowlist, with explicit size,
      length, depth and count bounds.
- [ ] No query, command, path, URL or markup is built by concatenation; every crossing into
      another interpreter uses that interpreter's safe construction.
- [ ] TLS with verification on everywhere; no skip-verify flag in any code path that production
      can reach; no sensitive data in URLs.
- [ ] Authorisation, token and policy failures deny rather than allow.
- [ ] Rate limits and timeouts exist on everything a stranger can call and everything expensive.
- [ ] No debug, profiling or introspection surface is enabled in production.
- [ ] Nothing on the §7 denylist appears in logs, error messages, analytics, URLs or third-party
      payloads; sensitive types redact themselves.
- [ ] Error responses carry a code and a correlation id, never internals.
- [ ] New dependencies are pinned and justified; the pipeline's vulnerability, static-analysis
      and secret scans pass and are build-failing.
- [ ] A test covers the authorisation boundary for the new code, not just the happy path.
- [ ] Any critical finding followed §9 in order — reported, fixed, rotated, swept, regression-tested.

## Project delta

The consuming repo supplies:

- **The credential claim that carries the subject identifier**, the middleware or helper that
  resolves it, and the type used to pass it down the stack.
- **The data classification** — the concrete field-level denylist for this product, plus the
  redacting types and the log fields that are considered safe.
- **The rate-limit tiers** and where they are enforced (edge, gateway, service), plus the
  standard timeout values.
- **Which environments count as production** for the fail-closed, debug-surface and
  certificate-verification gates.
- **The error-response shape** and the correlation-id field name.
- **The scanners wired into the pipeline**, the command that runs them locally, and where
  suppressions and their expiry dates are recorded.
- **Where a security finding is reported and who decides** on rotation, disclosure and incident
  status.
