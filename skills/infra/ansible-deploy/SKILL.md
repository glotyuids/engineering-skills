---
name: ansible-deploy
description: Ansible as the deploy orchestrator — inventory per environment, the playbook and role set, the service catalog every new service must be registered in, the deploy phase order, idempotence rules and the parallelism cap. Use when adding a service to the deploy pipeline, writing or changing a playbook, role, inventory or group_vars file, running a deploy through Ansible, or when the user says "add the service to Ansible", "it built but never deployed", "my service isn't in the deploy", "the playbook skipped it", "deploy just one service", "why did Ansible say changed", "run the deploy playbook", "make deploy does nothing", or "add it to the services list". Vendor-neutral — written against capabilities (MANAGED_K8S, REGISTRY, SECRET_MANAGER, MANAGED_PG, TFSTATE_BACKEND, LB, IAM), never a named cloud provider.
license: Apache-2.0
metadata:
  source: glotyuids/engineering-skills
  version: 0.1.0
---

# Ansible as the deploy orchestrator

This skill defines only the **orchestrator layer**: how the Ansible tree is laid out, what
each playbook and role is responsible for, **every place a service must be registered**, the
order the deploy phases run in, and the idempotence rules. It does not define the Make target
contract or image build rules (`cicd-build-deploy`), chart internals (`kubernetes-helm`), the
Terraform module layout (`terraform-conventions`), the secret contract (`secrets-management`),
or Makefile authoring style (`makefile-conventions`) — those are sibling skills in this pack.

Capabilities assumed: `MANAGED_K8S`, `REGISTRY`, `SECRET_MANAGER`, `MANAGED_PG`,
`TFSTATE_BACKEND`, `LB`, `IAM`. The concrete services behind them come from the vendor skill.
No language is assumed: a service's build step is "the container image build for this service",
whatever toolchain is inside it. If a language-pack skill is installed, follow it for the inside
of the build; otherwise follow the project's own conventions.

## 1. Stance: Ansible is a local orchestrator, not config management

- Every play runs `hosts: localhost`, `connection: local`, `gather_facts: false`. The
  **inventory does not describe cluster nodes** — the nodes are managed by `MANAGED_K8S` and are
  never SSH'd into. Ansible exists here to sequence `terraform`, image builds, `kubectl` and
  `helm` deterministically, with variables per environment.
- Ansible is invoked **only through Make** (`make deploy`, `make deploy-prod-service SERVICE=…`).
  A human typing `ansible-playbook` directly is a fallback, not the interface. See
  `cicd-build-deploy` for the target contract.
- Running Make + Ansible with **no CI platform at all** is a legitimate choice. When it is the
  choice, the deploy playbook is also the only gate — see §6.
- `ansible.cfg` lives at the Ansible root and pins: `inventory`, `roles_path`,
  `retry_files_enabled = false`, a generous `timeout`, and the YAML inventory plugin. Nobody
  should need flags to run the playbook correctly from the Ansible directory.

## 2. Tree layout

```text
infra/ansible/
├── ansible.cfg
├── inventories/
│   ├── <env>/                    # one directory per environment — staging, prod, …
│   │   ├── hosts.yml             # localhost only
│   │   └── group_vars/
│   │       ├── all.yml           # the environment: identity, defaults, per-service overrides
│   │       └── vault.yml         # encrypted vars, if any must live in git (see §3)
│   └── …
├── playbooks/                    # one playbook per verb (§4)
│   └── tasks/                    # shared task files included by playbooks
├── roles/                        # one role per capability-facing step (§5)
├── vars/
│   └── services.yml              # THE service catalog (§7)
└── callback_plugins/             # optional: deploy progress output
```

## 3. Inventory per environment

One inventory directory per environment. The environment is chosen by **path**
(`-i inventories/<env>/hosts.yml`) or by an explicit `-e env=<env>` — never inferred from the
git branch, the shell, or the current kube-context.

`group_vars/all.yml` is the single description of an environment. It carries:

| Group | Variables |
|---|---|
| Identity | `env`, `project`, `k8s_namespace`, `kube_context`, the `REGISTRY` path/name |
| Image | `image_tag` (commit sha by default), `push_images`, `image_pull_policy`, `target_arch`, build timeout |
| Secrets | `secrets_file` (`.secrets.<env>`), the `SECRET_MANAGER` scope/folder identifier, the sync-operator credential file path |
| Infra | whether this env applies infrastructure, auto-approve policy, `TFSTATE_BACKEND` env file location |
| Rollout defaults | replica count, resource requests/limits, autoscaling bounds, `helm_timeout` |
| Change detection | `shared_paths` — paths whose change rebuilds everything (§8) |
| Per-service | `service_overrides.<name>` — chart values for this env only (§7) |

