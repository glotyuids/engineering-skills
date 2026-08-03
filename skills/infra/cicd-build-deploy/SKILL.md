---
name: cicd-build-deploy
description: The build and deploy pipeline — Make as the single entrypoint, container image build rules, deploy orchestration order, cluster-context pinning and production safety. Use when writing or changing a Dockerfile, adding Make targets, building or pushing images, running or troubleshooting a deploy to staging or production, wiring CI, or when the user says "deploy this", "ship it to prod", "make deploy", "the build is broken", "why was my service skipped", "roll it back", or "set up CI/CD". Vendor-neutral — the pipeline is described against capabilities (MANAGED_K8S, REGISTRY, SECRET_MANAGER, MANAGED_PG, TFSTATE_BACKEND, LB, IAM), never against a named cloud provider.
license: Apache-2.0
metadata:
  source: glotyuids/engineering-skills
  version: 0.1.0
---

# Build and deploy pipeline

This skill defines only the **pipeline**: which `make` targets exist and what they must
guarantee, how container images are built, in what order a deploy executes, and the safety
rules around production. It does not define Terraform module layout (`terraform-conventions`),
orchestrator role structure (`ansible-deploy`), chart internals (`kubernetes-helm`), Makefile
authoring style (`makefile-conventions`) or the secret contract itself (`secrets-management`) —
those are sibling skills in this pack.

