#!/bin/bash
# Balance matrix (GID-176 / TID-718): each Chapter 1 enemy type over its level
# range, player level L vs enemy level L (+0) and L + 1 (+1). Prints win rates.
#   bash tools/balance_matrix.sh ["knob=v,knob=v"] [fights per cell, default 30]
cd "$(dirname "$0")/.." || exit 1
T="$1"; N=${2:-30}
for e in undead_basic:1,2 undead_horde:2,3,4 ghoul_pack:3,4,5 wolf_pack:4,5,6 forest_shade:5,6,7,8 bog_hag:6,7,8 imbued_stag:7,8,9 martarquas_scout:8,9,10; do
 t=${e%%:*}; l=${e#*:}
 for o in 0 1; do
  echo -n "$t +$o: "
  godot --headless --path . -s tools/balance_sim.gd -- --fights $N --csv none --enemy $t --sweep level=$l --enemy-offset $o ${T:+--tune $T} 2>&1 | grep "level=" | sed 's/\[ *\([0-9.]*\)- *\([0-9.]*\)\]/[\1-\2]/' | awk '{printf "%s %s | ", $2, $4}'; echo
 done
done
