# Contributing

The full authoring contract lives in [AGENTS.md](AGENTS.md) — it applies to humans and
agents alike. This page is the short version plus the PR checklist.

## Adding or changing a skill

1. Skills live at `skills/<pack>/<skill-name>/SKILL.md`. The directory name and the
   frontmatter `name` must match.
2. Frontmatter carries `name`, `description`, `license`, and `metadata` with `source` and
   `version` — nothing tool-specific.
3. Keep the body under 500 lines; move depth into `references/*.md` next to the skill.
4. Generic skills must not name a cloud provider. Provider detail belongs in
   `skills/cloud/<vendor>/`. See the three-layer rule in AGENTS.md.
5. Update [`manifest.json`](manifest.json) in the same commit if you add, rename or
   remove a skill, and add a [CHANGELOG](CHANGELOG.md) entry.
6. Run `./scripts/validate.sh`.

## PR checklist

- [ ] `./scripts/validate.sh` passes (spec conformance, manifest agreement, content policy)
- [ ] No hostnames, cluster IDs, tokens, absolute local paths, or personal data
- [ ] Cross-pack references are soft ("if X is installed…"), and every referenced skill exists
- [ ] Generic skill: has a `## Project delta` section; infra skill: also `## Vendor delta`
- [ ] `metadata.version` bumped, CHANGELOG updated
- [ ] `[!]` used only for rules that caused a real production incident
- [ ] Prose is English, including in `lang-ru`

## Adding a cloud vendor

Add `skills/cloud/<vendor>/SKILL.md` mapping every capability in the table in
`skills/infra/README.md` to a concrete service, plus that vendor's traps and bootstrap
steps. Add the pack to `manifest.json` with a `provides` array.

If you find yourself editing a generic skill to make the vendor fit, stop — the capability
contract is wrong, and fixing it there is the actual change.

## Reporting a leak

If anything in this repo identifies a person, names a real host or cluster, or contains a
credential, open an issue immediately or email the maintainer. It will be removed and the
history rewritten if needed.
