---
name: new-microservice
description: End-to-end phased checklist for scaffolding, wiring and shipping a new backend service in a multi-service Go repo — bounded context and planning, storage choice, clean-architecture layout, go.mod replace directives, multi-stage Dockerfile, migration hygiene, chart values, deploy-pipeline registration, secrets, first-deploy failure recovery, verification and documentation. Use when the user says "add a new service", "create a microservice", "scaffold a service", "new backend service", "wire the service up for deploy", "why did my first deploy skip the install", "the migration job left schema_migrations dirty", "the pod crashes with unable to read CA file", or when deciding whether a new bounded context deserves its own service.
license: Apache-2.0
metadata:
  source: glotyuids/engineering-skills
  version: 0.1.0
---

# New microservice — end-to-end checklist

Follow the phases in order. Each phase ends in state the next phase depends on; skipping
ahead is how services reach production half-wired.

**`[!]` marks a rule that caused a real production incident when it was missed.** Everything
carrying `[!]` below has already cost someone a broken deploy, a crash loop, or a data leak.

## Scope boundary

This skill defines only the **procedure**: the order of operations and the wiring points for
standing up a new service in a repo that already has several. It does **not** define Go
coding style, chart internals, SQL patterns, or which cloud service backs a capability.

If these skills are installed, they own the detail this one only points at; if not
installed, follow the project's own conventions:

| Detail | Owning skill | Pack |
|---|---|---|
| Go layout, error handling, context rules | `go-conventions` | go |
| OpenAPI + event contract shape | `api-and-events` | go |
| Metrics, logging, lint, test gates | `observability-and-quality` | go |
| Chart/template structure, probes, resources | `kubernetes-helm` | infra |
| Deploy pipeline mechanics | `ansible-deploy`, `cicd-build-deploy` | infra |
| Secret storage and sync | `secrets-management` | infra |
| Provisioning new managed resources | `terraform-conventions` | infra |
| Schema design, indexes, RLS | `postgres-patterns`, `database-migrations` | database |
| ADR + docs conventions | `documentation-standards` | process |
| Rules for services that call an LLM | `llm-pipeline-rules` | llm |
| Which concrete service backs each capability below | the cloud vendor skill in `skills/cloud/` | cloud |

Capabilities referenced here — `MANAGED_PG`, `SECRET_MANAGER`, `REGISTRY`, `MANAGED_K8S`,
`LB`, `TFSTATE_BACKEND`, `IAM` — are contracts, not products. The vendor layer maps them.

## Phase 0 — Start from the reference service

- [ ] Copy the repo's canonical skeleton service (often `services/_template/` or the
      smallest working service) rather than assembling files by hand. Everything below
      explains **what to change and why**, not what to type from scratch.
- [ ] If the repo ships a template Dockerfile/chart with a `SERVICE_NAME` placeholder,
      replace every occurrence before touching anything else — a half-renamed template
      builds fine and deploys the wrong image name.

## Phase 1 — Planning

Before writing code, settle the bounded context. Writing code first is how two services
end up owning the same table.

- [ ] Read `ARCHITECTURE.md` and the architecture docs (`docs/architecture/{domain,services,infrastructure}.md`
      or equivalent). Do **not** contradict them.
- [ ] Confirm the service belongs in the current service catalog. If it is new to the
      catalog, that is an architectural decision → write an ADR before the code.
- [ ] Define the owned domain entities, repository interfaces and application services.
      Reuse shared types from the repo's `pkg/` — do not redefine an existing shared type
      in a new package.
- [ ] Identify inter-service dependencies in both directions: which services does it call,
      which will call it.
- [ ] Decide storage needs (Phase 2). "None" is a valid, documentable answer.
- [ ] Define the API contract (`api/openapi/<service>.yaml`). If the service emits or
      consumes events, define those contracts under `api/events/` too.
- [ ] Determine whether existing services need changes (new fields, new internal endpoints).
      Land those in the same plan, not as a surprise afterwards.
- [ ] If the service talks to an LLM, route it through the project's proxy/gateway service
      via the shared client. Never call a provider SDK directly from a product service.

## Phase 2 — Storage decision

Choose per data class, not per service. A service may use several.

