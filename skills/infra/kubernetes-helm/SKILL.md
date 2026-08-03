---
name: kubernetes-helm
description: Helm chart layout and Kubernetes workload conventions for services deployed to a managed cluster — one chart per service, the template inventory, values conventions, the plain-config vs secret-reference split, liveness/readiness probes, resource requests and limits, HPA and when not to use it, singleton/long-polling workloads, migrations as a pre-install/pre-upgrade hook Job, and pinning the kube-context on every invocation. Use when the user says "add a Helm chart", "write the deployment template", "why is the pod CrashLoopBackOff", "the release did not install", "set up autoscaling", "run migrations on deploy", "helm upgrade", "deploy the service to Kubernetes", or when reviewing a chart before its first deploy. Vendor-neutral — routing is the LB capability, image pull is REGISTRY, secret injection is SECRET_MANAGER, the database is MANAGED_PG.
license: Apache-2.0
metadata:
  source: glotyuids/engineering-skills
  version: 0.1.0
---

# Kubernetes and Helm conventions

How a service is packaged for and behaves on a MANAGED_K8S cluster. Written against
capabilities, not a provider: substitute your cloud's services through the vendor skill.

Items marked `[!]` caused a real production incident when missed. They are not style
preferences.

## Scope

This skill defines only: **chart layout, the template inventory, values conventions, the
config-vs-secret split, workload shape (probes, resources, replicas, update strategy), the
migration hook, and how `helm`/`kubectl` are invoked.**

It does not define: building and pushing images or the deploy orchestration around Helm
(`cicd-build-deploy`), cluster and database provisioning (`terraform-conventions`), the
secret pipeline that materialises the Secret (`secrets-management`), or the playbook wiring
that calls Helm (`ansible-deploy`). SQL migration authoring belongs to the database pack —
if a `database-migrations` skill is installed, follow it; otherwise follow the project's own
conventions.

## 1. One chart per service, and where charts live

| Chart kind | Location | Owned by |
|---|---|---|
| Service chart | `services/<name>/infra/helm/<name>/` | the service; versioned and reviewed with its code |
| Platform / shared chart | `infra/helm/<component>/` | the repo (cluster-wide components: routing controller, secrets operator, identity server) |
| Chart template to clone | `infra/helm/service-template/` or a designated canonical reference service | the repo |

- One deployable service, one chart, one release. Do not fold two services into one chart
  "because they deploy together"; separate releases roll back separately.
- `Chart.yaml: name` == the chart directory name == the service directory name. The release
  name is derived from it, so drift here breaks every `_helpers.tpl` reference.
- **Never write a chart from scratch.** Copy the template. Adding a service should be
  "copy the template, edit `values.yaml`". If you find yourself adding a *template file*
  that the template does not have, first ask whether it belongs in the template.
- Value files: `values.yaml` holds defaults that are true everywhere; `values-<env>.yaml`
  holds only the per-environment delta. Many repos run a single environment — keep the
  chart env-parameterised anyway, so adding one later is non-breaking.
- Single namespace per project unless there is a stated reason otherwise.

## 2. Template inventory

| File | Present when | Must contain |
|---|---|---|
| `_helpers.tpl` | always | `fullname`, `labels`, `selectorLabels`, `serviceAccountName` |
| `deployment.yaml` | always | probes, resources, `envFrom`, security context, rollout annotation |
| `service.yaml` | always | named port mapping to the container's named port |
| `configmap.yaml` | always | every non-secret env var the service reads |
| `serviceaccount.yaml` | always | the identity pods run as; annotations if pods call cloud APIs |
| `hpa.yaml` | workload is horizontally scalable | see §6 — omit or disable it for singletons |
| secret-reference CR (e.g. `externalsecret.yaml`) | service consumes secrets | maps SECRET_MANAGER entries to a k8s Secret; the CR kind is a Vendor delta |
| `migration-job.yaml` | service owns schema migrations | the pre-install/pre-upgrade hook, §7 |
| CA-certificate ConfigMap + volume | MANAGED_PG requires a CA file on disk | §7, the `[!]` driver asymmetry |
| ingress / route object | the service is externally reachable **and** the chart owns the routing object | LB capability; see Vendor delta |

## 3. values.yaml conventions

