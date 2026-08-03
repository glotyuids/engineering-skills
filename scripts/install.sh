#!/usr/bin/env bash
#
# Install skill packs from this library into a project (or into your user-level
# agent directories).
#
#   ./scripts/install.sh <target-dir> --packs infra,cloud-yandex --tools claude,codex
#   ./scripts/install.sh --user --packs core,process --tools claude
#   ./scripts/install.sh <target-dir>                    # interactive pack picker
#   ./scripts/install.sh <target-dir> --packs go --dry-run
#
# Copies, never symlinks: symlinked skill directories are unreliable across agent tools.
# Never overwrites an existing skill of the same name unless --force is given.
set -euo pipefail

LIB="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$LIB/manifest.json"

TARGET=""
PACKS=""
TOOLS=""
USER_SCOPE=0
DRY_RUN=0
FORCE=0

die() { echo "error: $*" >&2; exit 1; }
have_jq() { command -v jq >/dev/null 2>&1; }

# Minimal jq-free JSON query via python3 (present on every supported platform).
q() { python3 -c "
import json,sys
m=json.load(open('$MANIFEST'))
$1" "$@"; }

usage() {
  sed -n '3,14p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --packs) PACKS="${2:-}"; shift 2 ;;
    --tools) TOOLS="${2:-}"; shift 2 ;;
    --user) USER_SCOPE=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage 0 ;;
    -*) die "unknown flag $1 (try --help)" ;;
    *) TARGET="$1"; shift ;;
  esac
done

command -v python3 >/dev/null 2>&1 || die "python3 is required"
[ -f "$MANIFEST" ] || die "manifest.json not found at $MANIFEST"

if [ "$USER_SCOPE" -eq 1 ]; then
  TARGET="${TARGET:-$HOME}"
else
  [ -n "$TARGET" ] || usage 1
  [ -d "$TARGET" ] || die "target directory does not exist: $TARGET"
fi

ALL_PACKS=$(q "print(' '.join(p['id'] for p in m['packs']))")

# ---- pack selection --------------------------------------------------------
if [ -z "$PACKS" ]; then
  echo "Available packs:"
  q "
for p in m['packs']:
    print(f\"  {p['id']:<14} {p['description']}\")"
  echo
  printf 'Packs to install (comma-separated, or "all"): '
  read -r PACKS </dev/tty
fi
[ "$PACKS" = "all" ] && PACKS=$(echo "$ALL_PACKS" | tr ' ' ',')

for p in ${PACKS//,/ }; do
  case " $ALL_PACKS " in *" $p "*) ;; *) die "unknown pack '$p' (have: $ALL_PACKS)" ;; esac
done

# ---- tool selection --------------------------------------------------------
if [ -z "$TOOLS" ]; then
  detected=""
  [ -d "$TARGET/.claude" ] && detected="claude"
  [ -d "$TARGET/.cursor" ] && detected="${detected:+$detected,}cursor"
  { [ -d "$TARGET/.agents" ] || [ -f "$TARGET/AGENTS.md" ]; } && detected="${detected:+$detected,}codex"
  if [ -n "$detected" ]; then
    TOOLS="$detected"
    echo "Detected tools: $TOOLS"
  else
    printf 'Tools (claude,codex,cursor,copilot,gemini): '
    read -r TOOLS </dev/tty
  fi
fi

echo
echo "Library : $LIB"
echo "Target  : $TARGET$([ "$USER_SCOPE" -eq 1 ] && echo ' (user scope)')"
echo "Packs   : $PACKS"
echo "Tools   : $TOOLS"
[ "$DRY_RUN" -eq 1 ] && echo "MODE    : dry run"
echo

installed=0; skipped=0; collisions=""

copy_dir() { # src dst label
  local src="$1" dst="$2" label="$3"
  if [ -e "$dst" ] && [ "$FORCE" -eq 0 ]; then
    collisions="${collisions}  $label -> $dst (kept existing)\n"
    skipped=$((skipped + 1)); return
  fi
  echo "  + $label -> ${dst#"$TARGET"/}"
  if [ "$DRY_RUN" -eq 0 ]; then
    mkdir -p "$(dirname "$dst")"
    rm -rf "$dst"
    cp -R "$src" "$dst"
  fi
  installed=$((installed + 1))
}

for pack in ${PACKS//,/ }; do
  echo "pack: $pack"
  skill_path=$(q "print(next(p for p in m['packs'] if p['id']=='$pack')['skillPath'])")
  skills=$(q "print(' '.join(next(p for p in m['packs'] if p['id']=='$pack')['skills']))")
  agent_path=$(q "p=next(p for p in m['packs'] if p['id']=='$pack'); print(p.get('agentPath',''))")
  agents=$(q "p=next(p for p in m['packs'] if p['id']=='$pack'); print(' '.join(p.get('agents',[])))")

  for tool in ${TOOLS//,/ }; do
    key=$([ "$USER_SCOPE" -eq 1 ] && echo userSkills || echo skills)
    sdir=$(q "t=m['toolPaths'].get('$tool'); print(t['$key'] or '' if t else '')")
    [ -n "$sdir" ] || continue
    sdir="${sdir/#\~/$HOME}"
    case "$sdir" in /*) dest_base="$sdir" ;; *) dest_base="$TARGET/$sdir" ;; esac
    for s in $skills; do
      [ -d "$LIB/$skill_path/$s" ] || { echo "  ! missing in library: $skill_path/$s"; continue; }
      copy_dir "$LIB/$skill_path/$s" "$dest_base/$s" "$s"
    done

    akey=$([ "$USER_SCOPE" -eq 1 ] && echo userAgents || echo agents)
    adir=$(q "t=m['toolPaths'].get('$tool'); print((t.get('$akey') or '') if t else '')")
    if [ -n "$adir" ] && [ -n "$agents" ]; then
      adir="${adir/#\~/$HOME}"
      case "$adir" in /*) adest="$adir" ;; *) adest="$TARGET/$adir" ;; esac
      for a in $agents; do
        [ -f "$LIB/$agent_path/$a.md" ] || continue
        copy_dir "$LIB/$agent_path/$a.md" "$adest/$a.md" "agent $a"
      done
    fi
  done
done

# ---- always-on layer -------------------------------------------------------
if [ "$USER_SCOPE" -eq 0 ] && [ "$DRY_RUN" -eq 0 ]; then
  if [ ! -f "$TARGET/AGENTS.md" ]; then
    cp "$LIB/templates/AGENTS.template.md" "$TARGET/AGENTS.md"
    echo
    echo "  + AGENTS.md created from template — fill in the Project context block"
  fi
  if ! grep -q '^Packs:' "$TARGET/AGENTS.md" 2>/dev/null; then
    printf '\nPacks: %s (from glotyuids/engineering-skills)\n' "$PACKS" >> "$TARGET/AGENTS.md"
  fi
  case ",$TOOLS," in
    *,claude,*)
      if [ ! -f "$TARGET/CLAUDE.md" ]; then
        echo '@AGENTS.md' > "$TARGET/CLAUDE.md"
        echo "  + CLAUDE.md created (imports AGENTS.md)"
      fi ;;
  esac
fi

echo
echo "installed: $installed   skipped: $skipped"
if [ -n "$collisions" ]; then
  echo
  echo "existing skills kept (use --force to overwrite):"
  printf "%b" "$collisions"
fi
echo
echo "Next: fill the Project context block in AGENTS.md, then check each installed skill's"
echo "'Project delta' section for values it needs."
