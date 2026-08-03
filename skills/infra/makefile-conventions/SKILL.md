---
name: makefile-conventions
description: The root Makefile as the single entrypoint — the standard target contract (help, build, test, lint, fmt, check, tidy, clean plus the deploy and ops set) that other skills, docs and CI depend on, self-documenting help harvested from `## target: description` comments, module fan-out discovered from the filesystem instead of hand-listed, environment parameterization with a safe default and separately named production targets, and per-service sub-Makefiles for the inner loop. Use when adding or renaming a Make target, writing a root or per-service Makefile, or moving a repeated command out of shell history. Trigger phrases - "add a make target", "make help is out of date", "a new module is not being built", "make build skips my service", "make build does nothing", "make deploy hit the wrong environment", "standardize our Makefiles". Language- and vendor-neutral - `make build` produces the artifacts, whatever they are.
license: Apache-2.0
metadata:
  source: glotyuids/engineering-skills
  version: 0.1.0
---

# Makefile conventions — the single entrypoint

**Core rule: every repeated command in the repo is a `make` target, the target names are a
public interface, and the Makefile is its own index.** If a human has to run something
twice, it belongs in a target. If a human has to read a wiki to find the command, the help
target failed.

This skill defines only the **authoring style of the Makefiles themselves**: the target
contract and its stability, the self-documenting help mechanism, module fan-out,
environment parameterization, and the split between the root Makefile and per-service
Makefiles. It does not define what a deploy does or in what order (`cicd-build-deploy`),
orchestrator internals (`ansible-deploy`), chart internals (`kubernetes-helm`), IaC layout
(`terraform-conventions`) or the secret contract (`secrets-management`) — those are sibling
skills in this pack.

No language is assumed. `make build` produces the artifacts, whatever they are; `make test`
runs the tests, whatever the runner is. If a language-pack skill (e.g. `go-conventions`) is
installed, follow it for what goes *inside* a recipe; otherwise follow the project's own
conventions.

Items marked `[!]` caused a real production incident when missed. They are not style
preferences.

## 1. Why the Makefile and not a pile of scripts

- **One entrypoint, many runners.** A developer shell, a cron host, an agent and a CI job
  all run the same target and get the same result. The automation must be independent of
  any specific git host or CI platform — never assume hosted runners or platform-specific
  workflow syntax. A CI platform, if one is ever adopted, calls `make <target>` and nothing
  else.
- **Running Make plus an orchestrator with no CI platform at all is a legitimate choice.**
  Record which way the project went as an ADR so nobody "fixes" it later by accident.
- **Discoverability.** `make help` is the entry point to the repo's operations. A command
  that exists only in someone's shell history, a chat message or a CI web UI does not exist.
- **Scripts still exist** — they live in `scripts/` and are *called by* targets. The target
  is the stable name; the script is the implementation. Never document a script path as the
  thing to run.

## 2. The target contract is an interface

Other skills, the project docs, agent instructions, onboarding notes and any CI runner all
call these names. **Target names are as stable as a published API.**

- Renaming a target is a breaking change. If you must rename, keep the old name as an alias
  for at least one release: `secrets-apply: secrets-sync` — a one-line alias target costs
  nothing and stops every stale doc and script from breaking.
- Do not repurpose a name. A `deploy` that used to mean staging and now means production is
  the worst possible change: every existing muscle memory now does something else.
- Adding a target is always safe. Prefer adding a narrow one over overloading a broad one
  with a new flag.
- **Never make a production action reachable by a variable on a non-production
  target.** Production is a separately named target (`deploy-prod`, `deploy-prod-service`),
  never `deploy ENV=prod` on its own. A forgotten or mistyped variable must fail, not
  promote. This is the single rule most worth enforcing in review.

### Root Makefile — local development