| Key | Convention |
|---|---|
| `namespace.name` | the project's single namespace; never hard-coded in templates |
| `replicaCount` | 2 for stateless services; **1** for singletons (§6) |
| `image.repository` / `image.tag` | REGISTRY-qualified repository; an immutable tag or digest — never `latest` |
| `imagePullSecrets` | required for a private REGISTRY; missing it is `ImagePullBackOff` |
| `service.type` | `ClusterIP` when routing terminates inside the cluster; `NodePort` when the LB targets node ports. This is an LB decision, not a service decision |
| `service.port` / `service.targetPort` | 80 → the app's container port (commonly 8080), referenced by *name* (`http`) |
| `service.nodePort` | only for `NodePort`; allocate the next free port from the project's allocation table and record it there |
| `podSecurityContext` | `runAsNonRoot: true`, `runAsUser: 1000` — must match the non-root user baked into the image |
| `resources` | see §5 |
| `autoscaling.*` | see §6 |
| `probes.*` | see §4 |
| `config.*` | plain, non-secret env values → ConfigMap (§4) |
| `migrations.enabled` | gates the hook Job, so the first install can be run without it (§7) |
| Prometheus scrape annotations | on the pod, pointing at the app port and metrics path |

Nothing secret ever appears in a values file, in any environment. See §4.

## 4. Plain config vs secret reference

Two mechanisms, one rule each. Do not mix them.

**Plain config → ConfigMap.** Map *every* non-sensitive env var the service's configuration
loader reads into `configmap.yaml`, and consume it with `envFrom: configMapRef`. Not a subset:
a var read at startup but absent from the ConfigMap is a boot failure that only appears in
production. Inter-service URLs default to in-cluster DNS names (`http://<service>:80`).

**Secrets → reference only.** A secret value is never in `values.yaml`, never in the
ConfigMap, never in `stringData` in a template. The chart declares the *reference*; the
Secret itself is materialised by SECRET_MANAGER (see `secrets-management`).

```yaml
# per-service secret, materialised by the secret pipeline
env:
  - name: DATABASE_DSN
    valueFrom:
      secretKeyRef:
        name: {{ include "<service>.fullname" . }}-secrets
        key: database-dsn
  # cluster-wide shared secret, referenced by a fixed name
  - name: INTERNAL_API_KEY
    valueFrom:
      secretKeyRef:
        name: internal-api-key
        key: api-key
        optional: false     # fail loudly; never silently start without it
```

`envFrom: secretRef` is equivalent and shorter when the whole Secret is env vars; per-key
`secretKeyRef` is clearer when only some keys are wanted. Both are fine; be consistent
within a chart.

- `[!]` **The Secret name the chart expects must equal the name the secret pipeline
  creates** (commonly `<release>-<service>` or `<service>-secrets` — pick one convention
  repo-wide). A mismatch does not fail the Helm release: the pod sits in
  `CreateContainerConfigError` and the deploy looks green.
- Always set `optional: false` on secrets the service cannot run without.
- Rotating a secret does not restart pods by itself. A rolling restart is part of rotation.

## 5. Probes, resources and rollout hygiene

**Health endpoints.** Two, both unauthenticated, both cheap:

| Probe | Endpoint | Semantics |
|---|---|---|
| liveness | `/healthz` | the process is alive. Must **not** check dependencies — a database blip would otherwise restart every pod at once and turn a degradation into an outage |
| readiness | `/readyz` | dependencies are usable (DB pool, cache, required downstream). Failing readiness removes the pod from the Service; the process keeps running |
| startup (optional) | `/healthz` | only when boot is genuinely slow; prevents liveness from killing a pod mid-start |

Probe the *named* container port, not a hard-coded number.

**Resources.** Requests are what the scheduler reserves; limits are the ceiling (memory
limit exceeded = OOMKill, CPU limit = throttling, not a kill). A workable starting point,
used across the source projects:

```yaml
resources:
  requests: { cpu: 50m,  memory: 128Mi }
  limits:   { cpu: 500m, memory: 512Mi }
```

Tune from observed usage. Requests must always be set — the HPA computes utilisation
against them, and without requests it reports `<unknown>` and never scales.

**Rollout hygiene.**

- `checksum/config` pod annotation over the rendered ConfigMap, so a config-only change
  actually rolls the pods instead of silently doing nothing.
- `terminationGracePeriodSeconds` >= the app's graceful-shutdown timeout (30s is the
  common value), or in-flight requests are cut at shutdown.
- Prometheus scrape annotations on the app port.
- `[!]` The image architecture must match the node architecture. An image built natively on
  a developer machine with a different CPU architecture pulls fine and then crashes with
  `exec format error`. Pin the build platform in the pipeline (`cicd-build-deploy`).

## 6. Replicas, HPA, and when not to autoscale

Default for a stateless HTTP service:

```yaml
replicaCount: 2
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80
```

