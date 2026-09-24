#!/usr/bin/env bash
# Lists unsafe member accesses as `path:line: message`, one per line.
# Usage: scripts/unsafe-hits.sh [res://file.gd ...]   (no args = whole project)
# Exit 1 if any hit. project.godot sets unsafe_*_access to error level; the editor
# import scan does not compile every script, so CI runs this to load them all.
cd "$(dirname "$0")/.."
LOG=$(mktemp)
if [ $# -gt 0 ]; then
  godot --headless --path . -s tests/typecheck/typed_access_probe.gd -- "$@" >"$LOG" 2>&1
else
  godot --headless --path . -s tests/typecheck/typed_access_probe.gd >"$LOG" 2>&1
fi
python3 - "$LOG" <<'PY'
import re,sys
lines=open(sys.argv[1]).read().split('\n')
hits=set()
for i,l in enumerate(lines):
    if 'Parse Error' not in l or i+1>=len(lines): continue
    m=re.search(r'reload \(res://([^:)]*):(\d+)\)',lines[i+1])
    if m: hits.add((m.group(1),int(m.group(2)),l.split('Parse Error: ',1)[1].replace(' (Warning treated as error.)','')))
for h in sorted(hits): print('%s:%d: %s'%h)
sys.exit(1 if hits else 0)
PY
