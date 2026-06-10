# TID-221: Alignment resolution + dual-face CardData model, face chosen at battle start

**Goal:** GID-062
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Dual-faced cards resolve as their Light or Dark face depending on the player's
corruption/redemption alignment, decided once at battle start and fixed for the whole
battle. This task builds the data model (how a `CardData` references its two faces) and
the alignment-resolution logic, so TID-222 (UI flip + inspect) and TID-223 (6 card
resources) can build on it. The moral currencies already exist on SaveManager but today
only gate cross-magic skill purchases — this is the first battle-facing use of them.

Design decisions deferred to the Plan phase of this task:
- Face model: (a) two linked `CardData` resources via `light_face_id` / `dark_face_id`
  fields, or (b) embedded `dark_*` mirror fields in one resource (trade-offs below).
- Tie rule: corruption == redemption defaults to Light, or to the last-chosen face.

## Research Notes

### Alignment input — exact location and semantics

The currencies live on the **SaveManager autoload** (`autoloads/SaveManager.gd`):

- `var corruption_points: int = 0` — line 93 (save schema v13)
- `var redemption_points: int = 0` — line 94 (save schema v13)
- Migration defaults: lines 310–311 (`if not data.has("corruption_points"): ...`)
- Load: lines 406–407; serialize: lines 455–456
- Mutators: `add_corruption_points(amount)` (line 783) and `add_redemption_points(amount)`
  (line 788) — both mark dirty and emit `GameBus.corruption_points_changed(new_amount)` /
  `GameBus.redemption_points_changed(new_amount)` (`autoloads/GameBus.gd:39-40`)
- Spent by `unlock_cross_skill(id, cost, currency)` around lines 773–779
- Semantics: corruption is earned via dark dialogue choices, redemption via light ones
  (earn wiring is stubbed per `docs/agent/skill-trees.md`). Both are non-negative ints,
  default 0. A fresh save has 0/0 — the tie rule therefore decides the default face for
  every new player.
- Access pattern used throughout battle code: `SceneManager.save_manager.<field>`
  (see `BattleScene.gd:109`, `:118`). `SkillTreeScene.gd:268,351` reads them directly.
- Note: `SaveManager.magic_type` (`""` until chosen, then `"light"`/`"dark"`) is a
  related but DIFFERENT signal — alignment for this feature is the CP-vs-RP comparison,
  not `magic_type`.

### CardData model (`data/CardData.gd`, `class_name CardData extends Resource`)

Existing exported fields (note the name field is `card_name`, NOT `display_name`):
`id`, `card_name`, `cost`, `attack`, `health`, `card_class` ("minion"/"spell"/"legendary"),
`description`, `color: Color`, `magic_type` ("light"/"dark"/""), `magic_branch`
("ember"/"dawn"/"dusk"/"ash"/""), `spell_effect`, `spell_power`, `auto_resolve`,
`emergence_effect`, `emergence_power`, `keywords: PackedStringArray`, `can_craft`,
`is_unique`. `to_template_dict()` converts to the Dictionary that `CardInstance.new(tmpl)`
consumes (key `"name"` maps from `card_name`).

New `@export` fields must have backward-compatible defaults (`""` / `false`) so the 46
existing `.tres` files in `data/cards/` need no edits — `.tres` omitting a property is
safe (cf. `keywords` rollout, `docs/agent/battle-system.md`).

### Face-model trade-offs (decide in Plan)

**(a) Linked resources** — add `light_face_id: String = ""` and `dark_face_id: String = ""`
to CardData; a dual card is a thin "shell" whose two faces are ordinary CardData `.tres`
files. Pros: faces reuse ALL existing machinery (templates, spell dispatch, inspect,
stat scaling in `PlayerState.build_deck`); face definitions stay editable as normal
cards. Cons: 3 `.tres` files per dual card (18 for TID-223); face resources must be
hidden from every "all cards" surface (see below); registry lookups need one indirection.

**(b) Embedded fields** — mirror every gameplay field as `dark_*` (`dark_card_name`,
`dark_cost`, `dark_attack`, `dark_health`, `dark_spell_effect`, `dark_spell_power`,
`dark_emergence_effect`, `dark_emergence_power`, `dark_keywords`, `dark_description`,
`dark_color`, ...) with the base fields acting as the Light face. Pros: 1 file per card,
nothing to hide, registry untouched. Cons: ~12 new fields on CardData,
`to_template_dict()` needs a face parameter or a second method, and any future CardData
field must be mirrored manually.

