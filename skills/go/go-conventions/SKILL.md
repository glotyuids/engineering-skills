---
name: go-conventions
description: Service-internal layout, the clean-architecture dependency rule, default library set, go.mod/monorepo mechanics, per-subject data ownership, configuration versus authority-bearing policy, error handling and the verification gate for Go services. Use when writing or reviewing Go code, adding a package or an adapter, choosing a Go library, wiring dependencies in the composition root, writing a repository or a sentinel error, setting up go.mod and replace directives in a monorepo, or when asked "where does this file go", "what is our Go layout", "which router/logger/Postgres driver do we use", "how do we scope queries per user", "can I add this dependency", "is this backend work done", "where does the rules engine go", "is this config or policy", "can domain import the generated types", or "how does the daemon get its secret".
license: Apache-2.0
metadata:
  source: glotyuids/engineering-skills
  version: 0.1.2
---

# Go conventions

Clean-architecture conventions for a Go service, merged from several independently
hardened service codebases.

**This skill defines only the service-internal layout and code conventions**: the
dependency rule, directory tree, module mechanics, default libraries, code style, data
ownership, error handling, and the local verification gate. It does **not** define
containers, CI pipelines, Helm charts, Terraform, deployment or secret storage — those
belong to the infrastructure pack. It does not define migration authoring or SQL schema
patterns — those belong to the database pack. Where a project's own conventions already
exist and differ, the project wins; adapt names to an existing repo rather than renaming
it, unless the user explicitly decides otherwise.

---

## 1. The dependency rule

This is the one non-negotiable. Every other section serves it.

| Layer | May import | Must never import |
|---|---|---|
| `internal/domain` | stdlib, tiny value-type helpers, transport-free generated contract types (see below) | transport, database drivers, external SDKs, any adapter |
| `internal/<engine>` (optional, see below) | stdlib, its own generated types, pure libraries | `domain`, `app`, adapters, drivers — it is a leaf |
| `internal/app` | `domain` (its entities **and its interfaces**), an engine's public API | concrete adapters, drivers, HTTP types |
| `internal/adapters/*` | `domain`, `app` interfaces, an engine's public API, drivers/SDKs | other adapters (go through `app`) |
| composition root (`cmd/<service>`, or `internal/compose`) | everything | — |

- `domain` holds entities, value objects, repository/gateway **interfaces**, and sentinel
  errors. It imports nothing outward.
- `app` holds use cases and orchestration. It depends on domain interfaces only, and is
  where input validation and sanitization live.
- `adapters` implement those interfaces: HTTP handlers and routers, database
  repositories, object storage, message/queue clients, external service clients.
- **Wiring happens in exactly one composition root per binary.** Once a binary exists,
  that is `cmd/<service>/main.go`. Before one exists, or when tests need a fully wired
  service, it is a `New(deps)`-style constructor in a dedicated package
  (`internal/compose/`) that `main` and the tests both call. The root may import
  everything; `internal/app` never composes adapters. "One place", not "that file", is
  the rule. If any other package reaches for a concrete implementation instead of taking
  an interface in its constructor, the rule is broken.

A new service may legitimately start with only `cmd/` and `internal/config/`. Add the
other layers as the service acquires real behaviour — do not scaffold empty packages to
look complete.

### Engine packages

A self-contained engine — an interpreter, a compiler, a rules or workflow evaluator — is
neither domain, app nor adapter. Treat it as a **leaf library**, the way stdlib is:

- It lives in `internal/<engine>/` (or `pkg/<engine>/` once a second consumer exists) and
  imports only stdlib, its own generated types and pure libraries. No drivers, no
  transport, no `domain`, no `app`.
- It does no I/O of its own. Where it must read or write, it declares its own small
  interfaces and the composition root supplies the implementations.
- **Its diagnostics are its contract.** It defines its own error types and never imports
  `internal/domain/errors.go`. The `app` code or adapter that calls it translates those
  errors into domain sentinels at the point where the result crosses into a use case —
  exactly as a driver error is translated (§7).
- `app` and adapters call it directly, the way they call stdlib. Hiding a pure engine
  behind a domain interface is abstraction for its own sake; wrap it only when a second
  implementation genuinely exists.