| Target | Effect |
|---|---|
| `help` | list the available targets — the **default goal**, and the first target in the file |
| `modules` | list the modules the Makefile discovered — the debugging aid when one is silently skipped |
| `build` | produce the artifacts for **every** module |
| `test` | run tests for every module |
| `lint` | run the linter for every module (guard: fail with an install hint if it is missing) |
| `fmt` | format every module |
| `vet` / `check` | the language's static analysis pass, per module (name it after what the toolchain calls it; keep one of the two, consistently) |
| `tidy` / `deps` | dependency hygiene per module |
| `clean` | remove build artifacts and coverage output, per module |
| `docker-build` | build the image(s) locally, no push |

### Root Makefile — deploy and ops

| Target | Effect |
|---|---|
| `deploy` | deploy changed services to `ENV` (default: the least dangerous environment) |
| `deploy-prod` | deploy changed services to production |
| `deploy-prod-all` | force-deploy **all** services to production |
| `deploy-prod-service SERVICE=<name>` | deploy exactly one service |
| `deploy-prod-<component>` | shortcut for a component that is not a normal service (e.g. a client bundle) |
| `secrets-sync` | push the local secret file into `SECRET_MANAGER` and apply the sync objects |
| `infra-plan` / `infra-apply` `ENV=<env>` | infrastructure changes (also seen as `terraform-plan` / `terraform-apply`; pick one spelling and alias the other) |
| `infra-destroy` | destructive; must require an explicit confirmation variable |
| `status` / `logs` / `restart` / `rollback` / `shell` / `port-forward` | ops, `SERVICE=<name>` where relevant |
| `test-e2e` | run the end-to-end suite against an environment |

Project-specific targets are expected and welcome (per-component deploys, scaling helpers,
a client-app start target, license-notice regeneration, token helpers). They follow the same
rules; they do not replace the contract above.

### Per-service Makefile — the inner loop

Lives in the service directory. It is what a developer uses all day and it never deploys:

`build`, `run`, `run-dev` (hot reload), `test`, `test-coverage`, `lint`, `fmt`, `clean`,
`deps` / `deps-update`, `generate`, `migrate-up` / `migrate-down` / `migrate-create`, `help`.

Head the file with a comment saying where deploys live:

```makefile
# <service> — local development only.
# For deployment use the root Makefile: make deploy / make deploy-prod
```

The root Makefile never duplicates the inner loop, and the service Makefile never grows a
deploy target. One direction only: root delegates down, service never reaches up.

## 3. Self-documenting help

**Rule: a target's description lives on the line above the target, and `help` is generated
from those lines.** A hand-written help block is a second source of truth and it drifts —
in practice it grows duplicates, keeps advertising renamed targets, and silently omits
everything added last quarter.

```makefile
## build: Produce the artifacts for every module
build:
	...

help:
	@echo "<project> — root Makefile (ENV=$(ENV))"
	@echo ""
	@sed -n 's/^## //p' $(MAKEFILE_LIST) | column -t -s ':'
```

- The marker is `## <target>: <description>` — two hashes, then the target name, a colon,
  and one line of description. A single `#` is a normal comment and stays out of help.
- **Descriptions must not contain a colon.** The formatter splits on `:`; a second colon
  produces a third column and mangles the table.
- Harvesting from `$(MAKEFILE_LIST)` rather than `$(firstword $(MAKEFILE_LIST))` means any
  `include`d fragment contributes its own targets to help automatically.
- **Help order is file order.** Group targets in the file the way you want them read
  (local development, then deploy, then ops, then testing, then cleanup) and add banner
  `@echo` lines between the groups.
- Make `help` the default goal (`.DEFAULT_GOAL := help`) so a bare `make` is safe and
  informative rather than accidentally building or, worse, deploying.
- Let `help` also print **discovered state** — the module list, the current `ENV` — so it
  doubles as a diagnostic. "Which modules does this Makefile see?" is answered without
  reading the file.
- Anything a reader needs beyond one line (a required env var, a two-step workflow) goes in
  a normal `#` comment block above the target, not in the `##` line.

## 4. Module fan-out is discovered, not listed

**Rule: the root Makefile finds modules on the filesystem. Adding a module must require
zero Makefile edits.**

