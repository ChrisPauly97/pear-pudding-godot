# BID-056: Three more GameBus signals declared but never emitted

Category: code-smell
Discovered during: GID-123 research (GameBus declared-vs-used audit)

## Summary

An audit cross-referencing every `signal` in `autoloads/GameBus.gd` against
every `GameBus.<name>.emit(...)` in the tree found three signals that are
declared but never emitted anywhere:

- `exited_to_world`
- `world_event_started`
- `world_event_ended`

This is the same defect class as BID-006 (fixed by GID-124 / TID-468), which
covered `card_played` / `card_attacked` / `battle_ended` but not these.

## Audit method (reproducible)

```bash
grep -oE "^signal [a-z0-9_]+" autoloads/GameBus.gd | awk '{print $2}' | sort > declared
grep -rhoE "GameBus\.[a-z0-9_]+\.(connect|emit|disconnect|is_connected)" --include=*.gd . \
  | sed -E 's/GameBus\.([a-z0-9_]+)\..*/\1/' | sort -u > used
comm -13 declared used     # used but not declared — currently empty (good)
for s in $(cat declared); do grep -rqE "GameBus\.$s\.emit" --include=*.gd . || echo "$s"; done
```

The reverse direction — a signal *used* but not *declared* — is currently clean.
That case is the dangerous one: per CLAUDE.md's "Dead signal connect aborted
`_ready`" learning, connecting to a nonexistent GameBus signal throws and
silently kills every statement appended after it in `_ready`.

## Notes

`world_event_started` / `world_event_ended` pair with GID-039 (Living World
Events); check whether that system emits equivalents under different names
before wiring or removing. `exited_to_world` likely overlaps `SceneManager`'s
map-stack pop path.

## Suggested resolution

For each: wire the emission at the correct point, or delete the declaration.
Do not leave them half-present — a declared-but-silent signal reads as working
to any future subscriber and under-reports instead of failing loudly.

Consider adding the audit above as a unit test so the class cannot regress.

## Acceptance

- Every `GameBus` signal is either emitted somewhere or removed.
- A test enforces it.