### Generated contract types in `domain`

`domain` may import a generated contract package (protobuf, JSON Schema) only when **both**
hold:

1. the generated package depends on nothing but its runtime (`google.golang.org/protobuf`
   and the like) — never on a gRPC, HTTP or broker package; and
2. the contract *is* the domain record — the same type is what the service stores and what
   it publishes (`api/contracts/`, §2), so a hand-written mirror would be a second source
   of truth that drifts.

Where the generated type is only a transport DTO, it stays in the adapter and the handler
maps it (§8). Record the choice in the project delta.

## 2. Directory layout

The root may be the repository root (standalone service) or a subdirectory in a monorepo.
The inner structure is identical either way.

```
<service-root>/
├── cmd/<service-name>/main.go     # entry point, DI, wiring, lifecycle
├── internal/
│   ├── config/                    # env-tagged config structs + Load() — deployment wiring only (§9)
│   ├── domain/                    # entities, value objects, interfaces, errors.go
│   ├── app/                       # use cases, orchestration, validation, sanitization
│   ├── <engine>/                  # optional: a self-contained interpreter or compiler (§1)
│   ├── compose/                   # optional: composition root shared by main and tests (§1)
│   └── adapters/
│       ├── http/                  # handlers, routers, HTTP DTOs
│       ├── db/                    # repository implementations
│       └── ...                    # further adapters as needed
├── api/
│   ├── openapi/                   # OpenAPI schemas — the public contract
│   ├── contracts/                 # domain contracts (protobuf / JSON Schema) that are both stored records and event payloads
│   └── events/                    # async message contracts, if the service publishes any
├── migrations/                    # SQL migrations
├── scripts/                       # operational scripts (seed, backfill, …)
├── pkg/                           # only truly generic, reusable utilities
├── docs/                          # ADRs, architecture notes, runbooks, post-mortems
├── Dockerfile
├── Makefile
├── .golangci.yml
└── go.mod
```

A project may add outer structure around this — a `services/<name>/` monorepo wrapper, an
`infra/` tree holding the chart and deployment assets. That outer shape is a project
decision and belongs to the infrastructure pack; it never changes the inner tree.

### Adapter subdirectories

Create a subdirectory only for a transport the service actually uses. An unused adapter
package is a lie about the architecture.

| Adapter | Package |
|---|---|
| HTTP handlers | `internal/adapters/http/` |
| Relational repositories | `internal/adapters/db/` |
| Object storage | `internal/adapters/storage/` |
| Message broker publish/subscribe | `internal/adapters/<broker>/` |
| Internal service client | `internal/adapters/<serviceclient>/` (wraps the shared typed client) |

A service whose asynchronous work runs on a task queue plus an in-process DAG runner has
**no broker adapter at all**. Do not add one on the assumption that every service uses a
message broker.

### `pkg/`

`pkg/` is for code that is genuinely cross-service. Add to it only when a second consumer
actually exists; a single-consumer package belongs in that service's `internal/`.

Recurring shared packages across these codebases:

| Package | Use |
|---|---|
| `pkg/cors` | CORS middleware |
| `pkg/metrics` | Prometheus HTTP metric helpers |
| `pkg/internalauth` | service-to-service API-key middleware |
| `pkg/jwtauth` | token verification — OIDC RS256 via JWKS, plus an anonymous HMAC mode where the product has guest sessions |
| `pkg/authz` | the authenticated subject type, ownership checks, and the SQL owner predicate |
| `pkg/sanitize` | input sanitization |
| shared value types | only where two or more services must agree on a cross-cutting domain concept and its derivation must be deterministic |
| internal gateway client | a typed client to an internal gateway service, where the project mandates that all calls of some kind go through one |

## 3. go.mod and monorepo mechanics

- **Standalone service**: one module at the repo root.
- **Monorepo**: each service under `services/<name>/` is its own module, and each shared
  library under `pkg/<x>/` is its own independent module.
- Module path: `github.com/<org>/<service-name>` for services,
  `github.com/<org>/pkg/<x>` for shared libraries. Keep the org segment identical across
  every module in the repo.
