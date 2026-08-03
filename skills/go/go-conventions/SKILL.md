---
name: go-conventions
description: Service-internal layout, the clean-architecture dependency rule, default library set, go.mod/monorepo mechanics, per-subject data ownership, error handling and the verification gate for Go services. Use when writing or reviewing Go code, adding a package or an adapter, choosing a Go library, wiring dependencies in main.go, writing a repository or a sentinel error, setting up go.mod and replace directives in a monorepo, or when asked "where does this file go", "what is our Go layout", "which router/logger/Postgres driver do we use", "how do we scope queries per user", "can I add this dependency", or "is this backend work done".
license: Apache-2.0
metadata:
  source: glotyuids/engineering-skills
  version: 0.1.0
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
| `internal/domain` | stdlib, tiny value-type helpers | transport, database drivers, external SDKs, any adapter |
| `internal/app` | `domain` (its entities **and its interfaces**) | concrete adapters, drivers, HTTP types |
| `internal/adapters/*` | `domain`, `app` interfaces, drivers/SDKs | other adapters (go through `app`) |
| `cmd/<service>` | everything | — |

- `domain` holds entities, value objects, repository/gateway **interfaces**, and sentinel
  errors. It imports nothing outward.
- `app` holds use cases and orchestration. It depends on domain interfaces only, and is
  where input validation and sanitization live.
- `adapters` implement those interfaces: HTTP handlers and routers, database
  repositories, object storage, message/queue clients, external service clients.
- **Wiring happens only in `cmd/<service>/main.go`.** Construction, dependency injection
  and lifecycle belong there and nowhere else. If a package reaches for a concrete
  implementation instead of taking an interface in its constructor, the rule is broken.

A new service may legitimately start with only `cmd/` and `internal/config/`. Add the
other layers as the service acquires real behaviour — do not scaffold empty packages to
look complete.

## 2. Directory layout

The root may be the repository root (standalone service) or a subdirectory in a monorepo.
The inner structure is identical either way.

```
<service-root>/
├── cmd/<service-name>/main.go     # entry point, DI, wiring, lifecycle
├── internal/
│   ├── config/                    # env-tagged config structs + Load()
│   ├── domain/                    # entities, value objects, interfaces, errors.go
│   ├── app/                       # use cases, orchestration, validation, sanitization
│   └── adapters/
│       ├── http/                  # handlers, routers, HTTP DTOs
│       ├── db/                    # repository implementations
│       └── ...                    # further adapters as needed
├── api/
│   ├── openapi/                   # OpenAPI schemas — the public contract
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

Dependency policy:

- Prefer mainstream, well-maintained packages. Avoid exotic or unmaintained ones.
- **Do not introduce a new dependency without stating why it is needed** and what stdlib
  or existing-dependency alternative was rejected.
- Every dependency's licence must be compatible with commercial use.
- Reach for an assertion library only where it earns its place; table-driven tests with
  plain comparisons are the default in some of these repos.

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

Mandatory for any service holding user-owned data.

1. **Every user-owned table carries `user_id`.** No exceptions, including join tables and
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

Shape of a scoped repository read:

```go
func (r *Repo) Get(ctx context.Context, subject authz.Subject, id uuid.UUID) (T, error) {
    pred, arg := subject.OwnerPredicate("user_id", 2)          // app-level guard, $2
    return r.withUserTx(ctx, subject, func(tx pgx.Tx) error {  // sets the session variable
        q := fmt.Sprintf(`SELECT ... WHERE id = $1 AND %s`, pred)
        return tx.QueryRow(ctx, q, id, arg).Scan( /* … */ )
    })
}
```

Keep one canonical `withUserTx` per service and reuse it; do not hand-roll the
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
  handler. Asynchronous message contracts live in `api/events/`.
- Handlers translate DTOs to and from domain types and do nothing else — no business
  rules, no SQL, no direct external calls.

For contract versioning, event schema evolution and consumer compatibility, see the
`api-and-events` skill in this pack.

## 9. Configuration

- All configuration comes from the environment, parsed into env-tagged structs in
  `internal/config/` with a single `Load()` returning a validated struct.
- `Load()` fails fast and loudly on a missing required value; no silent zero-value
  fallbacks for anything that matters.
- No secret is ever a default value in code, and no secret is logged, including at debug
  level. If the `secrets-management` skill is installed, follow it for how secrets reach
  the process; otherwise follow the project's own conventions.

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
6. **The authenticated-subject type and owner-predicate helper** the repositories take,
   and whether the row-level-security migration has shipped.
7. **The domain error set** in `internal/domain/errors.go` and the status-code mapping
   used by the transport boundary.
8. **Library overrides** — any row of the default table this project replaces, and why.
9. **Linter configuration** — the `.golangci.yml` in force, and whether it is per-service
   or repo-wide.
10. **Route domain segments** — the `<domain>` values used in `/api/<domain>/v1/…`.