**Surfaces that enumerate all cards** (must not show hidden face resources if model (a)
is chosen): `ShopScene.gd:99` (`for id in CardRegistry.get_all_ids()`),
`CraftingRegistry.gd:13` (same loop), `EnemyRegistry.get_drop_pool(enemy_type)` (drop
pools are explicit id lists — just don't list face ids), and
`tests/unit/test_card_registry.gd:25-26` which hard-codes the registry count
(`assert_eq(_registry.get_all_ids().size(), 40)` — already stale vs 46 preloads; verify
and fix while touching it). Existing precedent for filtering:
`CardRegistry.is_unlocked()` (line 108) gates legendaries out of the shop; `can_craft =
false` gates crafting. A `face_only: bool` export + filtering in `get_all_ids()` (or a
`get_all_ids(include_faces)` default arg) follows the same pattern.

### Where to resolve the face at battle start

`BattleScene._ready()` (`scenes/battle/BattleScene.gd:103-151`), fresh-battle branch:
1. `player_deck = SceneManager.save_manager.get_deck_template_ids()` (SaveManager.gd:631 —
   maps owned instance UIDs → template ids)
2. `_state.players[0].build_deck(player_deck)` → `PlayerState.build_deck`
   (`game_logic/battle/PlayerState.gd:26`) calls `CardRegistry.get_template(cid)` per id
   and appends `CardInstance.new(tmpl)` (note: there is no `from_template()` despite the
   doc's wording — construction is `CardInstance._init(tmpl)`).

Recommended seam: a static helper, e.g. `CardRegistry.resolve_face(id, dark: bool) ->
String` (model a) or a face-aware `get_template(id, face)` (model b), called from a small
alignment helper (`is_dark_aligned() -> bool` comparing
`SceneManager.save_manager.corruption_points` vs `redemption_points`). Resolution can
happen by mapping the deck id list in `BattleScene._ready()` before `build_deck`, which
keeps `PlayerState`/`GameState` battle logic alignment-agnostic. The enemy deck path
(`BattleScene.gd:137-140`, also `:1423` for the tavern-duel path) should resolve dual ids
too if a dual card ever appears in an enemy deck — pick the same face as the player or
always-Light (Plan decision; document it).

The UI (TID-222) needs to know a CardInstance is dual-faced and which face is active —
plan for that now (e.g. carry `dual_card_id` / `active_face: String` on the resolved
template dict and `CardInstance`, included in `to_dict()`/`from_dict()`).

### Mid-battle save/resume — face fixedness comes for free, but verify

`CardInstance.to_dict()/from_dict()` (`game_logic/battle/CardInstance.gd:115-168`)
serialize the RESOLVED fields (name, cost, effects...), and the restore path
(`BattleScene.gd:109-112`, `GameState.from_dict(SceneManager.save_manager.pending_battle_state)`)
never re-reads alignment. So the chosen face survives resume automatically — but any NEW
CardInstance fields (e.g. `active_face`) must be added to both `to_dict()` and
`from_dict()`, mirroring the 21-field pattern. Add a round-trip test.

### Constraints (CLAUDE.md)

- Any new `.tres` needs a `.uid` sidecar (`uid://` + 12 lowercase alphanumerics; generator
  one-liner is in CLAUDE.md) and a `const ... := preload(...)` entry in
  `autoloads/CardRegistry.gd` (`_C_*` consts lines 5–50 + the `all` array in
  `_ensure_loaded()`). Never `ResourceLoader.load()` with dynamic paths (Android).
- `:=` cannot infer from Variant — annotate `var x: int = ...` for dict/array reads.
- Preload scripts instead of relying on `class_name` global registration.
- Tests: `godot --headless --path . -s tests/runner.gd` (exit 0 = pass). Existing battle
  tests live in `tests/unit/` (e.g. `test_card_registry.gd`).

### Doc references

`docs/agent/battle-system.md` (CardData fields, CardRegistry, battle start, persistence),
`docs/agent/skill-trees.md` (currency semantics, SaveManager fields table v13).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
