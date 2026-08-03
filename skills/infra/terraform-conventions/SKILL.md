---
name: terraform-conventions
description: Vendor-neutral Terraform discipline - one module per infrastructure concern, a root composition per environment, remote state in the TFSTATE_BACKEND capability with locking and an out-of-band bootstrap, credentials sourced from a git-ignored env file, and a plan-before-apply ritual that reads every destroy/replace line on a managed data store. Use when writing or reviewing Terraform, adding a module or a managed resource (database, bucket, registry, vault, node group), wiring Make targets around terraform init/plan/apply/output/destroy, migrating local state to a remote backend, refactoring module paths with moved blocks, or investigating drift. Trigger phrases - "terraform plan", "terraform apply", "add a module", "provision a database", "tfstate", "remote state", "state locking", "backend.tf", "tfvars", "terraform output", "moved block", "state drift", "why does the plan want to destroy", "terraform-init/plan/apply target".
license: Apache-2.0
metadata:
  source: glotyuids/engineering-skills
  version: 0.1.0
---

# Terraform conventions

This skill defines **only** the Terraform layer: module layout, state handling, credential
handling, and the plan/apply discipline. It does not define which concrete service backs a
capability (that is the cloud vendor skill in `skills/cloud/`), how images are built and
released, how charts are shaped, or how application secrets reach a pod. If the
`cicd-build-deploy`, `kubernetes-helm`, `ansible-deploy` or `secrets-management` skills are
installed, follow them for those; otherwise follow the project's own conventions.

Infrastructure is named here by **capability**, never by product: `MANAGED_K8S`,
`MANAGED_PG`, `CACHE`, `REGISTRY`, `SECRET_MANAGER`, `OBJECT_STORAGE`, `TFSTATE_BACKEND`,
`LB`, `IAM`, `NETWORK`. `[!]` marks a rule that caused a real production incident when
missed.

## 1. Layout — one module per concern, one composition per environment

```text
infra/terraform/
├── modules/                  # reusable, capability-shaped, no environment values inside
│   ├── network/              # NETWORK   — VPC + subnets
│   ├── kubernetes/           # MANAGED_K8S — cluster + node groups
│   ├── postgresql/           # MANAGED_PG  — one cluster, one logical DB per service
│   ├── cache/                # CACHE       — managed Redis-compatible store
│   ├── storage/              # OBJECT_STORAGE — buckets (documents, artifacts)
│   ├── registry/             # REGISTRY    — container image registry
│   ├── secrets/              # SECRET_MANAGER — one vault per service
│   ├── iam/                  # IAM         — service accounts + least-privilege bindings
│   └── lb/                   # LB          — optional routing layer
├── environments/
│   └── <env>/                # the root composition: main.tf, variables.tf, outputs.tf,
│       │                     # backend.tf, terraform.tfvars (git-ignored)
│       └── ...
└── scripts/bootstrap.sh      # creates the state bucket + its keys, out of band (§2)
```

Rules:

- A **module** owns one infrastructure concern and takes every environment-specific value as
  an input variable. No environment names, no counts tuned for one environment, no secrets.
- A **root composition** (`environments/<env>/`) wires modules together and is the only place
  that names an environment. One directory per environment, one state file per directory.
- **Production-only is a legitimate environment set.** Do not invent a staging composition
  nobody operates. Keep everything env-parameterised so adding one later is additive, not a
  rewrite — that is the whole reason the environment name never appears inside a module.
- Pin `required_version` and every provider version constraint in the composition, and
  **commit the dependency lock file** so two operators resolve identical providers.
- Adding a new environment or a new cloud must not edit `modules/` — if it does, an
  environment value leaked into a module.
- Reuse order when starting a stack: modules first (retarget names), then the composition,
  then the automation wrapper. Copying a composition and editing it into a module is how
  environment values get baked in.

## 2. State — remote, locked, and bootstrapped out of band

