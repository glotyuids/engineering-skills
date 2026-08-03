---
name: secrets-management
description: How secrets are stored, synced and consumed so that values never enter git and exist only on the operator's machine and in SECRET_MANAGER. Use when adding a secret or third-party API key, writing or reviewing a `.secrets.example` / `*.env.example` contract file, wiring a `make secrets-sync` step, deciding how a service reads a credential (secret reference vs ConfigMap vs image layer), rotating a credential, redacting DSNs and tokens in logs, adding gitleaks-style scanning to pre-commit/CI, or handling a leaked key. Trigger phrases: "add a secret", "where do I put this API key", "secrets sync", "the pod can't find the secret", "rotate the key", "we committed a token", "is this safe to log".
license: Apache-2.0
metadata:
  source: glotyuids/engineering-skills
  version: 0.1.0
---

# Secrets management — the local-only contract

**Core rule: the repo commits only the contract. Values exist only on the operator's
machine and in SECRET_MANAGER. Runtime gets them by sync — nothing else ever holds a
value.**

This skill defines only how secret *values* travel: where they are written, how they
reach the cluster, how they are consumed, rotated and scanned for. It does not define
application-level encryption of user data, end-user authentication, or the vendor wiring
of SECRET_MANAGER itself (see `## Vendor delta`).

## 1. The four tiers

| Tier | Artifact | In git? | Written by |
|---|---|---|---|
| **Contract** | `.secrets.example`, `*.env.example` — every key with a comment, the generation command inline, the semantics of an empty value, and where derived values come from | ✅ committed | whoever adds the feature, in the same commit |
| **Local values** | `.secrets`, `.secrets.<env>`, `.terraform.env`, service-account key files, `*.pem` — only on the operator's machine | ❌ git-ignored | the operator, by hand or by the generation command |
| **Cloud values** | SECRET_MANAGER, filled by exactly one command (`make secrets-sync`), one-way local → cloud | ❌ | the sync command only |
| **Runtime** | the cluster's sync mechanism turns SECRET_MANAGER entries into a runtime secret object; workloads consume it as env from a secret reference | ❌ | the sync operator |

Each tier only ever reads from the tier above it. Nothing reads back down: the sync is
one-way, and no tool copies a runtime value into a file, a log, a chart, or a ticket.

Two contract files, two audiences — keep them separate:

- **`.secrets.example`** — application secrets consumed by services at runtime.
- **`*.env.example`** (e.g. `.terraform.env.example`) — credentials for the operator's
  own tooling (IaC provider auth, TFSTATE_BACKEND keys). `source`d into a shell, never
  synced into SECRET_MANAGER, never read by a service.

## 2. The contract file

Rules for the committed `.example`:

1. One key per line, in the exact form the local copy will take. No real value, ever.
2. **Every key carries a comment** saying what it is and who consumes it.
3. **The generation command is inline** where the value is self-minted
   (`generate: openssl rand -base64 32`). A reader must never have to ask "what shape is
   this?".
4. **Derived values name their source command**, not a literal — `terraform output -raw
   <name>`, the console page, the IaC variable that created the role.
5. **Empty-value semantics are stated** when empty is a legal, deliberate state
   ("empty ⇒ the feature is disabled"). Otherwise empty means "not filled in yet".
6. Placeholders are obviously fake (`CHANGE_ME`, `<user>`, `<host>`). Do **not** use a
   realistic prefix or a real-shaped sample — it trips secret scanners and gets copied.
7. Group keys by owning service or concern, with a header comment per group.
8. Ownership and rotation cadence for third-party keys, where they exist, go in the
   comment. The contract file is the only place that knowledge is written down.

Worked fragment — application secrets:

```sh
# <project> — secrets contract. Copy to `.secrets.<env>` (git-ignored) and fill in.
# `make secrets-sync` reads that copy and pushes the values into SECRET_MANAGER; the
# cluster's sync mechanism then turns them into the runtime secret each service reads.

# --- Shared ---
# Internal service-to-service API key. generate: openssl rand -base64 32
INTERNAL_API_KEY="CHANGE_ME"
# HMAC signing key for anonymous/trial tokens. generate: openssl rand -base64 64
TOKEN_SIGNING_KEY="CHANGE_ME"

# --- Third-party providers ---
# <provider> API key. Issued in the provider console; one key per environment.
# Owner: <team>. Rotate: every 90 days.
PROVIDER_API_KEY="CHANGE_ME"

# --- <service>: field-level sealing (see ADR-XXXX) ---
# AES-256 key sealing <sensitive-field> at rest. generate: openssl rand -base64 32
# Empty ⇒ the feature is disabled and no plaintext is ever stored. Empty is a valid,
# deliberate state here — not a missing value.
FIELD_ENC_KEY=""

# --- Per-service database DSNs (MANAGED_PG) ---
# host + pooler port: `terraform output -raw <pg_host_output>`; user/password: the IaC
# variables that created the role. Start at sslmode=require; harden to verify-full with
# a mounted CA once the CA distribution is in place.
<SERVICE>_DATABASE_DSN="postgres://<user>:<password>@<host>:<port>/<db>?sslmode=require"
```