| Data class | Store | Notes |
|---|---|---|
| Durable user-owned records | `MANAGED_PG` | One logical database per service; no cross-service table access. |
| Live presence, ephemeral sessions, expiry-backed state, caches | Redis-compatible KV | Anything that may be lost on restart without a support ticket. |
| Media, uploads, exports, large blobs | Object storage | Store the key in `MANAGED_PG`; never the blob. |
| Vector retrieval | `MANAGED_PG` + vector extension | Only if you actually do similarity search. |
| Nothing durable | none | Document the no-DB decision explicitly (Phase 8). |

- [ ] Every user-owned entity carries a `user_id`. Do not invent a parallel tenancy column
      when the platform already has one.

## Phase 3 — Service code

### Layout

```
services/<service>/
├── cmd/<service>/main.go        # config.Load → wire deps → run → graceful shutdown (30s)
├── internal/
│   ├── config/                  # env-tagged config struct + Load()
│   ├── domain/                  # entities, value objects, repo interfaces, errors
│   ├── app/                     # use cases over domain interfaces; validation + sanitization
│   └── adapters/
│       ├── http/                # router, handlers, DTOs, health endpoints
│       ├── db/                  # repository implementations
│       └── …                    # other adapters (object storage, other services, …)
├── api/openapi/<service>.yaml
├── migrations/                  # golang-migrate NNNNNN_*.{up,down}.sql
├── scripts/                     # operational scripts (seed, backfill, …)
├── infra/helm/<service>/
├── Dockerfile  Makefile  .golangci.yml  go.mod  README.md
```

`domain/` imports nothing from transport, storage drivers or external SDKs. Validation and
sanitization live in `app/`, not in handlers.

### go.mod

- Module path follows the repo's prefix: `<module-prefix>/<service>`.
- Match the Go version the other services already use. A one-off toolchain version breaks
  the shared `pkg/` modules for everyone.
- Add one `replace` directive per shared package the service consumes:

```go
replace (
    <module-prefix>/pkg/internalauth => ../../pkg/internalauth
    <module-prefix>/pkg/metrics      => ../../pkg/metrics
)
```

- Prefer the existing shared libraries for auth, CORS, metrics, sanitization and ownership
  checks over a local reimplementation.

### Config

- Parse env into a tagged struct; provide `Load()`.
- `DATABASE_DSN` carries the `required` tag if the service is DB-backed — fail at start,
  not at first query.
- Inter-service URLs default to the in-cluster service name (`http://<service>:80`) so a
  fresh environment works without per-env overrides.
- Shared cross-cutting credentials (e.g. the internal API key) are read where the client
  is constructed rather than threaded through the config struct, so a service that never
  makes internal calls does not require the variable.

### Auth and per-user isolation

- HTTP boundary: the user-facing auth middleware guards `/api/…`; the internal-auth
  middleware guards `/api/…/internal`. Every route is behind one of them.
- Build the request principal **once**, at the boundary, from verified token claims.
- `[!]` Repositories take that principal and scope **every** query. Two independent layers
  (defence in depth — either alone has failed before):
  1. set the per-transaction session variable the row-level-security policy reads;
  2. add the explicit owner predicate to the `WHERE` clause.
- `[!]` Never trust a `user_id` supplied by the client — body, query string or header.
- Internal endpoints are not "trusted therefore unscoped": they still pass a subject.

### Logging and the PII denylist

Structured JSON logs, with a redaction pass. `[!]` Never log:

- user free text (uploaded documents, message bodies, free-form report text, private
  motivation);
- email addresses, phone numbers, tokens, DSNs, API keys;
- precise location or exact coordinates;
- any field the product treats as private.

Log identifiers and shapes instead: `user_id`, request id, byte counts, enum outcomes.

### HTTP router and middleware order

Register middleware in exactly this order:

```
RequestID → RealIP → metrics → requestLogger → Recoverer → Timeout(30s) → CORS
```

`RequestID` first so every later layer can attach it; `Recoverer` below the logger so a
panic is still logged with its request id and does not take the pod down. Then mount
`/metrics`, `/healthz`, `/readyz`, the internal-auth routes, and the user-auth routes.

### Migrations

