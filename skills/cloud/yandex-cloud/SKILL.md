---
name: yandex-cloud
description: Resolves vendor-neutral infrastructure capabilities (MANAGED_K8S, REGISTRY, SECRET_MANAGER, MANAGED_PG, CACHE, TFSTATE_BACKEND, LB, IAM) to concrete Yandex Cloud services, with the production traps each one carries. Use when deploying to or operating on Yandex Cloud, or when a generic infra skill names a capability and you need the real service, Terraform module, CLI command, identifier shape or DSN behind it. Trigger phrases - "Yandex Cloud", "yc CLI", "Managed Service for Kubernetes", "Container Registry", "cr.yandex", "Lockbox", "External Secrets Operator", "Managed PostgreSQL", "Valkey", "Object Storage tfstate backend", "ALB / NodePort", "IAM token", "service account key", "folder id", "cluster context", "unable to read CA file", "sslrootcert".
license: Apache-2.0
metadata:
  source: glotyuids/engineering-skills
  version: 0.1.0
---

# Yandex Cloud — the vendor layer

This skill defines **only** the mapping from capability to concrete Yandex Cloud service,
plus the traps that mapping carries. It does not define the build/deploy procedure, the
Terraform layout, the Helm chart shape or the secrets pipeline — those live in the
vendor-neutral infra skills. If the `cicd-build-deploy`, `terraform-conventions`,
`ansible-deploy`, `kubernetes-helm` or `secrets-management` skills are installed, follow
them for the *pattern* and come here for the *service*; otherwise follow the project's own
conventions and use this file purely as a lookup.

**How to use it.** A generic skill names a capability in `SMALL_CAPS`. Find the row in the
table, then read that capability's subsection **before** writing Terraform, Helm values or
Ansible vars, and before running any `yc` / `kubectl` / `terraform` command. Items marked
`[!]` caused a real production incident when missed.

Vendor names belong in the vendor layer (`skills/cloud/<vendor>/`), which is where this file
lives. The generic infra skills must keep naming capabilities, never services.

## Capability → service

| Capability | Yandex Cloud service | Terraform module (conventional) | Identifier / endpoint shape |
|---|---|---|---|
| `MANAGED_K8S` | Managed Service for Kubernetes | `kubernetes` (cluster + node groups) | kubeconfig context `yc-<project>-cluster` |
| `REGISTRY` | Container Registry | `registry` | `cr.yandex/<registry-id>/<service>:<tag>` |
| `SECRET_MANAGER` | Lockbox + External Secrets Operator in-cluster | `lockbox` (one vault per service) | vault `<project>/<service>` |
| `MANAGED_PG` | Managed Service for PostgreSQL | `postgresql` (one logical DB per service) | `<cluster-id>.rw.mdb.yandexcloud.net:6432` |
| `CACHE` | Managed Service for Valkey (Redis-compatible) | `redis` | managed endpoint, TLS per cluster setting |
| `TFSTATE_BACKEND` | Object Storage (S3-compatible) | bootstrapped, not managed by the stack it stores | bucket `<project>-tfstate`, `AWS_*` env vars |
| `LB` | Application Load Balancer (ALB) | `alb` (optional) | ALB → K8s `Service type: NodePort` |
| `IAM` | IAM: service accounts, roles, authorized keys, IAM tokens | `iam` | `yc iam create-token` (short-lived) |
| *(beyond the core set)* `OBJECT_STORAGE` | Object Storage buckets | `storage` | server-side encrypted buckets |
| *(beyond the core set)* `LOG_SINK` | Cloud Logging | — | agent-shipped (e.g. Fluent Bit) from stdout |
| *(beyond the core set)* `NETWORK` | VPC + subnets | `network` | zonal subnets per availability zone |

---

## MANAGED_K8S — Managed Service for Kubernetes

Terraform provisions the cluster and its node groups. **Never create a cluster by hand** —
the only hand-made things are the account, the bootstrap service account and the state
bucket (see *Bootstrap*).

- `[!]` **Pin the kubeconfig context on every call.** `yc managed-kubernetes cluster
  get-credentials` writes a context named `yc-<cluster-name>` into the *shared* kubeconfig,
  so a developer with several Yandex Cloud projects has several such contexts. Every
  `kubectl` and `helm` invocation — in Ansible, in `scripts/*.sh` helpers, and typed by
  hand — must pass it explicitly:

  ```bash
  kubectl --context yc-<project>-cluster -n <namespace> get pods
  helm   --kube-context yc-<project>-cluster upgrade --install <release> <chart>
  ```

  The value flows from one place (`KUBE_CONTEXT` in the Makefile/scripts, `kube_context` in
  Ansible `group_vars/all.yml`). **Never rely on the current context** — that is how a
  deploy lands in another project's cluster.