Worked fragment — operator tooling:

```sh
# <project> — IaC environment contract. Copy to `.terraform.env` (git-ignored), then
# `source .terraform.env` before running the IaC tool.

# Cloud auth for the IaC provider. Short-lived by preference — mint it fresh rather
# than storing a static credential in the file.
export CLOUD_AUTH_TOKEN="$(<cloud-cli> auth create-token)"

# TFSTATE_BACKEND static keys — printed once by the bootstrap script; store them in a
# password manager, not in a second file.
export TFSTATE_ACCESS_KEY_ID="<tfstate-access-key>"
export TFSTATE_SECRET_ACCESS_KEY="<tfstate-secret-key>"
```

The exact backend credential variable names are vendor-specific — see `## Vendor delta`.

**File-shaped secrets** (service-account key files, client certificates, CA bundles) stay
files locally and are git-ignored by name. Store them in SECRET_MANAGER as a single
entry (base64 if the manager is text-only) and mount them at runtime from the same
runtime secret — never add them to a ConfigMap and never bake them into an image.

## 3. `.gitignore` — the enforcement side of the contract

The ignore rules ship with the project template and must be present before the first
local value is written:

```gitignore
.secrets
.secrets.*
!.secrets.example
*.env
!*.env.example
key.json
*.pem
```

Plus the agent/tool state directories (section 9). Verify with
`git check-ignore -v .secrets.<env>` rather than assuming — an ignore rule that is
shadowed by a later negation is a silent hole.

## 4. The sync: exactly one command

```
local file  ──make secrets-sync──▶  SECRET_MANAGER  ──sync operator──▶  runtime secret
```

- **One command, one direction.** No second path writes to SECRET_MANAGER — not the
  console, not an ad-hoc script, not a chart. If a value differs between local and cloud,
  local wins after the operator fixes the local file and re-runs the sync.
- **Idempotent.** Re-running with unchanged values is a no-op.
- **Quiet about values.** The command prints key names and a set/unset (or length)
  indicator — never a value, not even truncated, and not in `--debug` mode.
- **Environment is explicit.** The target environment is an argument
  (`make secrets-sync ENV=<env>`), never inferred from the shell's current context.
- `[!]` **Empty values may be silently dropped by the sync tooling.** An entry that never
  arrives in SECRET_MANAGER makes the cluster sync object fail on a missing remote key,
  and the failure surfaces later as a pod that cannot start. Either fill the key or
  remove it from both the sync input and the runtime reference — never leave a key
  declared-but-empty on the path to runtime.
- `[!]` **First-install ordering.** On a *fresh* install the runtime secret does not
  exist yet, so any pre-deploy hook that needs it (database migration jobs are the usual
  case) has no value and times out. Deploy in two phases: first create the sync object
  and let the operator populate the runtime secret with hooks disabled, then re-run the
  deploy with hooks enabled — no rebuild in between.

## 5. Consumption at runtime

| Channel | Verdict |
|---|---|
| Env var from a secret reference (`secretKeyRef` or equivalent) | ✅ the only supported path |
| File mounted from the same runtime secret | ✅ for file-shaped credentials only |
| ConfigMap, or plain values in a chart | ❌ plaintext; visible to anyone who can read the release |
| Committed `values.yaml` / `values-<env>.yaml` | ❌ contract only — it may name the secret and its keys, never carry a value |
| Baked into an image layer or a build `ARG` | ❌ survives in the registry and in every pull; rotating does not remove it |
| `--set` / CLI flags on the deploy command | ❌ lands in shell history and in process listings |
| Pasted into CI platform variables per-pipeline | ❌ a second source of truth that drifts; CI reads from SECRET_MANAGER instead |
| Query-string parameters in outbound URLs | ❌ logged by every proxy on the path — use headers |

Additional rules:

- `[!]` **Three names must agree**: the key in the contract file, the entry name in
  SECRET_MANAGER, and the reference in the deployment template. A mismatch is invisible
  until a pod starts, and produces a "secret not found" that looks like an operator
  error. The vendor layer carries the concrete form of this trap, including the naming of
  the sync object itself.