Once an HPA owns a Deployment, the chart must stop templating `spec.replicas` on upgrades —
otherwise each `helm upgrade` resets the replica count and the HPA has to climb back.

**Do not autoscale these:**

| Workload | Why |
|---|---|
| Long-polling / single-consumer clients (chat-bot update pollers, queue consumers without partitioning) | the upstream allows exactly one consumer |
| Leader-less schedulers, cron drivers, reconcilers | two instances do the work twice |
| Single-writer backfill or migration workers | concurrent writers corrupt or duplicate |
| Anything holding an exclusive external lock or session | the second instance blocks or steals it |

`[!]` **A singleton workload needs all three settings, not one of them:**

```yaml
replicaCount: 1
strategy:
  type: Recreate          # NOT RollingUpdate
autoscaling:
  enabled: false
```

With the default `RollingUpdate`, the new pod starts **before** the old one terminates, so
for the length of every deploy there are two consumers on the same stream: duplicated
deliveries, dropped updates, or a hard error from the upstream. `Recreate` accepts a few
seconds of downtime instead. This was observed in production on a long-polling bot; the
`Recreate` strategy is what fixed it.

## 7. Migrations as a pre-install/pre-upgrade hook

Schema migrations run as a Helm hook Job so the schema is ready before the new pods start:

```yaml
annotations:
  "helm.sh/hook": pre-install,pre-upgrade
  "helm.sh/hook-weight": "-5"
  "helm.sh/hook-delete-policy": before-hook-creation
```

- The Job uses the **same image as the service**, so the migration files and the tool that
  applies them ship together and can never be a version apart.
- Gate the whole template on `migrations.enabled` (see the two-phase install below).
- Prefer bundling the migration tool into the image over installing it at container start.
  Several of the source repos still install it at runtime via the base image's package
  manager, which works but costs cluster egress at deploy time and forces the Job to run as
  root (`runAsUser: 0`). Bundling removes both.
- `[!]` **The hook is inside the release timeout.** The default (5m) covers the hook *and*
  the rollout; a migration with a backfill exceeds it and fails the whole release. Raise
  `--timeout` deliberately for such releases.
- `[!]` **A failed migration leaves the version table dirty.** With the common
  version-table-plus-dirty-flag tools, a run that dies mid-migration marks the version
  dirty and every later run refuses to start. Recovery is to force the tracker back to the
  last clean version with the same tool, from a one-off pod with the same DSN, then re-run.
- `[!]` **Two-phase first install.** On a *fresh* install the hook runs before
  SECRET_MANAGER has materialised the Secret — the chart's secret-reference CR is created by
  the same release, and the operator's sync is asynchronous. The Job starts with no
  `DATABASE_DSN` and times out. Deploy in two phases: (1) install with
  `migrations.enabled=false`, which creates the CR and lets the operator sync the Secret;
  (2) `helm upgrade` with `migrations.enabled=true` — no rebuild needed. Script this; it is
  needed for every new service, not once.
- `[!]` **Driver asymmetry on MANAGED_PG TLS.** When the DSN names a CA file path
  (`...sslrootcert=/etc/ssl/<vendor>/CA.pem`), that file must be mounted into the **app**
  pod (CA ConfigMap + volume, gated on `database.ssl.enabled`) or the app crash-loops with
  `unable to read CA file`. The migration Job commonly uses a different driver that is
  satisfied by `sslmode=require` alone and therefore does **not** need the mount — which is
  exactly why this is missed: migrations succeed and only the service crashes. If the app
  crashes this way after a deploy, the release was installed without the CA values;
  upgrade with them enabled.

## 8. Invoking Helm and kubectl

`[!]` **Every `helm` and `kubectl` invocation pins the cluster context explicitly** — in
scripts, in playbooks, in Makefile targets and in commands typed by hand:

```bash
helm --kube-context "$KUBE_CONTEXT" -n "$NAMESPACE" upgrade --install <release> <chart-path>
kubectl --context "$KUBE_CONTEXT" -n "$NAMESPACE" get pods
```

Never rely on the kubeconfig's current context. A shared kubeconfig holds contexts for
several clusters, and the current one is whatever the last command left behind — that is how
a deploy lands in the wrong project's cluster. The value comes from one place
(`KUBE_CONTEXT` for Makefile and scripts, `kube_context` in the playbook group vars); it is
never re-derived per call site. The context naming convention is a MANAGED_K8S Vendor delta —
see the `skills/cloud/<vendor>` skill for the format your provider's credential command emits.

`[!]` **A deploy tool that skips unchanged releases can silently skip a brand-new install.**
Wrappers that run a diff before upgrading (the common `helm diff` pre-check) can report "no
changes" for a release that *does not exist yet* and skip it. The playbook reports success,
nothing is deployed. Therefore:

- After the first deploy of any service, **verify the release exists**:
  `helm --kube-context "$KUBE_CONTEXT" -n "$NAMESPACE" list` must show it.
- For a first install, either run `helm upgrade --install` directly once, or disable the
  skip (e.g. `-e skip_unchanged_releases=false`).
- Never report a service as deployed on the strength of a green pipeline alone. If the
  charts in the repo are still unwired placeholders, say so — "deploy is not wired yet" is a
  valid answer, and a much cheaper one than a claimed deploy that never happened.

Other invocation rules: `upgrade --install` is the only mutating verb used routinely; always
pass `--namespace`; never `helm delete` a release to "fix" a bad upgrade (that drops the
Secrets and PVCs the release owns) — roll back instead.

## 9. Failure modes

| Symptom | Likely cause | Fix |
|---|---|---|
| `CreateContainerConfigError` | expected Secret name != the name SECRET_MANAGER created, or it has not synced yet | align names (§4); check the secret-reference CR's status |
| `CrashLoopBackOff`, `unable to read CA file` | CA ConfigMap/volume not mounted, release installed without the SSL values | upgrade with SSL values enabled (§7) |
| Release absent after a "successful" deploy | skip-unchanged-releases skipped a first install | §8 |
| Migration hook times out on a fresh install | Secret not synced yet | two-phase install (§7) |
| Migrations refuse to run, version marked dirty | previous run died mid-migration | force the tracker to the last clean version, re-run (§7) |
| Duplicate or racing work right after each deploy | `RollingUpdate` on a singleton | `replicaCount: 1` + `Recreate` + autoscaling off (§6) |
| `ImagePullBackOff` | `imagePullSecrets` missing, or the pull identity lacks REGISTRY read (IAM) | §3, and the vendor skill |
| `exec format error` | image built for a different CPU architecture than the nodes | pin the build platform (§5) |
| HPA target shows `<unknown>` | metrics source absent, or `resources.requests` unset | set requests (§5) |
| Config change deployed but pods unchanged | no `checksum/config` annotation | add it (§5) |

## 10. Definition of done for a chart

- [ ] Chart cloned from the template; `Chart.yaml` name == directory == service name.
- [ ] Every env var the service reads is either in the ConfigMap or a secret reference — no
      third source, no defaults hidden in code.
- [ ] No secret value in any values file or template.
- [ ] `/healthz` and `/readyz` wired; liveness checks no dependencies.
- [ ] Requests and limits set; `checksum/config` annotation present.
- [ ] Singleton services: `replicaCount: 1` + `Recreate` + autoscaling disabled.
- [ ] Migration hook gated on `migrations.enabled`; two-phase first install rehearsed.
- [ ] Every command in scripts and playbooks pins the kube-context.
- [ ] After first deploy: release listed by `helm list`, pods `Running` (not
      `CrashLoopBackOff`), startup logs clean, `/healthz` and `/readyz` answer, the Service
      resolves by in-cluster DNS from another pod.

## Vendor delta

The `skills/cloud/<vendor>` skill must supply, per capability:

- **MANAGED_K8S** — the kube-context naming convention and how the kubeconfig is obtained;
  node CPU architecture; any cluster-scoped prerequisites (metrics source for the HPA).
- **REGISTRY** — the image reference format, how `imagePullSecrets` are created, and the
  IAM binding that lets nodes pull.
- **SECRET_MANAGER** — the CR kind that materialises a k8s Secret, the Secret naming rule
  the chart must match, sync latency, and refresh/rotation behaviour.
- **MANAGED_PG** — whether the DSN requires a CA file on disk and where that CA comes from,
  the per-driver TLS differences, and the connection/pooler port.
- **LB** — how external traffic reaches a Service (node ports, load balancer service, or an
  ingress class), and whether the routing object is owned by the chart or provisioned
  outside it.
- **IAM** — the service-account or workload-identity binding for pods that call cloud APIs.

## Project delta

The consuming repo supplies:

- Chart location convention and the template or reference chart to clone from.
- Namespace, release naming, and the kube-context value plus the single place it is defined.
- Service port, target port, and the NodePort allocation table if node ports are used.
- Health endpoint paths, if not `/healthz` and `/readyz`.
- Image repository and tag scheme.
- Secret key names and the Secret naming convention the templates expect.
- Which services are singletons (long-polling consumers, schedulers, single writers).
- Resource baselines and HPA bounds where they differ from §5–§6.
- The list of environment value files.