- **Zonal vs regional master.** A regional master can fail to provision on a freshly created
  cloud (quota/propagation), and a zonal master is the working fallback. Record which one
  the environment actually has; they are not interchangeable for availability claims.
- **Node egress.** Either give nodes public IPs (`nat = true` on the node group) or place a
  NAT gateway on the route table. Nodes with neither cannot pull from public registries,
  which surfaces much later as an unexplained `ImagePullBackOff` (see `REGISTRY`).
- **Third-party API geo-blocking.** Several SaaS APIs geo-block the cloud's egress ranges.
  If a service must reach one, route its outbound traffic through an in-cluster egress
  proxy pinned to a permitted region, and treat that proxy as a first-class deployed
  component with its own chart. Discovered at bring-up, not in the docs.
- Single namespace per project is the default; probes `/healthz` (liveness) and `/readyz`
  (readiness); `imagePullSecrets` referencing the registry pull service account.

## REGISTRY — Container Registry

- Image reference: `cr.yandex/<registry-id>/<service>:<tag>`. The registry id comes from a
  Terraform output; it is project configuration, never hard-coded in a chart.
- `[!]` **Build for `linux/amd64` explicitly.** Managed node groups are amd64. A Mac-native
  arm64 build pushes and pulls fine and then fails at runtime with `exec format error`.
  Pass `--platform linux/amd64` (or set it in the buildx invocation) for every image,
  including sidecars and mirrored third-party images.
- `[!]` **Mirror third-party images that nodes cannot reach.** Cluster nodes may have no
  route to public registries such as `ghcr.io`. The External Secrets Operator controller
  image is the case that bit: the Helm install succeeds, the controller pod never starts,
  and the whole secrets pipeline silently does nothing. Mirror the image into the project
  registry and point the operator's Helm values at the mirror.
- **Lifecycle policy is not managed by default; images accumulate.** A `registry`
  Terraform module typically exposes `lifecycle_policy_enabled` and the environment sets it
  to `false` with a comment that the policy is "managed outside Terraform".
  *Verify:* in the source project, no lifecycle policy was confirmed to exist — every
  `docker push` from every deploy accumulated tags with nothing pruning them. Either turn
  the flag on and manage the policy in Terraform, or confirm a console-configured policy
  exists and write down where.
- *Not an issue:* a project may legitimately have **two** registries (for example a
  Kubernetes-spine registry and a legacy serverless one) with near-identical ids. That is a
  design decision, not drift — document which id belongs to which deploy path so nobody
  "fixes" it.

## SECRET_MANAGER — Lockbox + External Secrets Operator

Designed pipeline, three tiers:

```text
.secrets[.<env>]  (git-ignored)  +  .secrets.example  (committed contract)
      ↓  Ansible role / sync script
Lockbox vault  <project>/<service>
      ↓  External Secrets Operator, ClusterSecretStore "yandex-lockbox" (external-secrets.io/v1)
Kubernetes Secret  <release>-<service>   (or <service>-secrets — pick one and be consistent)
      ↓  secretKeyRef / envFrom secretRef
pod env
```

- `.secrets.example` is the committed **contract**: every key documented, no values. The
  usual shape is a shared block (internal service-to-service API key, JWT signing secret),
  a provider-keys block, and one DSN per service. Generate values with
  `openssl rand -base64 32` (or `64` for signing keys), never by hand.
- `[!]` **The ExternalSecret's target secret name must match what the Helm template
  expects.** The chart reads `<release>-<service>` (or `<service>-secrets`); if the
  ExternalSecret writes a different name the pod starts with no env and fails in a way that
  looks like a config bug. Keep the naming in exactly one helper template.
- `[!]` **Update the expected-secrets list when a service is added.** The sync role keeps an
  `eso_expected_secrets` (or equivalent) list plus a per-service DSN computation step;
  adding a service means adding *both* — the vault entry and the expectation — or the sync
  silently skips the new service.
- `[!]` **ESO fails if an ExternalSecret references a remote key absent from Lockbox.**
  Empty values in `.secrets.<env>` are dropped by the `yc` CLI when the vault is written, so
  a key you "set" to an empty string does not exist remotely, and the whole ExternalSecret
  goes to `SecretSyncedError`. Either give the key a real value or remove it from the
  ExternalSecret.
- `[!]` **Fresh install ordering: migrations run before the secret exists.** DB migrations
  run as a Helm `pre-install,pre-upgrade` hook Job, but on a *first* install the ESO-synced
  secret does not exist yet, so the Job has no `DATABASE_DSN` and times out. Deploy in two
  phases: (1) install with migrations disabled so the `ExternalSecret` is created and ESO
  syncs the Secret; (2) `helm upgrade` with migrations enabled (no rebuild needed).
- **Rotation:** update Lockbox → wait for the ESO refresh interval (~1h) or force a refresh
  → rolling restart of the consumers.