- `golang-migrate` file format: `NNNNNN_<description>.up.sql` / `.down.sql`.
- Idempotent DDL — `IF NOT EXISTS` on columns, indexes and tables.
- Backfill `UPDATE`s must be safe to re-run; a migration that is only correct once cannot
  be recovered after a timeout (see Phase 6).
- `[!]` Guard JSONB operations against NULL and scalar values. Set-returning functions
  abort the whole migration on the first bad row:

```sql
-- BAD: crashes on NULL or non-array jsonb columns
SELECT jsonb_array_elements_text(some_jsonb_column)

-- GOOD: safe extraction
SELECT jsonb_array_elements_text(
    CASE WHEN jsonb_typeof(some_jsonb_column) = 'array'
         THEN some_jsonb_column ELSE '[]'::jsonb END
)
```

- `[!]` If the platform isolates users at the row level, every user-owned table gets the
  policy in its **creating** migration — retrofitting isolation later means auditing every
  query written in between:

```sql
ALTER TABLE <t> ENABLE ROW LEVEL SECURITY;
ALTER TABLE <t> FORCE  ROW LEVEL SECURITY;
CREATE POLICY <t>_user_isolation ON <t>
  USING      (user_id = NULLIF(current_setting('app.user_id', true), '')::uuid)
  WITH CHECK (user_id = NULLIF(current_setting('app.user_id', true), '')::uuid);
```

### Dockerfile

Multi-stage, built from the **repo root** (the build context must include `pkg/`).

- Builder stage on the language image, runtime stage on a minimal base.
- Run as a non-root user (UID 1000). `HEALTHCHECK` and `EXPOSE` on the service port
  (`:8080/healthz`).
- `[!]` Copy every shared package the module `replace`s **before** `go mod download`.
  Downloading with unresolvable local replaces fails the build, and copying afterwards
  discards the dependency-layer cache on every source change:

```dockerfile
COPY pkg/internalauth /build/pkg/internalauth
COPY pkg/metrics      /build/pkg/metrics
```

- `[!]` Rewrite the `replace` paths for the container's directory layout — the
  `../../pkg/` paths that work in the monorepo do not exist inside the build context:

```dockerfile
RUN sed -i 's|../../pkg/|/build/pkg/|g' go.mod
```

- Copy `migrations/` into the image if the service has any, and bundle the `migrate`
  binary in the same image so the migration job can run as the same non-root user.
  Installing the migration tool at container start instead forces the job to run as root
  and adds a network dependency to every deploy.

## Phase 4 — Chart and deploy manifests

Clone the chart of the reference service. Typical templates: `_helpers.tpl`, `deployment`,
`service`, `configmap`, `serviceaccount`, `hpa`, `externalsecret`, `migration-job`, plus a
TLS-material configmap if `MANAGED_PG` requires one.

### values

- Namespace, image repository (`REGISTRY`) and tag come from values, never hardcoded.
- Service port `80` → `targetPort` `8080` (named `http`).
- `service.type` follows how `LB` reaches the cluster: `ClusterIP` when an in-cluster
  ingress controller fronts it, a node-port type when the external load balancer targets
  node ports directly. Follow the project's existing convention — do not mix both.
