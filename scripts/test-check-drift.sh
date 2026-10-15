#!/usr/bin/env bash
#
# Behaviour tests for check-drift.sh: verdicts, and copies stamped with the owner's former
# account name (glotyuids, renamed to sudo-sane) counting as this library.
#
#   ./scripts/test-check-drift.sh
set -euo pipefail

LIB="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
n=0 fail=0

check() {  # check <name> <expected exit> <output> <exit> <pattern>...
  local name="$1" want="$2" out="$3" got="$4"; shift 4
  n=$((n+1))
  if [ "$got" != "$want" ]; then
    echo "FAIL $name: exit $got, want $want"; echo "$out"; fail=$((fail+1)); return
  fi
  for pat in "$@"; do
    if ! printf '%s\n' "$out" | grep -Eq -- "$pat"; then
      echo "FAIL $name: no line matching /$pat/"; echo "$out"; fail=$((fail+1)); return
    fi
  done
}

install_copy() {  # install_copy <project> <skill> <pack dir> [source]
  local d="$1/.claude/skills/$2"
  mkdir -p "$d"
  cp "$LIB/skills/$3/$2/SKILL.md" "$d/SKILL.md"
  if [ -n "${4:-}" ]; then
    sed -i.bak "s|^  source: .*|  source: $4|" "$d/SKILL.md" && rm "$d/SKILL.md.bak"
  fi
}

run() { set +e; out="$("$LIB/scripts/check-drift.sh" "$1" 2>&1)"; code=$?; set -e; }

# Current stamp, former stamp, and a foreign skill: all clean.
P="$TMP/clean"
install_copy "$P" git-workflow process
install_copy "$P" deslop process glotyuids/engineering-skills
mkdir -p "$P/.claude/skills/my-own" && printf -- '---\nname: my-own\nmetadata:\n  source: me/mine\n---\n' > "$P/.claude/skills/my-own/SKILL.md"
run "$P"
check "current stamp in sync" 0 "$out" "$code" '^IN SYNC +git-workflow +v[0-9.]+ +\['
check "former stamp in sync, not modified" 0 "$out" "$code" '^IN SYNC +deslop +v[0-9.]+, former source stamp'
check "foreign skill unknown" 0 "$out" "$code" '^UNKNOWN +my-own'

# A hand edit under the former stamp is still a hand edit.
P="$TMP/edited"
install_copy "$P" review-plan process glotyuids/engineering-skills
printf '\nlocal edit\n' >> "$P/.claude/skills/review-plan/SKILL.md"
run "$P"
check "former stamp hand-edited is modified" 1 "$out" "$code" '^MODIFIED +review-plan'

# An older version under the former stamp is stale.
P="$TMP/stale"
install_copy "$P" kanban-md process glotyuids/engineering-skills
sed -i.bak 's|^  version: .*|  version: 0.0.1|' "$P/.claude/skills/kanban-md/SKILL.md" && rm "$P/.claude/skills/kanban-md/SKILL.md.bak"
run "$P"
check "former stamp older version is stale" 1 "$out" "$code" '^STALE +kanban-md +installed v0.0.1'

echo "$((n-fail))/$n passed"
[ "$fail" -eq 0 ]