**Honest status (from the source projects).** In one of them the Lockbox + ESO path is
**authored but inert**: the `ClusterSecretStore`/`ExternalSecret` manifests and the sync
script exist, and the deploy playbook accepts flags to install ESO and sync Lockbox, but
ESO is not running on the live cluster because its controller image is on a registry the
nodes cannot reach. What actually runs today is a direct-apply script that writes plain
Kubernetes `Secret` objects from Terraform outputs and generated values, bypassing Lockbox
and ESO entirely. That is a networking/registry-mirroring gap, not a code bug. Resolution
path: mirror the controller image into the project registry, point the operator's Helm
install at the mirror, then switch day-to-day rotation from the direct script back to the
Lockbox sync. Do not describe the Lockbox path as live until that is done.

## MANAGED_PG — Managed Service for PostgreSQL

- One logical database per service inside one managed cluster. Adding a service means adding
  its database name to the `databases` list in the environment's Terraform composition and
  `[!]` **applying Terraform before the first migration runs** — the migration Job cannot
  create its own database.
- Connect through the **connection pooler on port 6432**, not the direct port.
  DSN shape (host from `terraform output -raw postgres_host`, credentials from tfvars):

  ```text
  postgres://<user>:<password>@<cluster-id>.rw.mdb.yandexcloud.net:6432/<db>?sslmode=require
  ```

- `[!]` **The SSL asymmetry between the app and the migration tool.** This is the single most
  confusing failure in this stack:
  - If the DSN carries `sslrootcert=/etc/ssl/yandex/CA.pem`, the **application** driver
    (`pgx`) opens that file and crashes on startup with `unable to read CA file` unless the
    managed cluster's CA certificate is actually mounted into the pod (a `configmap-ssl`
    template gated on `database.ssl.enabled`, plus the volume and volumeMount in the
    Deployment).
  - The **migration** Job does not mount the CA and does not need to: `lib/pq` (used by
    `golang-migrate`) is satisfied by `sslmode=require` alone.
  - Net effect: **the migration Job succeeds and the app CrashLoopBackOffs**, which reads
    like an application bug and is not. If a service crashes with `unable to read CA file`,
    the Helm release was installed without `database.ssl.enabled=true` and the CA — upgrade
    with SSL enabled rather than editing the DSN.
  - The CA content itself is environment configuration (an Ansible var such as
    `<vendor>_ca_cert` in `group_vars`), not a secret, but the DSN that references it *is* a
    secret and lives in `SECRET_MANAGER`.
- **Hardening ladder:** `sslmode=require` encrypts and needs no mounted CA — fine to start
  with. `verify-full` + a mounted CA is the hardened target; move both the app *and* the
  migration Job together when you take that step.
- `[!]` **`CREATE EXTENSION` is blocked for the application user.** The managed service does
  not let the app user install extensions (`pgcrypto` is the one that bites), so a migration
  that starts with `CREATE EXTENSION IF NOT EXISTS pgcrypto` fails on a fresh database.
  Use built-ins instead (`gen_random_uuid()` is available without `pgcrypto` on modern
  PostgreSQL), or request the extension through the cluster's managed extension list.
  `pgvector` is available that way when vector retrieval is needed.
- Set `deletion_protection = true` on production clusters, and never run a destructive
  Terraform plan against them without explicit human confirmation.

## CACHE — Managed Service for Valkey (Redis-compatible)

- Valkey is the Redis-compatible managed offering. **Pin a supported major version** — 7.2
  was deprecated and clusters must be created on 8.0 or later; a Terraform config pinning a
  deprecated version fails at create time, not at plan time.
- Typical uses: task queues, session/FSM state, step-result caches. A service whose entire
  state is in the cache has **no** `MANAGED_PG` database and therefore no migration Job —
  do not add one "for symmetry".

## TFSTATE_BACKEND — Object Storage (S3-compatible)

- Remote Terraform state lives in an Object Storage bucket accessed through the
  **S3-compatible** API. It is therefore configured with **`AWS_*`-named environment
  variables even though this is not AWS** — the names come from the S3 protocol client, not
  from the provider. Expect to explain this to every newcomer.
- The state bucket and its access keys are **bootstrapped outside** the stack they store —
  a small bootstrap script creates the bucket and a service account with static access keys
  and prints them once.
- Environment file (git-ignored; commit only a `.example` twin):

  ```bash
  # Yandex Cloud IAM token — authenticates the provider. Short-lived; regenerate on expiry.
  export YC_TOKEN="$(yc iam create-token)"
  # Static access keys for the tfstate bucket, from the bootstrap step.
  export AWS_ACCESS_KEY_ID="<tfstate-sa-access-key>"
  export AWS_SECRET_ACCESS_KEY="<tfstate-sa-secret-key>"
  ```

  Source it (`source .terraform.env`) before any `terraform` command.