- **Validate at startup.** Each service checks that its required secrets are present and
  non-empty at boot and fails fast with the *key name* in the message. A missing secret
  must never degrade into a silent fallback (empty signing key, unauthenticated client).
- **Config changes must restart the workload.** If the deployment does not roll on secret
  change (a checksum annotation over the referenced secret, or an explicit restart step),
  a synced value can sit unused for hours.
- Whether the runtime secret is one object per service or one shared object is a project
  decision; state it in the project delta and keep it consistent — mixed conventions are
  where the naming mismatches come from.

## 6. Adding a secret — the workflow

The `.example` diff is the reviewable artifact. A reviewer who sees only the contract
diff should be able to tell what the secret is, how it is generated, who reads it, and
what happens if it is empty.

1. **Contract first.** Add key + comment + generation command (+ empty semantics) to
   `.secrets.example`, in the same commit as the feature that needs it.
2. **Local value.** Run the generation command, or fetch the derived value from the
   source named in the comment, into `.secrets.<env>`.
3. **Sync.** `make secrets-sync ENV=<env>` — one command, nothing else.
4. **Reference.** Add the env var to the deployment template as a secret reference, and
   add the key to whatever list the cluster sync object uses to declare expected keys.
5. **Read it.** Load it through the service's configuration layer, validate non-empty at
   startup.
6. **Deploy and verify** the pod is running with the value present — check presence, not
   the value (`env | grep -c '^KEY='`, or a health endpoint that reports "configured").

Definition of done:

- [ ] `.secrets.example` documents the key: purpose, consumer, generation or source,
      empty semantics.
- [ ] No value appears in any tracked file, chart, log line, test fixture, ticket, or
      chat transcript.
- [ ] `.gitignore` covers the local file that now holds the value.
- [ ] Contract key name, SECRET_MANAGER entry name and the runtime reference agree.
- [ ] The service fails fast at startup when the secret is missing.
- [ ] The secret scanner passes on the diff and on the contract file.
- [ ] The change was actually applied — the sync ran and a pod started with it. If it has
      not run, say so rather than implying the path is wired.

## 7. Rotation

1. Mint the new value locally (same generation command as the contract states).
2. `make secrets-sync` for that environment.
3. Force the cluster sync to refresh instead of waiting — the operator's refresh interval
   is commonly up to an hour, and "it will pick it up eventually" is not an incident
   response.
4. Roll the consuming workloads so processes re-read the value.
5. **Revoke the old credential at the issuer.** Replacing a value does not invalidate the
   old one; for third-party keys, revocation is a separate action and is the only step
   that actually closes the exposure.
6. For values that other systems trust (signing keys, service-to-service keys), rotate in
   two passes — accept both old and new, roll everything, then drop the old — so rotation
   is not an outage.

## 8. Never log a value

- Never log a secret value: not at debug level, not truncated, not "just the first four
  characters". If you need to correlate which credential was used, log a stable
  identifier (key name, key id, or a salted hash), never a prefix of the value.
- **Redact connection strings before they are logged.** DSNs carry the password inline,
  and the classic leak is not a deliberate log line — it is a wrapped driver error on
  connect. Wrap DSN-bearing errors in a redacting helper at the one place the connection
  is opened.
- Startup config dumps print key names and set/unset, never values.
- Request/response logging middleware must redact `Authorization`, cookies, and any
  header or body field carrying a token. Crash reporters and panic handlers get the same
  treatment — a stack trace with local variables can carry the value.
- The project's other sensitive data classes (whatever the product treats as private —
  user documents, precise location, health or financial fields) inherit the same
  no-logging rule; the project delta names them. If the `observability-and-quality`
  skill is installed, follow its PII/redaction rules for the shared log pipeline;
  otherwise follow the project's own logging conventions.

## 9. Agent rules

Agents are a leak surface of their own: everything an agent reads can end up in a
transcript, a commit message, a doc, or a tool-config file.

- **Reference secrets by key name, never by value.** Say "set `PROVIDER_API_KEY` in
  `.secrets.<env>`", not the value.
- **Never print a local secrets file.** No `cat .secrets*`, no `echo $SECRET`. To verify,
  check presence only: `grep -c '^KEY=' .secrets.<env>`, or a `make secrets-check` target
  that prints key names with set/unset.
- **Never paste a value** into chat, a commit message, a PR description, documentation,
  an ADR, a skill file, a test fixture, an issue tracker, or an MCP/tool configuration
  file. A value that appears in any of those is leaked — run the leak protocol.
