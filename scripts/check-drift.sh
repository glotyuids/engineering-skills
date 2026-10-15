#!/usr/bin/env bash
#
# Compare skills installed in a project against this library.
#
#   ./scripts/check-drift.sh /path/to/project
#   ./scripts/check-drift.sh --user
#
# Reports, per installed skill: IN SYNC, MODIFIED (hand-edited — fix upstream instead),
# STALE (library has a newer version), or UNKNOWN (not from this library).
#
# Exit 1 if anything is MODIFIED or STALE.
set -euo pipefail

LIB="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${1:-}"
[ "$TARGET" = "--user" ] && TARGET="$HOME"
[ -n "$TARGET" ] || { echo "usage: $0 <project-dir>|--user" >&2; exit 2; }

command -v python3 >/dev/null 2>&1 || { echo "python3 is required" >&2; exit 2; }

python3 - "$LIB" "$TARGET" <<'PY'
import hashlib, json, re, sys
from pathlib import Path

lib, target = Path(sys.argv[1]), Path(sys.argv[2])
manifest = json.loads((lib / "manifest.json").read_text())

# Where installed skills can live, across tools.
search = [".claude/skills", ".agents/skills", ".cursor/skills", ".codex/skills",
          ".github/skills", "skills"]

# The library's source stamp. Copies installed before the GitHub account was renamed carry
# the former owner's name; they are the same library, and the stamp alone is not a change.
SOURCE = "sudo-sane/engineering-skills"
FORMER_SOURCES = ("glotyuids/engineering-skills",)

def restamped(text):
    for old in FORMER_SOURCES:
        text = text.replace(f"source: {old}", f"source: {SOURCE}")
    return text

def version_of(text):
    m = re.search(r"^\s+version:\s*(\S+)", text, re.M)
    return m.group(1) if m else None

def body_hash(path):
    return hashlib.sha256(restamped(path.read_text()).encode()).hexdigest()[:12]

# Index the library by skill name.
library = {}
for pack in manifest["packs"]:
    for skill in pack["skills"]:
        p = lib / pack["skillPath"] / skill / "SKILL.md"
        if p.exists():
            t = p.read_text()
            library[skill] = {"path": p, "version": version_of(t), "hash": body_hash(p),
                              "pack": pack["id"]}

rows, bad = [], 0
seen = set()
for base in search:
    d = target / base
    if not d.is_dir():
        continue
    for md in sorted(d.glob("*/SKILL.md")):
        name = md.parent.name
        key = (base, name)
        if key in seen:
            continue
        seen.add(key)
        text = md.read_text()
        if not any(s in text for s in (SOURCE,) + FORMER_SOURCES):
            rows.append((base, name, "UNKNOWN", "not from this library"))
            continue
        entry = library.get(name)
        if not entry:
            rows.append((base, name, "ORPHAN", "no longer in the library"))
            bad += 1
            continue
        inst_v, inst_h = version_of(text), body_hash(md)
        if inst_h == entry["hash"]:
            note = f"v{inst_v}" + (", former source stamp — reinstall to restamp" if restamped(text) != text else "")
            rows.append((base, name, "IN SYNC", note))
        elif inst_v != entry["version"]:
            rows.append((base, name, "STALE", f"installed v{inst_v} < library v{entry['version']} — reinstall"))
            bad += 1
        else:
            rows.append((base, name, "MODIFIED", f"v{inst_v} hand-edited — move the change upstream"))
            bad += 1

if not rows:
    print(f"no skills from this library found under {target}")
    sys.exit(0)

w = max(len(r[1]) for r in rows) + 2
for base, name, status, note in rows:
    print(f"{status:<9} {name:<{w}} {note}   [{base}]")

print(f"\n{len(rows)} installed, {bad} needing attention")
sys.exit(1 if bad else 0)
PY