- **Migrating an existing local state into the bucket** is a one-time, high-risk operation:

  ```bash
  terraform init -migrate-state
  terraform plan    # MUST print "No changes." before anything else is run
  ```

  If the plan is not empty, stop and reconcile — do not proceed to any other change,
  including `moved {}` block refactors.
  *Verify:* in one source project the remote backend is declared but the live state was
  still local on the operator's machine — the migration is authored, not executed. Check
  which is true before assuming the state is shared.

## LB — Application Load Balancer

- The ALB routes to Kubernetes `Service`s of `type: NodePort` (not `LoadBalancer` per
  service). Each service therefore owns a **node port allocated by hand**.
- Keep the allocation table in one place (the environment's `group_vars`) and check it
  before picking a port; two services on the same nodePort is a deploy-time failure that
  looks like a chart bug. Example shape of the table:

  | Port | Service |
  |---|---|
  | 30080 | `<frontend>` |
  | 30082 | `<service-a>` |
  | 30086 | `<service-b>` |

- A service that only does outbound work (long-polling a third-party API, consuming a
  queue) needs **no ALB route and no ingress at all** — do not allocate one. Such a service
  also wants `replicaCount: 1` and `strategy.type: Recreate` so two consumers never race.

## IAM — service accounts, keys and tokens

- **Prefer short-lived IAM tokens over static keys for the Terraform provider.**
  `export YC_TOKEN="$(yc iam create-token)"` mints one the cloud owner can produce directly;
  it expires, so a leak has a blast radius measured in hours. Reserve long-lived authorized
  key files (`key.json`) for unattended automation that cannot run `yc`, and never commit
  either form.
- Static access keys exist for exactly one reason here: the S3-compatible state backend
  (`TFSTATE_BACKEND`), which cannot consume an IAM token.
- Give each workload its **own** service account with least-privilege role bindings, managed
  in the `iam` Terraform module: cluster service account, node group service account,
  registry puller, Lockbox payload viewer for ESO, state-bucket writer. Do not reuse the
  bootstrap owner account for workloads.

---

## Bootstrap / prerequisites checklist

Terraform provisions the cluster, PostgreSQL, Valkey, registry, buckets, Lockbox vaults and
IAM. **None of the following is needed to write IaC, build images or run tests locally** —
only to `terraform apply` and deploy. The human operator supplies:

- [ ] A Yandex Cloud account with **billing enabled** (a trial/unbilled cloud fails at
      resource creation, sometimes only for regional masters).
- [ ] The **cloud id** and the **folder id** for the environment (`yc config list`,
      `yc resource-manager folder list`), recorded in the environment's tfvars.
- [ ] A bootstrap **service account** with the roles needed to create everything, and either
      the ability to run `yc iam create-token` or an authorized **key file** for unattended
      runs.
- [ ] An **Object Storage bucket for tfstate** plus its static access keys, created by the
      bootstrap script before the first `terraform init`.
- [ ] `.terraform.env` filled from `.terraform.env.example` and sourced (`YC_TOKEN`,
      `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`).
- [ ] `.secrets.<env>` filled from `.secrets.example`, with **no empty values** (see the ESO
      trap above).
- [ ] Cluster credentials fetched **and the context name recorded** as the single
      `KUBE_CONTEXT` / `kube_context` value: `yc managed-kubernetes cluster get-credentials
      <cluster> --external` writes `yc-<project>-cluster`.
- [ ] Confirmation, in writing, from the human before any destructive Terraform apply, any
      image push, or any other change to a live cloud.

## Naming conventions worth fixing early

| Thing | Shape |
|---|---|
| Core infra resources | `<project-prefix>-*` (short, stable, lowercase) |
| Lockbox vault | `<project>/<service>` |
| Kubeconfig context | `yc-<project>-cluster` |
| Image | `cr.yandex/<registry-id>/<service>:<git-sha>` |
| Logical database | one per service, named after the service |

## Project delta

The consuming repository supplies, and this skill never hard-codes:

- **Cloud id and folder id** per environment (and which environments exist at all — a
  production-only setup is a legitimate choice).
- **Cluster context name** in the `yc-<project>-cluster` shape, exported once as
  `KUBE_CONTEXT` / `kube_context`.
- **Namespace** (usually one per project).
- **Container registry id**, from a Terraform output, plus which registry serves which
  deploy path if there is more than one.
- **Registry/Lockbox/resource naming prefix** and the Lockbox vault naming scheme.
- **Node port allocations** per service, and whether the service is behind the ALB at all.
- **Database names**, pooler port and the chosen `sslmode`, plus whether the CA is mounted.
- **Valkey major version** pinned in Terraform.
- The **`.secrets.example` key list** — the contract for what each service needs.