- State lives in `TFSTATE_BACKEND`, declared in `environments/<env>/backend.tf`, with a
  distinct state key per environment. Never share one key between environments.
- **Locking is mandatory.** If the backend implementation provides native locking, enable
  it. If it does not, the project must impose a human lock — one operator applies at a
  time, announced — and say so in the runbook. Two concurrent applies against one state is
  how resources get orphaned.
- **The state file is a secret.** Managed-database passwords, generated keys and
  connection strings land in it in plaintext, whatever the variable was marked. The state
  bucket is therefore encrypted, private, versioned, and never fronted by anything public.
- **The bootstrap chicken-and-egg:** the state bucket and its access keys must exist before
  the first `terraform init`, so they cannot be created by the stack they store. A small
  bootstrap script creates the bucket and a service account with static access keys and
  prints the keys once. Keep that bucket **out of the managed stack entirely** and document
  where it came from; importing it later means a `terraform destroy` of that module can
  delete the state you are standing on.

### Never commit

Add to `.gitignore` before the first `terraform init`:

```gitignore
*.tfstate
*.tfstate.*
.terraform/
*.tfvars          # values, including database passwords
!*.tfvars.example
.terraform.env    # the credential env file (§3)
```

`terraform.tfvars` carries real values and is git-ignored; a committed
`terraform.tfvars.example` is the contract describing every variable the composition needs.

### Migrating an existing local state into the backend

A one-time, high-risk operation. The state you are moving describes the **live**
production cluster, database and routing — not a scratch environment.

```bash
source .terraform.env
cd infra/terraform/environments/<env>
cp terraform.tfstate terraform.tfstate.pre-migration   # keep a copy off to the side
terraform init -migrate-state
terraform plan    # MUST print "No changes." before anything else runs
```

If that plan is not empty, **stop and reconcile**. Do not proceed to any other change
— including a module-relocation refactor's own `moved {}` blocks — until the plan is clean.
A non-empty plan right after a state move means Terraform no longer recognises live
resources and the next apply will recreate them.

*Verify:* in one source project `backend.tf` declared the remote backend while the live
state (serial 72+, the real cluster, managed database, cache and routing) was still local on
the operator's machine — the migration was **authored, never executed**. Before assuming
state is shared, check which is true: a declared backend is not a used backend.

## 3. Credentials come from the environment

Terraform reads credentials from environment variables sourced from a **git-ignored** env
file whose `.example` twin is committed:

```bash
# .terraform.env.example  — copy to .terraform.env (git-ignored), then: source .terraform.env

# Provider credential. Prefer a short-lived token minted per session, so a leak
# has a blast radius measured in hours; regenerate when it expires.
export TF_PROVIDER_TOKEN="$(<cloud-cli> mint-token)"

# Static access keys for the state backend, printed once by the bootstrap script.
export TFSTATE_ACCESS_KEY_ID="<tfstate-sa-access-key>"
export TFSTATE_SECRET_ACCESS_KEY="<tfstate-sa-secret-key>"
```