```makefile
# Every module in the repo, discovered — never hand-listed.
MODULES := $(shell find <roots> -maxdepth 3 -name '<module-manifest>' \
                   -exec dirname {} \; 2>/dev/null | sort)
```

- Enumerate the **roots** explicitly (the shared-package dir, the services dir, the tools
  dir) instead of scanning the whole repo — that keeps vendored trees, dependency caches and
  build output from being discovered as modules.
- `-maxdepth` bounds the walk. Without it the scan finds modules inside dependency
  directories and the fan-out starts linting third-party code.
- `sort` makes the order deterministic, so build output and failures are comparable between
  machines and runs.
- `2>/dev/null` keeps a missing root from printing noise — but it also hides a **mistyped**
  root. That is exactly why `make modules` exists: when a service is silently skipped, the
  discovery list is the first thing to look at.
- `MODULES := $(shell ...)` runs at parse time on **every** invocation of make, including
  `make help`. Keep the command cheap; never put a network call or a cloud CLI in a
  parse-time `$(shell ...)`.

### Writing the fan-out loop

```makefile
build:
	@set -e; for m in $(MODULES); do \
		echo "==> build $$m"; \
		(cd $$m && $(TOOLCHAIN) build); \
	done
```

- **`set -e` is mandatory.** Make only checks the exit status of the recipe's last line; a
  bare `for` loop happily continues after a failed module and the target exits 0. A green
  `make test` that skipped a broken module is worse than no test target at all.
- **Subshell per module** (`(cd $$m && ...)`) so the working directory does not leak into
  the next iteration.
- **Echo a progress banner per module** (`==> build $$m`). Fan-out output is long; without
  the banner nobody can tell which module produced the error.
- `$$m` — a single `$` is Make's; shell variables need doubling.
- Delegate with `$(MAKE) -C $$m <target>` **only if every discovered module carries a
  Makefile**. When shared-package modules do not, call the toolchain directly at the root
  and keep the per-service Makefiles for the inner loop.
- Guard external tools once, at the top of the target, with an actionable message:
  `@which <tool> >/dev/null || { echo "<tool> not installed: <install command>"; exit 1; }`.

## 5. Environment parameterization

```makefile
ENV     ?= staging     # least dangerous default
SERVICE ?=             # optional narrowing
KUBE_CONTEXT ?= my-cluster
```

- **`?=` for anything an operator may override**, `:=` for everything derived. A plain `=`
  is re-evaluated on every use and is almost never what you want.
- **The default value of `ENV` is the least dangerous environment.** A repo whose root
  Makefile carries `ENV ?= prod` has a bare `make infra-destroy` pointed at production; the
  default must be the environment where a mistake is cheap. When there is only one
  environment, still write the variable — the second environment always arrives.
- **Never infer the environment** from the current git branch, the current cluster context,
  the hostname, or an exported shell variable. It comes from `ENV=` on the command line or
  from a separately named target, and from nowhere else.
- `[!]` **Cluster context and namespace flow from variables, never from "whatever is
  current".** Every `kubectl` / `helm` call in a recipe or a called script passes
  `--context "$(KUBE_CONTEXT)"` / `--kube-context` and `-n "$(NAMESPACE)"`. A shared
  kubeconfig accumulates entries for several environments and projects; whichever was
  selected last wins silently, so a command meant for staging lands in production with a
  completely plausible success message. See `cicd-build-deploy` §3.
- **Optional parameters use the `$(if ...)` idiom** so one target serves both shapes:

  ```makefile
  deploy:
  	cd $(ORCH_DIR) && <orchestrator> deploy --env $(ENV) $(if $(SERVICE),--service $(SERVICE),)
  ```

- **Required parameters are checked, not assumed.** An unset variable expands to the empty
  string and the underlying tool then does something surprising — restarts everything,
  tails nothing, or deploys the whole repo. Guard once:

  ```makefile
  define require
  	@test -n "$($(1))" || { echo "ERROR: $(1)=<value> is required"; exit 1; }
  endef

  rollback:
  	$(call require,SERVICE)
  	...
  ```

