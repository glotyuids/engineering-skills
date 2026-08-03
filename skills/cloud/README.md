# Pack: Yandex Cloud

Resolves every capability the `infra` pack names to a concrete Yandex Cloud service, and carries the traps that cost real production incidents.

## Skills

- [`yandex-cloud`](yandex-cloud/SKILL.md)

## Expects

`infra` (or your own infra skills that speak the same capability names).

## Soft companions

`infra` — companions are suggestions, not requirements. Every skill here works with the
companion pack absent; cross-pack references are written to degrade gracefully.

## Notes

This is the only pack allowed to name a cloud vendor. If you add another cloud, add a sibling pack — the generic skills must not change.

---

Install: `/plugin install cloud-yandex@engineering-skills`, or
`./scripts/install.sh <project> --packs cloud-yandex`, or ask your agent to install the
**cloud-yandex** pack from `glotyuids/engineering-skills`.
