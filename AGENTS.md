# Contributing agent guide — engineering-skills

You are working **on** this library. If you were asked to *install* skills from it into
another project, read [README.md](README.md) instead — that is the consumer procedure.

## What this repo is

A tool-agnostic library of engineering skills and guidelines, installed into projects that
use Claude Code, Codex, Cursor, Copilot, Gemini CLI, Lovable and similar agents. Everything
here is public — assume every file will be read by strangers.

## Skill format (non-negotiable)

Every skill is a directory `skills/<pack>/<skill-name>/SKILL.md` conforming to the
[Agent Skills spec](https://agentskills.io/specification):

```markdown
---
name: skill-name          # MUST equal the directory name; a-z0-9- only
description: What it does + when to use it, with trigger phrases. Max 1024 chars.
license: Apache-2.0
metadata:
  source: glotyuids/engineering-skills
  version: 0.1.0
---
```

- `name` and `description` are the only required fields. `description` is how an agent
  decides to load the skill — write "what + when", include the words a user would say.
- Body under 500 lines. Longer material goes in `references/*.md` beside the SKILL.md,
  one level deep, linked relatively.
- **No tool-specific frontmatter** (`model`, `tools`, `allowed-tools`, `argument-hint`,
  `user-invocable`, `paths`). Those are Claude/Cursor extensions; portable skills omit them.
- Run `scripts/validate.sh` before committing.

## The three-layer rule

Skills are layered **generic → vendor → project**. Never collapse the layers.

- **Generic skills** (`skills/infra/`, `skills/go/`, …) describe the pattern against named
  capabilities (`SECRET_MANAGER`, `MANAGED_PG`, `REGISTRY`, `TFSTATE_BACKEND`, `MANAGED_K8S`,
  `LB`, `IAM`). They must not name a cloud provider except as an explicitly labelled
  illustration.
- **Vendor skills** (`skills/cloud/<vendor>/`) map every capability to a concrete service
  and carry that vendor's traps.
- **Project delta** is what the consuming repo supplies (namespace, cluster context, module
  prefix). Every generic skill ends with a `## Project delta` section naming exactly what
  it expects; infra skills also carry `## Vendor delta`.

Acceptance test: **onboarding a new cloud = adding `skills/cloud/<vendor>/` and changing
zero generic skills.** If a generic skill needs an edit when a vendor is added, the
capability contract was violated.

## Packs and partial installs

A pack (a directory under `skills/`) is the unit of installation. Users install `infra`
without `go`. Therefore:

1. **Cross-pack references are soft.** Write "If the `go-conventions` skill is installed,
   follow it; otherwise follow the project's own conventions." Hard by-name references are
   allowed only within a pack. Never reference a skill that does not exist.
2. **No language assumptions outside language packs.** `infra/cicd-build-deploy` says
   "`make build` produces the artifacts", not "compiles the Go binary".
3. **Every pack has a `README.md` manifest** — what it provides, capabilities expected,
   soft companions.
4. **`manifest.json` is the source of truth** for pack contents. Update it in the same
   commit as any skill added, renamed or removed; `scripts/validate.sh` enforces agreement.

## Content policy (public repo)

Forbidden anywhere in the repo — CI greps for these:

- Hostnames, cluster IDs, namespaces, registry IDs, IP addresses, tokens, secrets.
- Absolute local paths (`/Users/…`, `/home/…`).
- Real personal data: names, employers, job history, contact details. This library never
  contains material about an identifiable individual.
- Verbatim customer or product copy, live production URLs.

Allowed: concrete examples, clearly labelled as examples, with placeholder identifiers
(`<service>`, `example.com`, `my-cluster`).

## House conventions

- **English prose everywhere**, including the `lang-ru` pack — it is written *in English
  about Russian*, with Russian appearing only as data (examples in guillemets or code
  blocks). The audience is any developer shipping to that market, most of whom
  read English; keeping one prose language also keeps the library reviewable.
- **`[!]` marks a rule that caused a real production incident when missed.** Do not use it
  decoratively; it is the highest-signal marker in the library.
- **Be honest about maturity.** If something is authored but never executed, say so
  (`Verify:` / `Not an issue:` prefixes, borrowed from the KNOWN_ISSUES pattern).
- Prefer tables for lookup material, numbered phases for procedures, checkboxes for
  definitions-of-done.
- Skills state their own scope boundary explicitly ("this skill defines only …").

## Upstream-first

Improvements discovered while using an installed copy in some project are made **here**
first, then re-installed. Never hand-edit an installed copy: `scripts/check-drift.sh`
exists to catch exactly that, comparing the `metadata.version` and content hash of
installed skills against the library.

Bump `metadata.version` on any content change and add a CHANGELOG entry.

## Evals

Complex or judgment-heavy skills ship `evals/evals.json`: assertion-based cases, run
with-skill vs without-skill, graded on pass rate, time and tokens. Include at least one
**negative case** (the skill must refuse or not fabricate). Convention skills may skip
evals but must pass `scripts/validate.sh`.