Rules:

- `[!]` **`kube_context` is a variable, and every `kubectl` / `helm` task passes it explicitly**
  (`--context` / `--kube-context`). Never rely on the kubeconfig's current context: a shared
  kubeconfig accumulates entries for several environments and several projects, whichever was
  selected last wins silently, and a command meant for staging lands in production with a
  completely plausible success message. Same for the namespace. Full rule in `cicd-build-deploy`.
- Prefer deriving the context from the cluster name (`kube_context: "<prefix>-{{ k8s_cluster_name }}"`)
  and having the kubeconfig role **rename the freshly fetched context to that stable name**, so
  the variable and reality cannot drift.
- Anything a cloud CLI resolves by "current profile" (account, folder, project) is pinned in
  `all.yml` too. Operators have more than one profile.
- Production defaults live in the prod inventory, not in role defaults. Role defaults are the
  safe minimum; the environment is where the real numbers are.
- Real secret **values** never live in group_vars, encrypted or not — they go through the
  `.secrets.<env>` → `SECRET_MANAGER` path (`secrets-management`). An encrypted `vault.yml` is
  for low-sensitivity variables that genuinely must be versioned, not a secret store.

## 4. The playbook set

One playbook per verb. Each is independently runnable and idempotent.

| Playbook | Responsibility |
|---|---|
| `deploy.yml` | the full pipeline for all services, or a subset via change detection |
| `deploy-service.yml` | exactly one service, end to end (`-e service=<name>`) |
| `build-service.yml` | build + push one image, no rollout — used to pre-warm or debug a build |
| `infra.yml` | `TFSTATE_BACKEND`-backed infrastructure; takes `-e tf_action=init\|plan\|apply\|output\|destroy` |
| `secrets.yml` | local secret file → `SECRET_MANAGER` → sync objects; deliberately **separate** from `deploy.yml` |
| `ops.yml` (or one playbook per verb) | `status`, `logs`, `restart`, `rollback`, `shell`, `port-forward`, e2e |
| `undeploy.yml` / `clean.yml` | remove a release / clean build state — destructive, guarded (§10) |

- Secrets sync is a **separate playbook**, not a step everyone pays for on every deploy. The
  deploy playbook may include it behind an explicit opt-in flag (`-e sync_secrets=true`),
  defaulting to false.
- A destructive playbook requires an explicit confirmation variable
  (`-e confirm_destroy=true`); the Make target must not set it silently.
- `-e service=<name>` must **fail loudly on an unknown name**, listing the known ones. Silently
  deploying nothing is the single most expensive failure mode in this whole skill.

## 5. The role set

One role per capability-facing step; roles are the reusable unit, playbooks only sequence them.

| Role | Does |
|---|---|
| `common` | task files, not a monolith: `validate`, `kubeconfig` / `switch-context`, `detect-changes`, `detect-arch`, cache check/save |
| `terraform` | wraps `TFSTATE_BACKEND`-configured plan/apply/output; see `terraform-conventions` |
| `registry-auth` | authenticates the build host to `REGISTRY` |
| `docker-build` | builds and pushes images for a list of services |
| `migrations` | runs the migration Job / verifies the chart's pre-upgrade hook |
| `helm-deploy` | `helm diff` then `helm upgrade --install` per service |
| secret-manager sync | local file → `SECRET_MANAGER` payloads |
| secret-operator install | installs/refreshes the sync operator in the cluster |
| ingress / platform | `LB` wiring and shared platform manifests |

`common/validate` runs **first in every deploy** and fails before anything is mutated. It checks:

- [ ] required CLI tools are on PATH (`kubectl`, `helm`, the container builder, `git`, `jq`, the cloud CLI, `terraform` when infra is in scope)
- [ ] the `kube_context` named in group_vars **exists** in the kubeconfig — assert on the list, do not discover it
- [ ] credentials for `REGISTRY`, `SECRET_MANAGER` and `TFSTATE_BACKEND` resolve
- [ ] the environment name is one of the known environments
- [ ] any project-specific budget assertions (e.g. a `MANAGED_PG` connection budget: sum of per-service pool maxima × replica ceilings must stay under the role's client limit, with headroom for rolling updates, migrations and probes)

## 6. Deploy phase order

The order is the point — each phase depends on the previous one having landed.

1. **Pre-deploy gate.** With no CI platform, the deploy *is* the gate: build, static analysis
   and tests over the whole repo, before anything is pushed. It catches the change a concurrent
   branch merge silently dropped. Provide an escape hatch (`-e skip_integrity_check=true`) that
   exists **only** for an emergency rollback to a known-good tag.
2. **Validate the environment** (§5) — resolve env, context, namespace; check tools and
   credentials. Fail here.
3. **Fetch/switch kubeconfig context**, then detect host architecture if images are
   arch-specific.
4. **Infrastructure, only if it changed.** Compare a content hash of the infra directory against
   a committed `.last-applied` marker and skip the whole phase when they match — infra API calls
   are slow and mostly no-ops. Provide `-e force_infra=true`. Update the marker only after a
   successful apply.
5. **Platform prerequisites** — ingress/`LB` controller, shared platform charts, cluster-wide
   ConfigMaps (e.g. a CA bundle) — before any service that depends on them.
6. **Sync secrets** (opt-in flag, or the separate playbook run first). Before images and rollout,
   so a newly added key already exists when the new pods start.
7. **Detect changed services** (§8), unless `-e force_deploy_all=true`.
8. **Build and push images** for the changed services, in parallel — **capped** (§9).
9. **Database migrations** as a Job or a `pre-install,pre-upgrade` hook, before the new
   application pods roll. If the `database-migrations` skill is installed, follow it.
10. **`helm diff`, then `helm upgrade --install`** per service, in parallel — same cap.
11. **Verify.** Rollout status, health endpoints, `make status`. A deploy that is not verified is
    not finished.

Phases 4–6 are skipped independently and explicitly (`-e deploy_infra=false`, …). A skip is
always **announced in the output**; a silent skip is indistinguishable from a bug.

## 7. Registering a service — every point, or it never deploys

`[!]` **Adding a service means updating EVERY registration point. Miss one and you get a
service that builds fine, passes review, and never deploys — with no error anywhere.** This is
the classic failure of this architecture and it has bitten in production.

| Registration point | Carries | Symptom if missed |
|---|---|---|
| The service catalog used by `deploy.yml` | `name`, build context, container file, `chart_path`, `has_migrations`, change-detection `paths`, `skip_build` / `auto_deploy` flags | the aggregate deploy never sees the service — no build, no release, no message |
| The per-service map used by `deploy-service.yml` | same fields minus `paths` | `SERVICE=<name>` fails "unknown service", or deploys nothing |
| The flat ops list (`services_list`) | just the names | `status` / `logs` / `restart` / `rollback` / `undeploy` cannot address the service |
| `group_vars/<env>/all.yml` → `service_overrides.<name>` | per-env chart values: `migrations.enabled`, datastore TLS + CA, inter-service URLs, replicas/autoscaling, `LB` address or port allocation, timeouts | the release installs with **chart defaults**: migrations never run, the CA is not mounted, URLs point at nothing, the service is unreachable |
| The `SECRET_MANAGER` payload map + the expected-secrets assertion | which local env vars fill which secret entries, and the cluster Secret name the chart expects | pods start and crash-loop on a missing variable, or the sync object never materialises |
| The datastore list in the infrastructure module, if the service needs a new database | the database name | migrations fail — the database must exist before the first migration runs |

**Rule: one catalog, many consumers.** Keep the catalog in `vars/services.yml` and pull it into
every playbook with `vars_files`, so `deploy.yml`, `deploy-service.yml` and the ops playbooks
read the *same* list. Duplicating the catalog inline in two playbooks is exactly how the
"builds but never deploys" bug is produced.

Where duplication is unavoidable, add an **assertion task that fails when the sets disagree** —
catalog names vs. ops list vs. `service_overrides` keys vs. the chart directories on disk — and
run it in `common/validate`. A machine check is the only thing that survives a hurried Friday.

Catalog entry shape (illustrative, paths relative to the repo root):

```yaml
deploy_services:
  - name: <service>
    build_context: "{{ repo_root }}"                  # repo ROOT in a monorepo
    dockerfile: services/<service>/Dockerfile
    chart_path: services/<service>/infra/helm/<service>
    has_migrations: true
    paths:                                            # change detection (§8)
      - services/<service>
      - services/<service>/infra
    # skip_build: true      # chart-only unit (a second workload off an existing image)
    # auto_deploy: false    # never rolled by the aggregate deploy; explicit only
```

- A **chart-only unit** (a worker sharing another service's image, a proxy with no code) is a
  catalog entry with `skip_build: true` and its own `chart_path`. It still needs every other
  registration point.
- `auto_deploy: false` is for units a rollout must not touch unattended (a single-consumer
  long-polling bot, anything with a manual cutover). Say so in the entry with a comment.
- **`LB` address / port allocation is a shared namespace.** Read the current allocations out of
  the environment's group_vars before assigning; never pick from memory. A collision is silent —
  one of the two services simply stops being reachable.

Definition of done for a new service in the orchestrator:

- [ ] present in the shared catalog with correct build context, chart path and `has_migrations`
- [ ] change-detection `paths` cover the service directory **and** its chart
- [ ] in the ops list; `status` / `logs` / `restart` / `rollback` address it by name
- [ ] `service_overrides.<name>` exists for every environment it deploys to
- [ ] secret payload entries and the expected-secrets assertion updated
- [ ] `LB` address/port taken from the allocation table, not invented
- [ ] the cross-check assertion passes
- [ ] first deploy done, and the first-deploy traps in §11 anticipated

## 8. Change detection

- Each catalog entry declares the `paths` that make it dirty. A chart change must redeploy the
  service, so the chart path is listed too.
- `shared_paths` in group_vars are the paths that dirty **everything** — shared libraries,
  shared chart values, cross-cutting config. Keep this list minimal and comment each entry: the
  orchestrator's own directory and the infrastructure directory usually do **not** belong there,
  because changing a deploy script does not change any service's runtime.
- The base ref for the diff is a defined, documented ref. "Changed since my last commit" is not
  a specification.
- Optionally compare against the **tags actually running in the cluster**, not just the git
  diff: a repo that matches the base ref can still be ahead of a cluster running an older
  release. Without this, a re-deploy after a failed rollout is a no-op.
- When code changed but the image tag would be identical, still run `helm upgrade` so pods roll
  (`force_helm_upgrade_on_changes`). Otherwise a rebuild lands nowhere.
- `-e force_deploy_all=true` bypasses detection entirely. Keep it; incident recovery needs it.

## 9. Parallelism cap

`[!]` **Never run more than about 3 service builds or deploys concurrently.** Container image
builds are CPU- and I/O-heavy; past three, the build host (a laptop or a single runner) thrashes,
every step slows down together, and tasks start tripping their own timeouts — the "parallel"
deploy finishes later than the sequential one would have, and leaves a half-deployed environment
behind.

- 1 service → the single-service playbook. 2–3 → run it in parallel, one per service.
  4+ → the aggregate deploy target, which sequences for you.
- Express the cap in the playbook (`throttle`, a batch size, or a bounded async loop), not in a
  human's memory. Make the number a variable so a bigger build host can raise it.
- If async/parallel Helm is used, **poll every job's result and fail the play on any failure**.
  An async task whose result is never collected is a deploy that reports success while a release
  is broken. Fail fast on terminal pod states (`CrashLoopBackOff`, `ImagePullBackOff`,
  `CreateContainerConfigError`, `RunContainerError`) rather than waiting out the timeout.

## 10. Idempotence and honest task status

A deploy is **re-run, never resumed by hand**. Every playbook must be safe to run twice in a row.

- `helm upgrade --install`, `kubectl apply`, `create … --dry-run=client -o yaml | kubectl apply`
  — never `create` bare, never `delete` to "fix" state.
- Set `changed_when` and `failed_when` on every `command` / `shell` task. A task that reports
  *changed* on every run destroys the value of the output: nobody can see the one real change.
  A read-only check is `changed_when: false`.
- `check_mode` / `--check` should at minimum be non-destructive for the validate and plan phases.
- Retry only **transient** failures (cluster unreachable, TLS handshake timeout, connection
  reset, EOF) with a bounded count and delay. Never blanket-retry a task that can half-apply.
- `no_log: true` on any task that touches secret values, including the loop that parses an env
  file. A secret in a deploy log is a leaked secret.
- Markers and caches (`.last-applied`, build caches) are optimisations, never correctness. There
  must always be a documented flag to force the phase to run.
- Destructive verbs live in their own playbook, behind an explicit confirmation variable, and
  are never reachable from a convenience Make target.

## 11. Known failure modes

| Symptom | Cause | Fix |
|---|---|---|
| Service builds in CI/locally but is never deployed `[!]` | missed a registration point (§7) | add it everywhere; add the cross-check assertion |
| Brand-new release silently skipped on its **first** deploy `[!]` | `helm diff` reports "no changes" for a release that does not exist yet, and the skip-unchanged optimisation drops it | install it once explicitly, or run with `-e skip_unchanged_releases=false` |
| Every deploy now fails at the migration step `[!]` | a failed/timed-out migration left the version table marked **dirty** | force the version back to the last good one, fix the migration, re-run |
| Migration exceeds the Helm timeout | the release timeout also covers the pre-upgrade hook Job; backfills are slow | raise `helm_timeout` for that service in `service_overrides`, and keep backfills re-runnable |
| App crash-loops on the datastore CA, but the migration Job succeeded `[!]` | the app driver requires the CA file mounted; the migration tool is satisfied by requiring TLS alone | enable the TLS override + CA in `service_overrides` and mount it in the chart |
| Deploy landed in the wrong cluster `[!]` | a task relied on the current kube-context | pin `--context` / `--kube-context` from `kube_context` in every task |
| `SERVICE=<name>` "succeeds" but nothing happened | unknown name not validated against the catalog | fail loudly, listing known names |
| Deploy reports success, release is broken | async Helm tasks whose results were never polled | collect every async job; fail the play on any failure |
| Infra phase never runs after an infra change | stale `.last-applied` marker | force flag; update the marker only after a successful apply |

## 12. Never let the playbook be the only place a rule lives

`[!]` **If a human can run the same step by hand, the rule must exist outside the playbook too.**
Encoding the context flag, the migration force-recovery, the parallelism cap or the confirmation
gate *only* inside a role means that during an incident — when someone runs `helm` or `kubectl`
directly at 3am — the rule is simply absent. That is precisely when it matters most.

- Every rule with a manual equivalent appears in **two** places: enforced in the role, and written
  in the runbook / known-issues document that the on-call reads. If the `incident-response` skill
  is installed, follow it for where that lives; otherwise use the project's own runbook.
- Shell helpers (`scripts/k8s-*.sh`) and the playbooks must read the **same** variables
  (`KUBE_CONTEXT` / `kube_context`, namespace, image tag). Two sources of truth become two
  different clusters.
- Recovery procedures belong in prose with a copy-pasteable command, not only as a task nobody
  can find under pressure.
- Conversely, a rule that only lives in a document gets skipped. Anything mechanically checkable
  becomes an assertion in `common/validate`.

## 13. Honesty about maturity

- In a freshly bootstrapped repo the deploy playbooks and roles are **placeholders**. Do not
  claim resources are provisioned or that a service is deployed until the roles, the `REGISTRY`
  and `SECRET_MANAGER` wiring and the charts exist and have been run at least once against a
  real environment.
- A playbook exiting 0 is not evidence of a deploy when its tasks are stubs or were all skipped.
  Read the recap: `ok=… changed=0 skipped=everything` is a no-op, not a success.
- Mark steps authored but never executed against a live environment —
  `Verify: never run against a real cluster` — and keep the marker until someone runs it.

## Vendor delta

The `skills/cloud/<vendor>` skill must supply, per capability:

- `MANAGED_K8S` — how the kubeconfig is fetched by a role, the context naming convention, and any
  exec-credential quirk that needs a token pre-fetched and exported to child tasks.
- `REGISTRY` — the image path format and how a build host authenticates non-interactively.
- `SECRET_MANAGER` — the payload API the sync role calls, the sync operator and its refresh
  interval, the credential file it needs, and the naming rules for entries.
- `MANAGED_PG` — TLS requirements, the CA file the application driver needs but the migration
  tool does not, and any connection-limit behaviour the budget assertion must encode.
- `TFSTATE_BACKEND` — the backend configuration and the environment variables the `terraform`
  role must export.
- `LB` — how a service is exposed and how per-environment addresses/ports are allocated.
- `IAM` — the CLI, the profile/account/folder identifiers to pin in group_vars, the service
  account credential file, and how a short-lived token is obtained.

## Project delta

The consuming repo supplies:

- The Ansible root path, and the environment names with one inventory directory each.
- `kube_context` and `k8s_namespace` per environment, and the cluster/registry names they derive from.
- The service catalog: names, build contexts, container file paths, chart paths, which services
  have migrations, which are chart-only or excluded from unattended rollout.
- Change-detection `paths` per service, the `shared_paths` list, and the base ref for the diff.
- `service_overrides` per environment, including the `LB` address/port allocation table.
- The secret payload map and the cluster Secret names the charts expect.
- Which pre-deploy gate (if any) runs, and the escape-hatch flag name.
- The parallelism cap, if 3 does not fit the build host.
- Which playbooks exist beyond the set in §4, and which are destructive.
