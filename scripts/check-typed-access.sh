#!/usr/bin/env bash
# Fails if any script reads, writes or calls a member that does not exist on a
# *project-script* type (GDScript: "... not present on the inferred type
# "res://..."). This is how a typo in a module's back-reference (`_world.X`,
# `_battle.X`, `_sm.X`, `_save.X`, all typed as their owner script) is caught
# before runtime. Accesses on engine or Variant types (~2.8k, legitimately
# dynamic) are ignored.
set -uo pipefail
cd "$(dirname "$0")/.."
if [ -e override.cfg ]; then
  echo "override.cfg already exists at the project root; refusing to overwrite it." >&2
  exit 2
fi
cp tests/typecheck/override.cfg override.cfg
trap 'rm -f override.cfg' EXIT
LOG=$(mktemp)
godot --headless --path . -s tests/typecheck/typed_access_probe.gd >"$LOG" 2>&1
HITS=$(grep -A1 'inferred type "res://' "$LOG" || true)
if [ -n "$HITS" ]; then
  echo "Access to a member that does not exist on a project script:"
  echo "$HITS"
  exit 1
fi
echo "Typed access clean."