Capabilities assumed: `MANAGED_K8S`, `REGISTRY`, `SECRET_MANAGER`, `MANAGED_PG`,
`TFSTATE_BACKEND`, `LB`, `IAM`. The concrete services behind them come from the vendor skill
(see [Vendor delta](#vendor-delta)). No language is assumed: `make build` produces the
artifacts, whatever they are. If a language-pack skill (e.g. `go-conventions`) is installed,
follow it for the inside of the build; otherwise follow the project's own conventions.

## 1. Pipeline stance

- **Make is the entrypoint; whatever runs it is an implementation detail.** The pipeline must
  be independent of any specific git host or CI platform — never assume hosted runners,
  provider-specific workflow syntax, or provider-managed secrets. A developer shell, a cron
  host and a CI job must all run the same target and get the same result.
- Automation chain: `Makefile` → orchestrator (playbooks/roles) → Helm + kubectl →
  `MANAGED_K8S`. A CI platform, if one is ever adopted, calls `make <target>` and nothing else.
- Running **Make + orchestrator with no CI platform at all** is a legitimate, common choice.
  Record whichever way the project went as an ADR, so nobody "fixes" it later by accident.
- Everything a deploy needs must be reproducible from a clean checkout plus the local secret
  file plus credentials. No step may exist only in someone's shell history or a CI web UI.

## 2. Make target contract

Root `Makefile` — local development. Applies over **every** module / workspace member the repo
discovers, not just the one you are standing in:

| Target | Effect |
|---|---|
| `make help` | list the available targets (keep it the first target) |
| `make build` | produce the artifacts for every module |
| `make test` | run tests for every module |
| `make lint` | static analysis per module |
| `make fmt` | formatting per module |
| `make deps` | dependency hygiene per module (lockfile refresh, prune, verify) |
| `make modules` | list the modules the Makefile discovered — the debugging aid when a module is silently skipped |
| `make docker-build` | build the image(s) locally, no push |

These names are the contract. An ecosystem's own idiom (a separate static-analysis pass, a
lockfile command under another name) may exist alongside them, but the contract target must
exist and must delegate to it — a caller never needs to know which toolchain is underneath.

Per-service `Makefile` (in the service directory) — the inner loop: `build`, `run`,
`run-dev` (hot reload), `test`, `lint`, `fmt`, `migrate-up` / `migrate-down` / `migrate-create`,
plus any project-specific run target (a client app start target, a local emulator, …).

Root `Makefile` — deploy and ops:

| Target | Effect |
|---|---|
| `make deploy` | deploy **changed** services to staging (change detection from a git diff against a base ref) |
| `make deploy-prod` | deploy changed services to production |
| `make deploy-prod-all` | force-deploy **all** services to production |
| `make deploy-prod-service SERVICE=<name>` | deploy exactly one service |
| `make deploy-prod-<component>` | shortcut for a component that is not a normal service (e.g. a frontend bundle) |
| `make secrets-sync ENV=<env>` | push the local secret file into `SECRET_MANAGER` and apply the sync objects |
| `make infra-plan` / `make infra-apply` `ENV=<env>` | infrastructure changes (also seen as `terraform-plan` / `terraform-apply`) |
| `make status` / `logs` / `restart` / `rollback` | ops, `SERVICE=<name>` where relevant |

Rules for every target above:

- **Idempotent and re-runnable.** A half-failed deploy is re-run, never resumed by hand.
- **The environment is explicit.** `ENV=<env>` or a dedicated `-prod` target — never infer
  production from the current branch, the current kube-context, or an exported shell variable.
- **Production is a separately named target, never a flag on the staging one.** Typos should
  not be able to promote a staging deploy.
- Change detection has a defined base ref. Say what it is; "changed since my last commit" is
  not a specification.

## 3. Cluster context pinning

`[!]` **Every `kubectl` and `helm` invocation passes an explicit context, always, everywhere.**

```bash
kubectl --context "$KUBE_CONTEXT" -n "$NAMESPACE" get pods
helm --kube-context "$KUBE_CONTEXT" -n "$NAMESPACE" upgrade --install <release> <chart>
```

Never rely on the current context. A shared kubeconfig accumulates entries for several
environments and several projects; whichever one was selected last wins silently, so a command
meant for staging lands in production — with no error, no prompt, and a completely plausible
success message.

- The value flows from **one variable per environment**: `KUBE_CONTEXT` in the Makefile and in
  shell helpers, `kube_context` in the orchestrator's group vars. Context names are never
  written as literals in scripts, roles or docs (`my-cluster`, `<env>-cluster` in examples).
- This covers **every** call site: Make targets, orchestrator tasks, `scripts/k8s-*.sh`
  helpers, and the ad-hoc commands typed during an incident. Ad-hoc is the dangerous one — that
  is where the mistake actually happens.
- `kubectl config use-context` is not a substitute: it mutates shared state that the next
  command in another terminal inherits.
- Pin the namespace the same way (`-n "$NAMESPACE"` from a variable). Never depend on a
  kubeconfig's default namespace.
- Review gate: a diff that adds a bare `kubectl` or `helm` call without a context flag is
  rejected, no matter how small.

## 4. Container image build rules

- **Multi-stage.** Build toolchain in the build stage; the runtime stage carries the artifact
  and nothing else.
- **Run as a non-root user in production images.**
- **Order layers for cache reuse**: dependency manifests and dependency resolution first, source
  last, so a code change does not re-download the world. Design build and deploy steps to reuse
  existing layers and caches wherever possible.
- **Pre-bake at build time** everything the container would otherwise do at startup: code
  generation, migration binaries and migration files, static assets, templates. Runtime
  containers start fast and cannot fail on a missing generator.
- **Tag images immutably** — the commit SHA, optionally plus a semantic tag. Never deploy
  `latest`; a rollback needs a tag that still means what it meant yesterday.
- Push to `REGISTRY` only from the deploy pipeline, never from an ad-hoc local run "just to
  test" (see §8).

### Monorepo build context and local path dependencies

`[!]` In a monorepo the image build runs **from the repository root**, not from the service
directory — otherwise the shared packages the service depends on are outside the build context
and the build fails at dependency resolution with a misleading "not found".

Copy each local path dependency in before dependency resolution, then rewrite the relative path
overrides in the manifest to the in-image paths:

```dockerfile
# docker build -f services/<service>/Dockerfile .    ← context is the repo ROOT
COPY <shared>/<dep-a> /build/<shared>/<dep-a>        # one COPY per local dependency,
COPY <shared>/<dep-b> /build/<shared>/<dep-b>        # before any resolution step
COPY services/<service>/<manifest> /build/
RUN sed -i 's|\.\./\.\./<shared>/|/build/<shared>/|g' /build/<manifest>
RUN <dependency-resolution-command>                  # overrides now point at real paths
COPY services/<service>/ /build/
RUN <build-command>
```

The manifest file name and the override-directive syntax are language-specific; if a language
pack skill is installed, follow its version of this rule. Adding a new shared package means
adding its `COPY` line to **every** Dockerfile that depends on it — this is the most common
"works locally, breaks in the image" failure.

## 5. Deploy orchestration order

The orchestrator runs these phases in this order. The order is the point: each phase depends on
the previous one having landed.

1. **Validate the environment.** Resolve the env name, the cluster context and the namespace;
   check credentials and required tools are present; check the working tree state. Fail here,
   before anything has been mutated.
2. **Infrastructure, only if it changed.** Plan, show the plan, then apply — per
   `terraform-conventions`. Skipped entirely when no infra files changed.
3. **Secrets sync.** Local secret file → `SECRET_MANAGER` → sync objects applied. Before images
   and rollout, so a newly added key already exists when the new pods start.
4. **Build and push images** for the changed services, in parallel.
5. **Database migrations**, as a Job / pre-install,pre-upgrade hook, before the new application
   pods roll. If the `database-migrations` skill is installed, follow it; otherwise follow the
   project's own migration conventions.
6. **Diff, then apply the charts.** `helm diff` first (a reviewable summary, and the basis for
   skipping unchanged releases), then `helm upgrade --install`, in parallel across services.
7. **Verify.** Rollout status, health endpoints, `make status`. A deploy that is not verified is
   not finished.

### Parallelism cap

- Deploying 2–3 specific services: run the per-service target in parallel, one per service.
- **Never more than 3 concurrent deploys.** Image builds are CPU-heavy; beyond three, the build
  host (a laptop or a single runner) thrashes, everything slows down together, and steps start
  hitting timeouts — the deploy takes longer than the sequential one would have.
- 4+ services: use the aggregate `deploy` / `deploy-prod` target, which does change detection
  and sequences the chart applies for you.

## 6. Secrets in the pipeline

```text
.secrets.<env>          git-ignored, exists only on the operator's machine
   │  make secrets-sync ENV=<env>          (one command, one direction: local → cloud)
   ▼
SECRET_MANAGER
   │  sync operator / CSI driver
   ▼
cluster Secret  <release>-<service>
   │  secretKeyRef
   ▼
pods
```

- `.secrets.example` is the **committed contract**: every key, a comment, and the command that
  generates a value. Real values never enter git, never enter chart values, never enter images.
- Adding a secret is one workflow: extend `.secrets.example` in the same commit as the feature,
  set the value locally, `make secrets-sync`, reference it via `secretKeyRef` in the chart.
- **Rotation is three steps**: update the value → wait for the sync operator's refresh interval
  (an hour is a common default) or force a refresh → **rolling restart the consumers**. Changing
  the stored value alone does not restart pods, and the old value stays live until they restart.
- The sync object's name and the Secret name the chart expects must match exactly; see
  `secrets-management` and `kubernetes-helm`.
- Never echo secret values into build or deploy logs — including "helpful" debug output of a
  full connection string.

## 7. Chart and artifact locations

- One chart per service, living with the service; shared platform charts in a top-level infra
  directory; new services start from the repo's service-template chart. Exact paths are project
  delta.
- Migrations run as a `pre-install,pre-upgrade` hook Job, not as an init container racing the
  app.
- Services are exposed through the `LB` capability per the project's ingress convention; the
  vendor skill says what that means concretely.

## 8. Production safety

- **Never apply a destructive infrastructure change without explicit confirmation for that
  specific action.** Show the plan's destroy/replace lines first and wait. This includes
  `destroy`, replacements, and deleting a resource by hand to "unblock" an apply.
- **Never push an image or apply any cloud change without clear user intent to deploy.** "Fix
  the build" is not consent to deploy. "The tests pass" is not consent to deploy.
- Prod deploys are explicit and named; they are never a side effect of a test, a lint fix, or a
  convenience target.
- **Know the rollback path before deploying**, not after. `make rollback SERVICE=<name>` must
  exist and must have been exercised.
- Do not hand-edit live cluster objects to make a deploy pass. Fix the chart or the values and
  re-run the target; anything done by hand is lost on the next apply and invisible to review.
- Do not copy production data to a laptop or into staging to debug a deploy. Treat the project's
  sensitive categories (personal data, location traces, safety or incident reports, customer
  content) as untouchable during pipeline work.
- A failed production deploy is an incident-shaped event: record the failing phase, the command,
  and the recovery. If the `incident-response` skill is installed, follow it; otherwise write it
  into the project's known-issues document.

## 9. Known failure modes

| Symptom | Cause | Fix |
|---|---|---|
| Brand-new service is silently skipped on its first deploy `[!]` | `helm diff` reports "no changes" for a release that does not exist yet, and the skip-unchanged optimisation drops it | `helm install` it once explicitly, or disable the skip-unchanged flag for that run |
| Every deploy now fails at the migration step `[!]` | a failed migration left the version table marked **dirty** | force the version back to the last good one, fix the migration, re-run |
| Image build fails at dependency resolution in a monorepo | a local path dependency was not `COPY`ed, or the path overrides were not rewritten | see §4 — add the `COPY`, rewrite the manifest |
| The deploy went to the wrong cluster | a `kubectl`/`helm` call relied on the current context | see §3 — pin the context from the variable, everywhere |
| Migration Job succeeds but the application crash-loops on the datastore connection `[!]` | the app driver and the migration tool disagree about TLS: one needs a CA file mounted, the other is satisfied by requiring TLS alone | mount the CA for the app; the vendor skill names the file and the connection parameter |
| A service deploys but serves the previous build | a mutable tag (`latest`) was reused, so nothing changed from the cluster's point of view | tag by commit SHA |

## 10. Definition of done

- [ ] `make build`, `make test`, `make lint` pass from a clean checkout, for every module.
- [ ] The image builds from the repo root, is multi-stage, runs as non-root, and is tagged by commit.
- [ ] Every `kubectl` / `helm` call in the diff passes an explicit context from the variable.
- [ ] The deploy target is idempotent and safe to re-run after a partial failure.
- [ ] New secret keys are in `.secrets.example` and synced; no value is in git or in a log.
- [ ] Migrations run as a hook Job before the rollout, and the dirty-state recovery is known.
- [ ] A rollback command exists for the service and has been tried.
- [ ] The whole pipeline still runs with no CI platform present.
- [ ] `make status` shows the expected version running after the deploy.

## 11. Honesty about maturity

- In a freshly bootstrapped repo the deploy and cloud targets are **placeholders**. Do not claim
  resources are provisioned until the infra modules, orchestrator roles, `REGISTRY`,
  `SECRET_MANAGER` wiring and the charts are actually in place and have been applied at least
  once against a real environment.
- A target exiting 0 is not evidence of a deploy when the target is a stub. Verify against the
  cluster before reporting success.
- Mark pipeline steps that were authored but never executed against a live environment —
  `Verify: never run against a real cluster` — and keep the marker until someone runs it.

## Vendor delta

The `skills/cloud/<vendor>` skill must supply, per capability:

- `MANAGED_K8S` — how kubeconfig entries are created and the cluster-context naming convention.
- `REGISTRY` — the image path format, authentication for build hosts and for cluster pulls, and
  the retention/lifecycle behaviour (whether old tags are ever cleaned up automatically).
- `SECRET_MANAGER` — the secret store, the sync operator or CSI driver used, its refresh
  interval, its naming rules, and any image-mirroring needed to install it.
- `MANAGED_PG` — TLS requirements, including any CA file the application driver needs but the
  migration tool does not (see §9).
- `TFSTATE_BACKEND` — the state backend configuration and the environment variables its client
  expects.
- `LB` — how a service is exposed (ingress controller, node ports, other) and per-environment
  address allocation.
- `IAM` — the one-time bootstrap the operator performs by hand: account and billing, a service
  account plus its credential file, the state bucket and its keys, organisation/folder
  identifiers, and how a short-lived CLI token is obtained. None of this is required to write
  IaC or to build locally — only to apply infrastructure or deploy.

## Project delta

The consuming repo supplies:

- Environment names, and the `KUBE_CONTEXT` value and namespace for each.
- The service list, which services are independently deployable units, and the base ref used for
  change detection.
- Any Make targets beyond the contract in §2 (component shortcuts, client-app targets).
- Chart locations: per-service chart path, shared platform chart path, service-template path.
- The image name and tag scheme, and the registry path variable.
- Local secret file names and the committed example file name.
- The migration tool and its commands.
- The orchestrator in use and where its playbooks, roles and inventories live.
- What counts as sensitive data in this domain (§8).
- The maximum number of parallel deploys, if the default cap of 3 does not fit the build host.