- The **actual variable names are dictated by the backend's storage-protocol client**, not
  by the cloud you are on, and are frequently surprising (a backend can demand another
  vendor's variable prefix). The vendor skill names them; do not rename them.
- Static long-lived keys exist for exactly one reason: a state backend that cannot consume a
  short-lived token. Everything else uses the short-lived path.
- `source .terraform.env` before **every** Terraform command, including `output`. A wrapper
  target that forgets it fails with an authentication error that reads like a permissions
  problem.
- Never pass credentials as `-var`; they end up in shell history and in the state.

## 4. The plan/apply ritual

Numbered, every time, including "trivial" changes:

1. `source .terraform.env`, then work inside `environments/<env>/`.
2. `terraform init` (add `-upgrade` only when provider constraints changed).
3. `terraform validate` and `terraform fmt -check`.
4. `terraform plan -out=tfplan`. **Never apply without a plan** — not even for a one-line
   variable change.
5. **Read the plan, do not skim it.** Specifically hunt for:
   - any `destroy` or `must be replaced` / `forces replacement` line touching `MANAGED_PG`,
     `CACHE`, `OBJECT_STORAGE` or `SECRET_MANAGER` — those destroy data, not config;
   - resources you did not intend to touch at all (that is drift, §6);
   - a plan larger than the change you made.
6. If the plan destroys or replaces a data store, **stop and get explicit written human
   confirmation** before applying. There is no undo.
7. `terraform apply tfplan` — apply the saved plan, not a fresh one, so what you reviewed is
   what runs.
8. `terraform output` and propagate (§5).
9. Record what changed where the project records infrastructure changes.

Guardrails:

- Protect data stores in code as well as in procedure: set the provider's deletion
  protection attribute on production databases and add `lifecycle { prevent_destroy = true }`
  to the stores whose loss would be unrecoverable. Procedure fails at 2am; the lifecycle
  block does not.
- Refactoring module paths or renaming resources uses `moved {}` blocks, verified by a plan
  that shows **only moves and no destroys**. Never fix a rename with `state rm` + re-import
  unless a `moved {}` block genuinely cannot express it.
- `terraform destroy` is never a routine target. Where the automation exposes one, it
  requires an explicit confirmation flag (see §7) and a human who typed it deliberately.

## 5. Outputs are the contract other tooling consumes

Outputs are not documentation — they are the interface between Terraform and everything
downstream: connection hosts and ports, registry id, bucket names, vault ids, cluster
identifiers. The secrets sync step, the release values and the operational scripts all read
them.

- Consume them programmatically: `terraform output -raw <name>`. Never hand-copy an
  identifier into a chart, a script or a variable file — hand-copied ids are the most common
  source of "it works on the operator's machine".
- An output that no downstream tool consumes is dead weight; an identifier a downstream tool
  needs and cannot get from an output is a missing output.
- Keep secret-bearing outputs marked `sensitive` — and remember §2: sensitive hides them
  from the console, not from the state file.

### Ordering: the resource must exist before the code that uses it

Provisioning is a **prerequisite** of deployment, not a parallel activity:

```text
1. terraform apply   # the service's logical database / bucket / vault now exists
2. secrets sync      # DSNs built from Terraform outputs land in SECRET_MANAGER
3. deploy            # migrations run, then the workload starts
```

`[!]` **A service's database must exist before its migration job runs.** Adding a service
usually means adding its database name to the `databases` list in the environment
composition and applying Terraform *first*; the migration job cannot create its own
database, and when it runs against a missing one it fails in a way that looks like a
migration bug. The same ordering applies to any bucket or vault the workload opens at
startup.

## 6. Drift is real — a dirty plan is an incident

A `terraform plan` that shows changes nobody made is not noise to be applied away.

- Run a plan on a schedule (or at minimum before every apply and after every incident) and
  treat a non-empty plan as an event with a cause: someone changed something by hand, a
  provider changed a default, or a resource is partially managed (below).
- **Investigate before applying.** Applying a drifted plan can revert an emergency manual
  fix that is currently the only thing keeping production up.
- **Never fix infrastructure in the cloud console.** If an emergency forces it, the
  follow-up task is to bring the change back into Terraform the same day and re-plan to
  clean.
- **Partially-managed resources are a permanent drift source.** A module flag such as
  `lifecycle_policy_enabled = false` with a comment "managed outside Terraform" means a real
  surface nobody owns. Either manage it in Terraform or record, in the repo, where it is
  managed and by whom.
  *Verify:* in one source project exactly that pattern left it unconfirmed whether the
  registry's image-cleanup policy existed at all — if it did not, every deploy pushed images
  that nothing ever pruned.
- Two Terraform-adjacent things that look like drift and are not: intentionally duplicated
  resources with near-identical ids (two registries for two deploy paths, for example), and
  resources created by an in-cluster controller. Document both so nobody "fixes" them.

## 7. Automation wrapper — one entrypoint, environment-parameterised

Terraform is driven through the project's task runner so that the working directory, the
environment and the credential sourcing live in exactly one place. `make` targets are used
below as the illustration; the shape matters, not the tool.

| Target | Does | Notes |
|---|---|---|
| `terraform-init ENV=<env>` | init / re-init the composition | add `-migrate-state` only for the one-time move (§2) |
| `terraform-plan ENV=<env>` | plan, save the plan file | the default target operators run |
| `terraform-apply ENV=<env>` | apply the saved plan | human-confirmed for data-store changes |
| `terraform-output ENV=<env>` | print outputs | the contract downstream tooling reads (§5) |
| `terraform-destroy ENV=<env>` | destroy | **requires an explicit confirmation flag**, e.g. `confirm_destroy=true`; never run casually |

- `ENV` defaults to the only environment that exists, and every target passes it through —
  an operator must not be able to plan one environment and apply another.
- The wrapper sources the credential env file itself, or fails loudly if it is unsourced.
- Keep the target names stable; runbooks, onboarding docs and other skills reference them.

## 8. Adding a managed resource for a new service

- [ ] Decide which existing module owns the concern; add a new module only for a genuinely
      new concern.
- [ ] Add the input (database name, bucket name, vault name) to the environment composition
      — usually one line in a list, not a new module block.
- [ ] Add the identifier the downstream tooling needs as an **output**.
- [ ] `plan` → read it → `apply`, before any deploy of the service (§5).
- [ ] Grant access through `IAM` least-privilege bindings in the `iam` module, not by
      widening an existing role.
- [ ] Update `terraform.tfvars.example` and the credential `.example` file if new variables
      appeared.

## Definition of done

- [ ] No environment value, secret or environment name inside `modules/`.
- [ ] `backend.tf` declares the remote backend **and** the live state is actually there.
- [ ] Locking is enabled, or the human-lock convention is written in the runbook.
- [ ] `terraform fmt -check` and `terraform validate` pass; the lock file is committed.
- [ ] No state file, `.tfvars` or credential env file is tracked by git; the `.example`
      twins are.
- [ ] `terraform plan` is empty against the live environment (no drift).
- [ ] Production data stores carry deletion protection and `prevent_destroy`.
- [ ] Every identifier consumed downstream comes from an output, none hand-copied.

## Vendor delta

The cloud vendor skill must supply:

- `TFSTATE_BACKEND` — the concrete storage service, the backend block's arguments, the exact
  credential environment-variable names, whether native state locking exists, and the
  bootstrap command that creates the bucket and its keys.
- `IAM` — how the provider is authenticated (short-lived token vs key file), which roles the
  bootstrap identity needs, and the least-privilege bindings for each workload identity.
- `MANAGED_PG`, `CACHE`, `MANAGED_K8S`, `REGISTRY`, `SECRET_MANAGER`, `OBJECT_STORAGE`,
  `LB`, `NETWORK` — the resource types each module wraps, the deletion-protection attribute,
  version pinning requirements, and the traps that make a plan destroy or replace them.
- The shape of every identifier exposed as an output (host, port, registry path, vault id).
- Which surfaces the provider cannot manage at all, so they can be documented as deliberately
  unmanaged rather than rediscovered as drift.

## Project delta

The consuming repository supplies:

- **Terraform root path** and the module directory layout if it differs from §1.
- **Environment list** — which `environments/<env>/` compositions exist (production-only is
  a valid answer).
- **Resource naming prefix** and the per-service naming scheme for databases, buckets and
  vaults.
- **State backend location and key layout**, plus who ran the bootstrap and when.
- **Credential env file name** (`.terraform.env` above) and its committed `.example`.
- **Task-runner target names** for init / plan / apply / output / destroy, and the
  confirmation flag the destroy target requires.
- **The list of resources deliberately managed outside Terraform**, and where each is managed.
- **Who must confirm** a plan that destroys or replaces a data store.