- **Destructive targets require an explicit confirmation variable** that no other target
  sets (`CONFIRM=yes`, or the orchestrator's own `confirm_destroy` flag). Being asked twice
  is the point.
- **Never echo a secret value from a recipe.** A target that fetches a credential for a
  test run prints it only when its whole purpose is to be `eval`'d into the operator's own
  shell, and its name says so (`*-secrets`). Everything else passes credentials as an
  environment prefix to the command, never through `@echo`.
- When a target needs a credential refreshed first, encode that in a variable prefix rather
  than a README instruction, so it cannot be forgotten:

  ```makefile
  PROD_PREFLIGHT := eval "$$(scripts/fetch-credentials.sh 2>/dev/null)" &&
  deploy-prod:
  	$(PROD_PREFLIGHT) cd $(ORCH_DIR) && <orchestrator> deploy --env prod
  ```

## 6. Delegation to sub-Makefiles

A family of related targets (an end-to-end suite, a client build) belongs in the
subdirectory's own Makefile; the root exposes thin wrappers so `make help` at the root
still lists everything.

```makefile
## test-e2e: Run the default end-to-end slice against BASE_URL
test-e2e:
	BASE_URL=$(BASE_URL) $(MAKE) -C <subdir> e2e
```

- Pass configuration as an **environment prefix on the `$(MAKE)` line**, not by exporting
  globally — the sub-Makefile's own defaults stay visible and overridable.
- Use `$(MAKE)`, never a literal `make`: it preserves the job server, the flags and the
  chosen make binary.
- A composite target that fans out over several services is just repeated `$(MAKE)` calls
  to the single-service target — keep the single-service target the only place that knows
  how a deploy is invoked:

  ```makefile
  deploy-prod-<group>:
  	$(MAKE) deploy-prod-service SERVICE=<a>
  	$(MAKE) deploy-prod-service SERVICE=<b>
  ```

- **Cap parallel fan-out of image builds at three.** Beyond that the build host thrashes and
  everything slows down together; see `cicd-build-deploy` §5.
- Dispatching on a variable inside a target (`ifeq ($(SERVICE),<special>)`) is acceptable
  for one genuine special case, and a smell at two. The second one becomes its own target.

## 7. Versioning and artifact naming

```makefile
VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
TAG     := $(shell printf '%s' "$(VERSION)" | tr -c 'A-Za-z0-9_.-' '-' | sed 's/--*/-/g; s/-$$//')
```

- Derive the version from the VCS, with a literal fallback so the Makefile still works in a
  checkout without tags or history (a shallow CI clone, an exported tarball).
- **Sanitize before using a version as an image tag or a release name.** `git describe`
  output can contain characters that are illegal in a tag, and a `-dirty` suffix marks a
  build that is not reproducible — decide deliberately whether to strip it or refuse to
  push it.
- Stamp the version into the artifact through the toolchain's own mechanism, and expose the
  same value to the deploy targets, so "what is running" has one answer.

## 8. Recipe hygiene

- Recipes are indented with **tabs**. An editor that inserts spaces produces
  `missing separator`.
- Every target that is not a real file goes in `.PHONY`. Keep the list grouped and
  line-continued at the top, and add to it in the same edit that adds a target — a `build`
  target in a repo containing a `build/` directory silently does nothing without it.
- Prefix informational commands with `@` so the recipe does not echo itself; leave the
  interesting command un-prefixed so the operator can see exactly what ran.
- One target, one job. A target that builds *and* pushes *and* deploys cannot be reused by
  the next target that needs only the build.
- Every target is **idempotent and re-runnable**. A half-failed deploy is re-run, never
  resumed by hand.
- No interactive prompts inside a recipe except a deliberate destructive-action
  confirmation — targets run unattended.
- Multi-line shell logic uses `\` continuations and `;` chaining because each line of a
  recipe is a separate shell. Anything longer than ~10 lines moves into `scripts/` and the
  target calls it.
- Repeated recipe fragments become a `define`/`$(call ...)` macro rather than a fourth
  copy-paste.
- Keep the same target names in the root Makefile and in per-service Makefiles wherever the
  meaning matches (`build`, `test`, `lint`, `fmt`, `clean`, `help`). Muscle memory should
  transfer between directories.

## 9. Honesty about stubs

In a freshly bootstrapped repo the deploy and cloud targets are **placeholders**.

- A placeholder target must **fail loudly** — print what is missing and exit non-zero. A
  stub that exits 0 will be read as a successful deploy, by a human and by an agent.
- Mark it in its own `##` description (`## deploy: NOT IMPLEMENTED — placeholder`) so
  `make help` tells the truth.
- Do not claim resources are provisioned until the IaC modules, orchestrator roles,
  `REGISTRY`, `SECRET_MANAGER` wiring and the charts are actually in place and have been
  applied at least once against a real environment.
- A target authored but never executed against a live environment carries
  `Verify: never run against a real environment` in its comment block until someone runs it.

## 10. Worked skeleton

```makefile
# <project> — root Makefile: the single entrypoint.
# Local orchestration across every module, plus deploy entrypoints that wrap the
# orchestrator. Per-service inner loop lives in services/<name>/Makefile.

.DEFAULT_GOAL := help
.PHONY: help modules build test lint fmt check tidy clean \
        deploy deploy-prod deploy-prod-service secrets-sync \
        infra-plan infra-apply infra-destroy \
        status logs restart rollback test-e2e

ENV          ?= staging
SERVICE      ?=
KUBE_CONTEXT ?= my-cluster
TOOLCHAIN    := <build-tool>
ORCH_DIR     := infra/<orchestrator>
MODULES      := $(shell find <roots> -maxdepth 3 -name '<module-manifest>' \
                        -exec dirname {} \; 2>/dev/null | sort)

define require
	@test -n "$($(1))" || { echo "ERROR: $(1)=<value> is required"; exit 1; }
endef

# ---- Local development ------------------------------------------------------
## help: Show this help
help:
	@echo "<project> — root Makefile (ENV=$(ENV))"
	@echo ""
	@sed -n 's/^## //p' $(MAKEFILE_LIST) | column -t -s ':'
	@echo ""
	@echo "Modules discovered:"
	@for m in $(MODULES); do echo "  - $$m"; done

## modules: List the modules discovered on the filesystem
modules:
	@for m in $(MODULES); do echo "$$m"; done

## build: Produce the artifacts for every module
build:
	@set -e; for m in $(MODULES); do \
		echo "==> build $$m"; \
		(cd $$m && $(TOOLCHAIN) build); \
	done

## test: Run tests for every module
test:
	@set -e; for m in $(MODULES); do \
		echo "==> test $$m"; \
		(cd $$m && $(TOOLCHAIN) test); \
	done

## lint: Run the linter for every module
lint:
	@which <linter> >/dev/null || { echo "<linter> not installed: <install command>"; exit 1; }
	@set -e; for m in $(MODULES); do \
		echo "==> lint $$m"; \
		(cd $$m && <linter> run); \
	done

## clean: Remove build artifacts
clean:
	@set -e; for m in $(MODULES); do rm -rf $$m/bin $$m/coverage.*; done

# ---- Deploy and ops ---------------------------------------------------------
## deploy: Deploy changed services to ENV (optional SERVICE=<name>)
deploy:
	cd $(ORCH_DIR) && <orchestrator> deploy --env $(ENV) $(if $(SERVICE),--service $(SERVICE),)

## deploy-prod: Deploy changed services to production
deploy-prod:
	cd $(ORCH_DIR) && <orchestrator> deploy --env prod $(if $(SERVICE),--service $(SERVICE),)

## deploy-prod-service: Deploy exactly one service to production (SERVICE=<name>)
deploy-prod-service:
	$(call require,SERVICE)
	$(MAKE) deploy-prod SERVICE=$(SERVICE)

## secrets-sync: Push the local secret file into SECRET_MANAGER and apply sync objects
secrets-sync:
	cd $(ORCH_DIR) && <orchestrator> secrets --env $(ENV)

## infra-destroy: Destroy infrastructure for ENV — DANGEROUS, needs CONFIRM=yes
infra-destroy:
	$(call require,CONFIRM)
	cd $(ORCH_DIR) && <orchestrator> infra --env $(ENV) --action destroy --confirm

## logs: Tail a service's logs (SERVICE=<name>)
logs:
	$(call require,SERVICE)
	cd $(ORCH_DIR) && <orchestrator> logs --env $(ENV) --service $(SERVICE)
```

## 11. Known failure modes

| Symptom | Cause | Fix |
|---|---|---|
| `make build` prints "up to date" and does nothing | a directory of the same name exists and the target is not in `.PHONY` | add every non-file target to `.PHONY` |
| `missing separator` | recipe indented with spaces | use tabs |
| A new module is never built or tested | it lives outside the discovery roots, below `-maxdepth`, or the root name was mistyped and `2>/dev/null` swallowed the error | run `make modules`; fix the roots |
| `make test` is green but a module is broken | the fan-out loop has no `set -e`; only the last module's status reached make | add `@set -e;` to the loop |
| `make help` advertises a target that no longer exists | help is a hand-written `@echo` block | generate it from the `##` lines |
| A target's help line renders as three columns | the description contains a colon | remove the colon |
| `make restart` restarts everything | `SERVICE` was unset and expanded to empty | add the `require` guard |
| The command works for one person only | it lives in shell history, not in a target | add the target |
| A deploy hit the wrong environment | `ENV` defaulted to production, or the context came from the current kubeconfig | least-dangerous default; named prod targets; pin the context from the variable |
| `make deploy` "succeeded" but nothing was provisioned | the target is a placeholder that exits 0 | make stubs exit non-zero and say so in help |

## 12. Definition of done

- [ ] `make help` is the default goal, generated from `##` lines, and lists every target.
- [ ] The target contract of §2 exists; renamed targets kept an alias.
- [ ] Production has its own named targets; no `ENV=prod` path into a non-production target.
- [ ] Module list is discovered from the filesystem; `make modules` prints the expected set.
- [ ] Every fan-out loop has `set -e`, a per-module banner and a subshell `cd`.
- [ ] Every non-file target is in `.PHONY`.
- [ ] Required variables are guarded; destructive targets need an explicit confirmation.
- [ ] Every `kubectl` / `helm` call in a recipe passes an explicit context from a variable.
- [ ] Per-service Makefiles cover the inner loop and contain no deploy target.
- [ ] Placeholder targets fail loudly and say so in their help line.
- [ ] `make build`, `make test`, `make lint` pass from a clean checkout, for every module.

## Vendor delta

The `skills/cloud/<vendor>` skill must supply, phrased as capabilities:

- `MANAGED_K8S` — the cluster-context naming convention that `KUBE_CONTEXT` carries, and
  any credential pre-fetch command that must be evaluated before ops targets can run
  unattended.
- `REGISTRY` — the image path format the `docker-build` / deploy targets interpolate, and
  the login command a build host needs.
- `SECRET_MANAGER` — the CLI invocation behind `secrets-sync` and behind any
  credential-fetching test target, plus the tool guards those targets should check for.
- `TFSTATE_BACKEND` — the environment variables the infra targets must have set, and the
  file they are sourced from.
- `IAM` — the CLI tool name to guard on, and how a short-lived token is obtained for the
  pre-flight prefix.

## Project delta

The consuming repo supplies:

- The discovery roots, the module-manifest filename and the `-maxdepth` bound.
- The toolchain commands behind `build`, `test`, `lint`, `fmt`, `check`, `tidy`, `clean`,
  and the linter's install hint.
- Environment names and the default value of `ENV`; the `KUBE_CONTEXT` and namespace per
  environment.
- The orchestrator invocation and where its playbooks/inventories live.
- Any targets beyond the contract in §2, and which subdirectories own their own Makefiles.
- The version derivation and tag-sanitization rules if `git describe` is not the source.
- The service list and which services are independently deployable.
- The maximum number of parallel deploys if the default cap of 3 does not fit the build host.
