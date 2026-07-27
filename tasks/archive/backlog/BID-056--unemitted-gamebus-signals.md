# BID-056: GameBus signals declared but never emitted

Category: code-smell
Discovered during: GID-124 research (GameBus declared-vs-used audit)
Status: **resolved** by GID-125 / TID-474

## Correction to the original filing

This item was first filed naming **three** dangling signals:
`exited_to_world`, `world_event_started`, `world_event_ended`.

That was wrong. The audit grep only matched the typed `GameBus.<name>.emit(...)`
form. `world_event_started` and `world_event_ended` **are** emitted — from
`autoloads/WorldEventManager.gd:99,116`, using the string form on a cached
reference:

```gdscript
_game_bus.emit_signal("world_event_started", id)
```

Both also have live subscribers in `AppLog.gd`. Only **`exited_to_world`** was
genuinely dangling.

## Confirmed defect

`exited_to_world` is the counterpart to `entered_named_map` in GameBus's
"Ambient audio signals" block. `entered_named_map` is emitted from
`WorldScene._ready()` on the named-map branch and logged by `AppLog`;
`exited_to_world` was never emitted by anything, so any subscriber would see the
player enter named maps and never come back out.

## Secondary finding

Five call sites use `emit_signal("name", ...)` rather than `name.emit(...)`. The
string form is **not compile-checked**: a typo emits nothing and raises nothing,
failing completely silently. All five currently name valid signals.

## Resolution — see GID-125 / TID-474

- `WorldScene._ready()` emits `exited_to_world` on the infinite-world branch.
- `AppLog` subscribes, for symmetry with `entered_named_map`.
- `tests/unit/test_gamebus_signal_coverage.gd` guards all three directions and
  both emission spellings so the class cannot regress.