- Go version: match the other modules in the repo. Do not bump one service's `go`
  directive in isolation.
- One `replace` directive per shared module consumed, pointing at the relative path:

```go
replace (
    github.com/<org>/pkg/internalauth => ../../pkg/internalauth
    github.com/<org>/pkg/metrics      => ../../pkg/metrics
)
```

Every shared module a service imports needs both a `require` and a `replace`. A missing
`replace` fails only at build time in the module that consumes it, so build **all**
modules after touching any shared package.

## 4. Library defaults

Use the standard library whenever reasonable. Below is a **known-good default set**, not
law — a project may override any row, and an existing repo's established choice always
wins over this table.

| Purpose | Library |
|---|---|
| HTTP routing | `github.com/go-chi/chi/v5` |
| Structured logging | `go.uber.org/zap` |
| Config from environment | `github.com/caarlos0/env` |
| PostgreSQL | `github.com/jackc/pgx/v5` (with `pgxpool`) |
| Columnar analytics store | `github.com/ClickHouse/clickhouse-go/v2` |
| SQL migrations | `github.com/golang-migrate/migrate/v4` |
| AMQP message broker | `github.com/rabbitmq/amqp091-go` |
| S3-compatible object storage | `github.com/minio/minio-go/v7` |
| Assertions in tests | `github.com/stretchr/testify` |
| YAML | `github.com/goccy/go-yaml` |
| Expressions (rules, policies, filters) | `cel.dev/cel-go` |
| Protobuf validation | `buf.build/go/protovalidate` |
| Protobuf toolchain | `buf` + `protoc-gen-go`, pinned with the `go.mod` `tool` directive |

Dependency policy:

- Prefer mainstream, well-maintained packages. Avoid exotic or unmaintained ones.
- **Do not introduce a new dependency without stating why it is needed** and what stdlib
  or existing-dependency alternative was rejected.
- Every dependency's licence must be compatible with commercial use.
- Reach for an assertion library only where it earns its place; table-driven tests with
  plain comparisons are the default in some of these repos.
- Two rows above changed module path: `cel.dev/cel-go` was `github.com/google/cel-go`, and
  `buf.build/go/protovalidate` was `github.com/bufbuild/protovalidate-go` (the repository
  keeps the old name). Import the current path only — a module that carries both compiles
  two copies of the library and type-mismatches between them.
- Pin code generators with the `tool` directive (Go 1.24+) and run them as `go tool buf …`,
  so every author and CI generate with one version and `go mod tidy` tracks it. Commit the
  generated code or produce it in the build — one choice per repo.

### Datastores and runtime assumptions

These services target `MANAGED_PG`, an optional columnar analytics store, an
`OBJECT_STORAGE` bucket reached over the S3-compatible protocol, and a broker or task
queue; they run on `MANAGED_K8S` with Helm-packaged manifests. `prod` always exists,
`dev`/`staging` are optional; local development uses a local Kubernetes cluster and/or a
compose file for dependencies. Which concrete service backs each capability is the
infrastructure pack's business, resolved by the `skills/cloud/<vendor>/` layer — the
capabilities are listed here only so that code written under this skill does not assume
something incompatible (for example, do not assume a writable local filesystem that
survives a restart).

## 5. Code style

- Assume `gofmt` and `goimports` formatting always.
- Small, focused packages.
- Package names: short, all lowercase, no underscores, no gratuitous plurals.
- No `util`, `common`, `helpers`, `base`. Name packages after what they do in the domain.
- Generics only where they clearly remove duplication and increase clarity. No
  abstraction layer that exists "for future flexibility".
- Constructors take interfaces and return concrete types; the caller decides what to
  narrow.
- `context.Context` is the first parameter of anything that does I/O, and it is
  propagated, never replaced with `context.Background()` mid-call-chain.
- If the project's linter config (`.golangci.yml`) disagrees with anything here, the
  linter wins — fix the code, do not edit the config to pass.

## 6. Data ownership and per-subject scoping

Mandatory for any service holding data that belongs to a subject — a user, a tenant, an
organisation. The **owner column** is whichever of those the project scopes by
(`user_id`, `tenant_id`, `org_id`); its name is a project delta, the rules below are not.

