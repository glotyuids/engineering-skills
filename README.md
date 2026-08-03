# engineering-skills

A tool-agnostic library of engineering skills and guidelines for AI coding agents —
Claude Code, Codex, Cursor, Copilot, Gemini CLI, Lovable and anything else that reads the
[Agent Skills](https://agentskills.io/specification) format.

Install whole **packs**, not the whole library. Take `infra` and `cloud-yandex` and keep
your own Go conventions; take `go` alone; take everything. Skills are layered
**generic → cloud vendor → your project**, so adding AWS later means adding one vendor
pack, not rewriting anything.

## Packs

| Pack | What it gives you |
|---|---|
| `core` | Project bootstrap; architect, planner, code-explorer, code-reviewer, security-reviewer agents |
| `process` | Git workflow, documentation standards (ADRs, runbooks), plan review, integration testing, incident response, de-slopping, a markdown task board, security practice |
| `infra` | CI/CD, Terraform, Ansible, Kubernetes/Helm, Makefiles, secrets — **vendor-neutral**, written against capabilities |
| `cloud-yandex` | Yandex Cloud capability mapping and production traps |
| `go` | Clean-architecture Go conventions, new-service scaffolding, API/event contracts, observability; Go review agents |
| `database` | PostgreSQL patterns, migration discipline; database-reviewer agent |
| `frontend` | React/React Native conventions, design-system authoring, i18n, Playwright e2e |
| `llm` | LLM pipeline safety rules, MCP server authoring, skill authoring |
| `writing` | Purposeful product writing, honesty gates, cover-letter craft and review |
| `lang-ru` | Shipping to the Russian market: plurals and gendered forms, RU/EN tone transfer, RU job-application norms, bilingual product architecture — written in English |

Machine-readable index: [`manifest.json`](manifest.json).

---

## Install

### Option 1 — ask your agent (recommended)

Say this to Claude Code, Codex, Cursor, or any agent with file access:

> Use github.com/glotyuids/engineering-skills and install the **infra** and
> **cloud-yandex** packs into this project.

Other phrasings that work: *"take the go package from …"*, *"set this project up with the
core and process packs"*, *"install everything except frontend"*.

<details>
<summary><strong>Agent: follow this procedure</strong> (this section is the instruction set)</summary>

You are installing packs from this library into the user's project. Do this:

1. **Resolve packs.** Read [`manifest.json`](manifest.json). Match the user's words
   ("infra package", "yandex cloud", "go") to pack `id`s. If ambiguous or unspecified,
   show the pack table and ask which they want. Include each selected pack's `companions`
   in your suggestion, but never install one they did not confirm.
2. **Detect target tools.** Look for `.claude/`, `.cursor/`, `.agents/`, `AGENTS.md`,
   `CLAUDE.md` in the project. Install for every tool you find evidence of. If you find
   none, ask which tools they use.
3. **Copy the skills.** For each selected pack, copy every directory listed in its
   `skills` array from `<skillPath>/<skill>/` into each target tool's skills directory
   from `toolPaths` (project scope: `.claude/skills/`, `.agents/skills/`). Copy whole
   directories — `SKILL.md` plus any `references/`. Use `git clone` if you have a shell,
   otherwise fetch raw files from
   `https://raw.githubusercontent.com/glotyuids/engineering-skills/main/<path>`.
4. **Copy the agents.** If the pack has `agents` and the target tool has a non-null
   `agents` path, copy `<agentPath>/<agent>.md` there. Codex, Copilot and Gemini have no
   subagents — skip them silently.
5. **Never overwrite.** If a skill of the same name already exists in the target, keep
   the user's version, and list the collision in your report. Only overwrite if the user
   explicitly asks.
6. **Stamp provenance.** Each installed `SKILL.md` must keep its `metadata.source` and
   `metadata.version` frontmatter — that is what `scripts/check-drift.sh` compares later.
7. **Wire the always-on layer.**
   - If the project has no `AGENTS.md`, create one from
     [`templates/AGENTS.template.md`](templates/AGENTS.template.md) and fill the
     "Project context" block from what you can observe (language, cloud, cluster context,
     namespace). Leave `TODO` for anything you cannot determine.
   - Add a `Packs:` line recording what was installed.
   - If the project uses Claude Code and has no `CLAUDE.md`, create it containing exactly
     `@AGENTS.md`.
   - Reference **only installed packs** in AGENTS.md. Never mention a skill that is not there.
8. **Report.** List: skills installed and where, agents installed, collisions skipped, and
   which `Project delta` fields the user still needs to fill in.

Do not install `lang-ru` unless the project ships Russian-language UI or content.

</details>

### Option 2 — Claude Code plugin marketplace

```bash
/plugin marketplace add glotyuids/engineering-skills
```

Then install packs individually — `/plugin install infra@engineering-skills`,
`/plugin install cloud-yandex@engineering-skills`. Each pack plugin carries its own skills
and agents.

### Option 3 — script

```bash
git clone https://github.com/glotyuids/engineering-skills && cd engineering-skills
./scripts/install.sh ~/path/to/project --packs infra,cloud-yandex --tools claude,codex
```

Omit `--packs` for an interactive picker. `--user` installs to `~/.claude/skills` etc.
instead of into a project. `--dry-run` shows what would happen.

### Option 4 — copy the directories

Packs are plain directories. `cp -r skills/infra/* /path/to/project/.agents/skills/`.

### Lovable

Lovable reads the root `AGENTS.md` of a connected repo automatically — that is the main
integration. For skills, zip a pack directory and upload it in workspace
Settings → Skills.

---

## First use in a blank project

After installing `core`, tell your agent: **"bootstrap this project"**. The
[`bootstrap-project`](skills/meta/bootstrap-project/SKILL.md) skill asks about your stack,
instantiates the templates (AGENTS.md with a filled Project context block, `CLAUDE.md`
pointer, `docs/` tree with ADR and runbook templates, Makefile, `.secrets.example`,
`.gitignore`), and tells you what is left to fill in.

## How the layers fit

```
generic skill        infra/secrets-management   "values never enter git; the
                                                 SECRET_MANAGER capability holds them"
        ↓ Vendor delta
vendor skill         cloud/yandex-cloud         "SECRET_MANAGER = Lockbox + External
                                                 Secrets Operator; [!] the ExternalSecret
                                                 name must match the Helm template"
        ↓ Project delta
your project         AGENTS.md                  "Cloud: yandex-cloud, namespace: acme-prod"
```

Generic skills never name a vendor. Vendor skills never name your project.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) and [AGENTS.md](AGENTS.md) (the rules agents follow
when working on this repo). Improvements go upstream first — never hand-edit an installed
copy.

## Licence

[Apache-2.0](LICENSE).