- `[!]` If node ports are used, allocate the port from the registry the project maintains
  (the shared env vars file that lists every service's port). Two services silently sharing
  a node port is a deploy-time failure that looks like a routing bug.
- Pod security: `runAsNonRoot: true`, `runAsUser: 1000`.
- Probes: `/healthz` (liveness), `/readyz` (readiness). Readiness must actually check
  dependencies; liveness must not.
- Metrics scrape annotations on the service port.
- Resource requests well below limits (e.g. `50m/128Mi` → `500m/512Mi`); HPA for stateless
  HTTP services (e.g. min 2 / max 10 on CPU 70% / memory 80%).

### Config and secrets

- The ConfigMap carries **all** non-secret env vars from the config struct; the deployment
  consumes it with `envFrom`. A variable in the struct but not the ConfigMap is a silent
  default in production.
- Secrets never enter the ConfigMap. They arrive as a Kubernetes Secret synced from
  `SECRET_MANAGER` by the cluster's secret-sync operator, and the deployment references it
  by `envFrom secretRef` or per-key `secretKeyRef`:

```yaml
env:
  - name: DATABASE_DSN
    valueFrom:
      secretKeyRef:
        name: {{ include "<service>.fullname" . }}-secrets
        key: database-dsn
  - name: INTERNAL_API_KEY
    valueFrom:
      secretKeyRef:
        name: internal-api-key
        key: api-key
        optional: false
```

- The Secret name in the sync manifest must match the name the deployment template builds.
  A mismatch surfaces as an indefinitely pending pod, not as an error.
- Add a `checksum/config` pod annotation over the ConfigMap so a config-only change
  actually rolls the pods.

### `MANAGED_PG` transport security

- `[!]` If the DSN held in `SECRET_MANAGER` references a CA certificate path, that
  certificate **must** be mounted into the pod or the service crash-loops at startup with
  `unable to read CA file`. Ship the CA as a configmap + volume mount, gated on a
  `database.ssl.enabled` value.
- *Verify:* the application driver and the migration tool's driver may have different TLS
  requirements — one can be satisfied by requiring TLS without verification while the other
  needs the CA file on disk. Check both paths for your driver pair before assuming the
  migration job needs the same mount as the app, and re-check when either driver is
  upgraded. Which certificate, which path, and which drivers apply is vendor detail; see
  the cloud vendor skill.

### Migration job

- A Helm hook job, `pre-install,pre-upgrade`, using the **same image** as the service.
- Runs `migrate -database "$DATABASE_DSN" -path /migrations up`.
- Same non-root user as the app (possible because the binary is bundled — Phase 3).
- Give the hook its own timeout: the release timeout covers the hook, and a backfill that
  outruns it leaves the schema dirty (Phase 6).

### Single-consumer and long-polling services

If the service holds a long poll or is otherwise the only permitted consumer of an upstream:

- `replicaCount: 1`;
- `[!]` `strategy.type: Recreate` (never `RollingUpdate` — a rolling deploy briefly runs two
  consumers and the upstream drops or duplicates messages);
- autoscaling disabled. An HPA silently reintroduces the second consumer.

## Phase 5 — Deploy wiring

*Verify: the registration points below are named after a reference pipeline layout. Confirm
the file names against your own pipeline before editing.*

The pipeline enumerates services in more than one place. Register the new service in
**every** one:

| Registration point | Contents |
|---|---|
| All-services deploy list | name, build context = repo root, Dockerfile path, chart path, `has_migrations`, change-detection paths |
| Single-service deploy map | the same entry, used by targeted deploys |
| Shared services list variable | the service name, for anything that iterates services |
| Per-environment overrides | inter-service URLs, `migrations.enabled`, `database.ssl.enabled`, route/port allocation |

- `[!]` Registering only in the all-services list makes "deploy just this one service"
  silently do nothing — it resolves to an empty entry and reports success.

### Secrets (`SECRET_MANAGER`)

- `[!]` Add the DSN computation for the new database wherever the pipeline builds DSNs.
  A `SECRET_MANAGER` entry created with an empty DSN deploys cleanly and fails at runtime.
- Add the service's entry to the secret definitions.
- `[!]` Add that entry to the list of **expected** secrets the sync check validates — an
  entry absent from that list is never verified and its absence is never reported.
- Create the sync manifest mapping `SECRET_MANAGER` properties to Kubernetes Secret keys.
- Update `.secrets.example` with every new variable and a one-line description; put real
  values only in the ignored per-environment secrets file.

### Infrastructure

- New database, bucket or queue → declare it in the infrastructure code, with state in
  `TFSTATE_BACKEND` and access granted through `IAM`.
- `[!]` Apply the infrastructure change **before** the first deploy. Migrations run as a
  pre-install hook and fail if the database does not exist yet.

## Phase 6 — Deploy sequence and first-deploy failure catalog

First-time order (names are illustrative; use the repo's Makefile targets):

```
1. make secrets-sync ENV=<env>      # create SECRET_MANAGER entries + apply sync manifests
2. make terraform-apply ENV=<env>   # provision the database / bucket if new
3. make deploy ENV=<env>            # build + push to REGISTRY, run migrations, release the chart
```

Known first-deploy failures, all observed in production:

- **`[!]` The install is skipped as "unchanged".** Pipelines that run a release diff before
  deploying can report "no changes" for a release that does not exist yet, and skip the
  install entirely while reporting success. Workaround: run the install manually once, or
  disable the skip-unchanged behaviour for the first deploy.
- **`[!]` Migration job timeout leaves the schema dirty.** The release timeout includes the
  pre-install hook. A migration with a large backfill can exceed it; the tool then records
  the version as *dirty* and every later deploy refuses to run. Recovery: run a one-off pod
  from the service image (the `migrate` binary is bundled) against an empty migrations
  directory, force the version back to the last clean one, then re-run with a longer hook
  timeout and a smaller backfill:

```bash
migrate -database "$DATABASE_DSN" -path /empty force <PREVIOUS_VERSION>
```

  This is why backfills must be re-runnable (Phase 3) — forcing back replays them.
- **`[!]` `unable to read CA file` crash loop.** The release was installed without the
  `MANAGED_PG` TLS material enabled. Upgrade with the CA configmap and mount enabled; the
  pod will not recover on its own.
- **Pod stuck pending on a missing Secret.** The secret-sync manifest name and the name the
  deployment expects disagree, or the `SECRET_MANAGER` entry was never created.

## Phase 7 — Verify

- [ ] Pods `Running`, not `CrashLoopBackOff` or `ImagePullBackOff`.
- [ ] Startup logs are clean and show the database connection established.
- [ ] `/healthz` and `/readyz` both return success from inside the cluster.
- [ ] The service is discoverable by its dependents (Service + DNS name resolve).
- [ ] The release is listed by the release tool in the target namespace, at the expected
      chart and image tag.
- [ ] Migrations applied: the schema version matches the highest migration and is not dirty.
- [ ] **Isolation test**: a second user cannot read the first user's rows. Assert this in a
      test against the repository or app layer, not by eyeballing a query.
- [ ] An end-to-end call through the real route (`LB` → service → dependency) succeeds.

## Phase 8 — Document

- [ ] Update the architecture docs: services table, diagram, and the service's boundary and
      ownership.
- [ ] Write an ADR if the service introduces a new bounded context or an architecturally
      significant choice; update `ARCHITECTURE.md` if the top-level picture changed.
- [ ] Update `.secrets.example` with every new variable.
- [ ] Tick the plan's definition of done and append the progress log, if the project keeps one.

## Done means

- [ ] `make build`, `make test`, `make vet` and the linter all pass; formatting is clean.
- [ ] The OpenAPI contract file exists and matches the implemented routes.
- [ ] Migrations exist, **or** an explicit no-database decision is documented.
- [ ] Every config variable appears in the ConfigMap or in `SECRET_MANAGER`, and in
      `.secrets.example`.
- [ ] The service is registered in every deploy registration point (Phase 5).
- [ ] Phase 7 verification passed in at least one deployed environment.
- [ ] The service boundary is documented and, where required, an ADR is merged.

## Vendor delta

The cloud vendor skill must supply:

- `MANAGED_PG` — whether TLS requires a CA certificate on disk, where it is mounted from,
  and which connection modes each driver supports.
- `SECRET_MANAGER` — the entry/property model, the sync mechanism into Kubernetes Secrets,
  and the identity that is allowed to read entries.
- `REGISTRY` — image path format and the pull credentials the cluster needs.
- `MANAGED_K8S` — how the cluster is addressed by the pipeline.
- `LB` — whether external traffic arrives via an in-cluster ingress or by targeting node
  ports, which determines `service.type` in Phase 4.
- `TFSTATE_BACKEND` and `IAM` — state storage and the permissions the deploy identity needs.

## Project delta

The consuming repo must supply:

- **Module prefix** for `go.mod` paths and the list of shared `pkg/` modules available.
- **Reference service** to clone in Phase 0, and the template Dockerfile/chart location.
- **Namespace** and **cluster context** per environment.
- **Chart location convention** (`services/<service>/infra/helm/<service>/` above).
- **Deploy registration points** — the actual file names for the four rows in Phase 5.
- **Route or node-port registry** — the file that records the allocation per service.
- **Makefile target names** for secrets sync, infrastructure apply and deploy.
- **Auth model** — the identity provider, the claim carrying the user id, and the shared
  middleware names.
- **Isolation model** — whether row-level security is in force and the session variable
  name its policies read.
- **Architecture documents** to read in Phase 1 and update in Phase 8, and the ADR location.