1. **Every owned table carries the owner column.** No exceptions, including join tables and
   append-only logs.
2. **Repositories take the authenticated subject as an explicit parameter** and scope
   every read *and* every write by it. A repository method that can be called without a
   subject is a data-leak waiting to happen.
3. **Scope twice, independently**: an application-level predicate injected into the SQL,
   and a database-level guard (row-level security keyed off a per-transaction session
   variable set from the subject). Two independent layers mean a bug in one is not a
   breach.
4. **Missing rows and not-owned rows both map to not-found.** Returning "forbidden" for a
   row that exists but belongs to someone else leaks its existence.

Shape of a scoped repository read (`ownerColumn` is the project's column name):

```go
func (r *Repo) Get(ctx context.Context, subject authz.Subject, id uuid.UUID) (T, error) {
    pred, arg := subject.OwnerPredicate(ownerColumn, 2)        // app-level guard, $2
    return r.withOwnerTx(ctx, subject, func(tx pgx.Tx) error { // sets the session variable
        q := fmt.Sprintf(`SELECT ... WHERE id = $1 AND %s`, pred)
        return tx.QueryRow(ctx, q, id, arg).Scan( /* … */ )
    })
}
```

Keep one canonical `withOwnerTx` per service and reuse it; do not hand-roll the
transaction-plus-session-variable dance per repository.

**Verify:** the database-level half only exists once the migration that enables row-level
security and defines the policy has shipped. If it has not, the application-level
predicate is the *only* guard — say so explicitly rather than claiming defence in depth
you do not have. If the `postgres-patterns` or `database-migrations` skills are installed,
follow them for the policy and migration mechanics; otherwise follow the project's own.

## 7. Error handling

- Wrap with `%w` when adding context; never with `%v`, which severs `errors.Is`/`As`.
- **Sentinel errors live in `internal/domain/errors.go`.** Adapters and app code return
  domain sentinels; they do not invent per-package parallel error vocabularies.
- Translate driver-specific errors into domain sentinels **at the adapter boundary**
  (`pgx.ErrNoRows` → `domain.ErrNotFound`), so `app` never imports a driver package.
- Map domain errors to HTTP status codes in exactly one place at the transport boundary
  (a single `writeDomainError`-style helper), not per handler.
- `Get`-by-id returns `ErrNotFound` for **both** a missing row and a row owned by someone
  else — do not leak ownership.
- Never swallow an error. If it is genuinely ignorable, say why in a comment on the same
  line.
- **Never log PII.** No document or CV text, message bodies, email addresses, names, or
  anything a user wrote about themselves. Log identifiers and counts, not content.

## 8. API surface

Brief, so that code written under this skill lands in the right place:

- External routes: `/api/<domain>/v1/...`
- Internal (service-to-service) routes: `/api/<domain>/internal/...`, gated by the
  internal API-key middleware (`X-Internal-API-Key`).
- The public contract lives in `api/openapi/` and is updated in the same change as the
  handler. Asynchronous message contracts live in `api/events/`. A domain contract that is
  both a stored record and an event payload (protobuf or JSON Schema) lives in
  `api/contracts/`, generated into `internal/gen/` or the project's equivalent — see the
  generated-types rule in §1.
- Handlers translate DTOs to and from domain types and do nothing else — no business
  rules, no SQL, no direct external calls.

For contract versioning, event schema evolution and consumer compatibility, see the
`api-and-events` skill in this pack.

## 9. Configuration

Two kinds of value reach a process, and they are handled differently.

**Deployment wiring** — addresses and DSNs, ports, pool sizes, timeouts, log level, feature
toggles, the name of the environment:

- Comes from the environment, parsed into env-tagged structs in `internal/config/` with a
  single `Load()` returning a validated struct.
- `Load()` fails fast and loudly on a missing required value; no silent zero-value
  fallbacks for anything that matters.
- No secret is ever a default value in code, and no secret is logged, including at debug
  level. If the `secrets-management` skill is installed, follow it for how secrets reach
  the process; otherwise follow the project's own conventions.
- **Where the process manager cannot hand over a secret safely** — a launchd plist, for
  example, can only carry literal environment values — indirect through the environment
  rather than around it: a `<NAME>_FILE` variable naming an owner-only file (mode `0600`)
  that `Load()` reads, refusing a file readable by group or world, and accepting `<NAME>`
  or `<NAME>_FILE` but never both; or a password-free DSN through peer or socket
  authentication or the driver's password file. An init system's credentials directory
  (systemd's, for example) is the same pattern with the file supplied by the init system.

**Authority-bearing policy** — spend caps and budgets, grants and allowlists, release pins,
trust roots, anything whose change lets someone spend money, widen access or run a
different artefact:

- Is **not** configuration. It is data with provenance: a versioned, signed or explicitly
  accepted record that the process loads and verifies, and whose identity (version,
  digest, who accepted it) it logs at startup and on every reload.
- Never a bare environment variable or chart value. Anyone with deploy or `exec` rights
  can set those silently, which turns a policy into a suggestion.
- Its absence is a startup failure, like missing wiring. A policy that silently defaults
  to "unlimited" or "allow" is the worst of both kinds.

The test: if changing a value could spend money, widen access or ship a different
artefact, it is policy. If it only changes *where* or *how loudly* the same behaviour
runs, it is wiring.

## 10. Verification gate

Do not claim backend work is complete until all of these are green, locally, on the
change as it stands:

- [ ] `make fmt` — or `gofmt -l .` produces no output
- [ ] `make build` — every module in the repo, not just the one you edited
- [ ] `make vet`
- [ ] `make test` — with `-race`
- [ ] the project linter (`golangci-lint`, per-service `.golangci.yml`) is clean

Running a subset and reporting "done" is the failure mode this gate exists to prevent.
"It compiles" is not the gate; the whole list is. If the Makefile lacks one of these
targets, run the underlying `go` command directly and say which target was missing. If
the `makefile-conventions` skill is installed, follow it when adding the missing target;
otherwise follow the project's own conventions.

### Several authors, one module

When more than one person or agent edits the same module at once:

- `go mod tidy` is run by whoever changes an import, at once, and committed with that
  change. Never revert another author's `require` lines because your tidy did not see
  their code yet — pull first, tidy again.
- **Mid-work, gate your own packages, not the world.** `go build ./...` must still pass
  across the module — a broken build blocks everyone — but run `go vet`, `go test -race`
  and the linter on `./internal/<your-packages>/...` until you integrate. A red test in a
  package someone else is halfway through is their signal, not your gate.
- The **full gate** above runs once, on the integrated change, before anyone claims the
  work is done. If a coordinator integrates, the coordinator runs it.

---

## Project delta

The consuming repository must supply:

1. **Module prefix** — the `github.com/<org>/…` path used by every module in the repo.
2. **Go version** — the `go` directive value shared by all modules.
3. **Repository shape** — standalone service, or monorepo with a `services/<name>/`
   wrapper and shared modules under `pkg/`.
4. **Service names** — which services exist, so `cmd/<service-name>/` and module paths
   are concrete.
5. **Which shared `pkg/` modules exist**, and the `replace` path prefix (`../../pkg/<x>`
   for the standard two-level monorepo).
6. **The owner column** (`user_id`, `tenant_id`, `org_id`), the authenticated-subject type
   and owner-predicate helper the repositories take, and whether the row-level-security
   migration has shipped.
7. **The domain error set** in `internal/domain/errors.go` and the status-code mapping
   used by the transport boundary.
8. **Library overrides** — any row of the default table this project replaces, and why.
9. **Linter configuration** — the `.golangci.yml` in force, and whether it is per-service
   or repo-wide.
10. **Route domain segments** — the `<domain>` values used in `/api/<domain>/v1/…`.
11. **Where authority-bearing policy lives** (§9) — the record or artefact, how it is
    signed or accepted, and how its identity is logged at load.
12. **Whether `domain` imports generated contract types**, and where the generated package
    lives (`internal/gen/` or the project's equivalent).
13. **The engine package**, if one exists, and how its diagnostics map to domain errors.
14. **How secrets reach the process outside a cluster** — `<NAME>_FILE` files, a password
    file, or the init system's credentials — where the `secrets-management` skill does not
    cover the deployment.
