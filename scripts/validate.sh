#!/usr/bin/env bash
# Validate the library: spec conformance, manifest agreement, content policy.
set -euo pipefail
cd "$(dirname "$0")/.."
exec python3 scripts/validate.py "$@"