- **Never invent a value.** If the key is missing locally, stop and tell the operator
  which key to add and which generation command to run. A fabricated placeholder that
  passes startup validation is worse than a hard failure.
- `[!]` **Never commit agent/tool state directories.** Session, history and
  approval-rules files written by coding agents capture full command payloads and stable
  user identifiers — a real approval-rules file on a developer machine embedded a user
  UUID together with complete command lines. `.gitignore` those directories in the
  project template, and never add one to a commit "for reproducibility".
- **Sync and cloud writes need explicit intent.** `make secrets-sync`, IaC apply, and
  image pushes mutate a shared environment: do not run them as a side effect of another
  task, and never against an environment other than the one named.
- **Be honest about what is wired.** Placeholder deploy targets and unexecuted scripts
  are placeholders — do not claim SECRET_MANAGER is populated, or that a service reads a
  secret, until the sync has actually run and a pod has started with it.

## 10. Scanning

- **Pre-commit hook + CI job**, both running a secret scanner (gitleaks or equivalent).
  The hook catches it before it exists; the CI job is what actually holds the line,
  because `--no-verify` exists.
- **Scan history once on adoption.** A scanner added today says nothing about what is
  already in the repo.
- **Allowlist narrowly**: the contract files' obviously-fake placeholders, nothing else.
  Never allowlist a path wholesale — a per-file exemption is how the next real key gets
  in.
- Extend the scan to what the repo generates: fixtures, snapshot tests, `.env` copies
  produced by tooling, and committed docs.
- The scanner is part of the project template, not something added after the first leak.

## 11. Leak protocol

When a secret is found in the repo, in history, in a log, or in a transcript — regardless
of how briefly it was there — treat it as compromised.

1. **Stop and report first.** State `file:line`, what the credential is, where it is
   valid, how long it has been exposed, and who could have read it. Report before
   quietly fixing: the blast radius decides whether this is a commit or an incident.
2. **Fix the code path.** Remove the literal, replace it with the secret reference, add
   the key to the contract file with its comment and generation command.
3. **Rotate.** Mint a new value, sync, roll the consumers, and **revoke the old value at
   the issuer** (section 7). Deleting the commit does not rotate anything; a value that
   was ever pushed must be assumed harvested.
4. **Sweep for the same pattern.** Grep the codebase, the other environments, git
   history, chart values, CI configuration, docs, and agent transcripts for the same
   credential and for the same *class* of mistake — one hardcoded key usually means the
   pattern was copied.
5. **Record it** in the project's known-issues or incident notes, without the value:
   what leaked, when, rotation timestamp, what stopped the class of mistake. If the
   `incident-response` skill is installed, follow it for anything with production blast
   radius; otherwise follow the project's own incident process.
6. **History rewriting is optional and last.** It is disruptive, it never reaches forks,
   caches and mirrors, and it is not a substitute for rotation.

If the `code-reviewer`/`security-reviewer` agents are installed, they enforce steps 1 and
4 on every review of sensitive code; otherwise make this checklist part of the review.

## Vendor delta

The `cloud/<vendor>` skill must supply, per capability:

- **SECRET_MANAGER** — the concrete service; vault/entry naming and per-service scoping;
  the CLI or API the sync command drives; whether empty values are dropped; size, count
  and versioning limits; how to roll back an entry.
- **Cluster sync mechanism** — the operator or CSI driver used, its installation, the
  store/credential wiring, its refresh interval and how to force a refresh, the list
  object that declares expected keys, and the naming agreement between that object and
  the deployment template (a known trap). Any egress or image-mirroring requirement for
  the operator's own image belongs here too.
- **IAM** — which identity may write versus read secrets, the least-privilege binding,
  and how to mint a short-lived token instead of storing a static key.
- **TFSTATE_BACKEND** — the exact credential environment variable names the IaC env
  contract must export, and the bootstrap step that prints them.
- **MANAGED_PG** — the DSN shape: pooler host and port, required SSL mode, and whether a
  CA file must be mounted for the driver in use.

## Project delta

The consuming repo supplies:

- Contract file names and environment suffixes (`.secrets.example` → `.secrets.<env>`;
  which environments exist).
- The sync command and its environment argument (`make secrets-sync ENV=<env>`), and who
  is allowed to run it against which environment.
- SECRET_MANAGER vault/entry naming for this project, and which service owns which key.
- Namespace, release names, and whether the runtime secret is per-service or shared.
- The secret scanner and its config path, plus the pre-commit and CI wiring.
- The additional sensitive data classes that inherit the no-logging rule.
- The startup-validation location — where each service asserts its required keys.
