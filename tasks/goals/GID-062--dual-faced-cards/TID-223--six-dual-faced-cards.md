# TID-223: Content: 6 dual-faced cards spanning the four branches

**Goal:** GID-062
**Type:** agent
**Status:** done
**Depends On:** TID-221

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

With the dual-face model and battle-start alignment resolution in place (TID-221), this
task ships the content: 6 dual-faced cards covering all four magic branches (ember,
dawn, dusk, ash), each with meaningfully different Light/Dark behaviour — different
effects, not just stat swaps (e.g. Light face `heal_all` vs Dark face
`deal_damage_all`).

## Research Notes

### .tres format and field names

Cards live in `data/cards/*.tres` (46 today). Exact format (from
`data/cards/mend.tres`):

```
[gd_resource type="Resource" script_class="CardData" load_steps=2 format=3 uid="uid://hvj8k7w6ks5t"]

[ext_resource type="Script" path="res://data/CardData.gd" id="1_mend"]

[resource]
script = ExtResource("1_mend")
id = "mend"
card_name = "Mend"          # NOTE: field is card_name, not display_name
cost = 1
attack = 0
health = 0
card_class = "spell"
description = "..."
color = Color(1, 0.9, 0.5, 1)
magic_type = "light"
magic_branch = "dawn"
spell_effect = "heal_single"
spell_power = 3
```

Omitted properties fall back to script defaults — only set what differs. Keywords
serialize as `keywords = PackedStringArray("ward")`. Minions leave spell fields at
defaults; spells set `card_class = "spell"`. Optional minion on-play abilities:
`emergence_effect` / `emergence_power`. The structure of the dual-face fields
(`light_face_id`/`dark_face_id` shell + 2 face resources, or embedded `dark_*` fields)
is decided in TID-221's Plan — read it before authoring files.

### Available effect vocabulary (no new battle logic needed)

Spell effects dispatched by `BattleScene._resolve_spell_effect` (full list in
`docs/agent/battle-system.md`): `deal_damage_single`, `deal_damage_all`,
`deal_damage_random`, `debuff_attack`, `destroy_low_hp`, `resurrect_last`,
`heal_single`, `heal_all`, `shield_minion`, `buff_attack`, `lifesteal_hit`,
`mana_drain`, `curse_minion`, `draw_card`.
Emergence effects (`_resolve_emergence`): `emergence_deal_damage` (enemy hero),
`emergence_heal_hero`, `emergence_draw`, `emergence_buff_friendly`,
`emergence_apply_poison`.
Keywords (`game_logic/battle/Keywords.gd`): `ward`, `surge`, `shroud`.

Meaningful Light/Dark contrast pairs achievable with existing effects, e.g.:
`heal_all` vs `deal_damage_all`; `shield_minion` vs `curse_minion`; `heal_single` vs
`lifesteal_hit`; `buff_attack` vs `debuff_attack`; `resurrect_last` vs
`destroy_low_hp`; minion with `ward` + `emergence_heal_hero` vs `surge` +
`emergence_deal_damage`. Spanning 6 cards across 4 branches means at least one branch
gets 2 cards — keep light branches (ember/dawn) and dark branches (dusk/ash) balanced
(e.g. 2/2/1/1 or 1/2/2/1). Branch color conventions in existing cards: ember = reds
(`Color(1, 0.2, 0, 1)` scorch), dawn = warm golds (`Color(1, 0.9, 0.5, 1)` mend), dusk =
purples, ash = grays — check siblings in `data/cards/` for each branch before picking.

### Registration checklist (CLAUDE.md Android rules — every new .tres)

1. Create `data/cards/<name>.tres` with a fresh `uid="uid://..."` in the header.
2. Create the `<name>.tres.uid` sidecar containing the same uid string
   (`uid://` + exactly 12 lowercase alphanumerics; generate via
   `python3 -c "import random,string; print('uid://'+''.join(random.choices(string.ascii_lowercase+string.digits,k=12)))"`).
3. Add `const _C_<NAME> := preload("res://data/cards/<name>.tres")` to
   `autoloads/CardRegistry.gd` (alphabetical block, lines 5–50) AND append it to the
   `all` array in `_ensure_loaded()` (lines 59–69). Never `ResourceLoader.load()`.
4. If the model is linked-faces: face `.tres` files are registered the same way but must
   be excluded from player-facing enumeration per TID-221's hiding mechanism (shop:
   `ShopScene.gd:99`; crafting: `CraftingRegistry.gd:13`; both iterate
   `CardRegistry.get_all_ids()`).

### Acquisition surfaces (decide where dual cards come from)

- Shop: `ShopScene.gd:99` lists every registry id passing
  `CardRegistry.is_unlocked(id, unlocked_achievements)` — dual shell ids appear
  automatically once registered (faces must not).
- Drops: `EnemyRegistry.get_drop_pool(enemy_type)` returns explicit id lists per enemy
  type — add dual shell ids to chosen pools if drops are wanted (see the keyword-card
  precedent table in `docs/agent/battle-system.md`, "Drop source" column).
- Crafting: gated by `can_craft` (default true).
- None go in the starter deck (`BattleScene.gd:121-123` fallback list).

### Tests

- `tests/unit/test_card_registry.gd:25-26` hard-codes the registry count
  (`assert_eq(_registry.get_all_ids().size(), 40)` — already stale vs the 46 preloaded
  cards; verify what the runner reports and update the expected count to include the new
  cards, respecting TID-221's face-hiding semantics for `get_all_ids()`).
- Add assertions that each dual card resolves to the expected Light/Dark templates via
  TID-221's resolution helper, and that the two faces of each card differ in
  `spell_effect`/`emergence_effect`/`keywords` (not just stats) — this enforces the
  "meaningfully different" criterion mechanically.
- Run: `godot --headless --path . -s tests/runner.gd` (exit 0 = pass; install per
  CLAUDE.md if `godot` missing).

### GDScript gotchas (CLAUDE.md)

Annotate types when reading dicts/arrays (`var d: int = arr[i]`); array literals passed
to `Array[String]` params need explicit annotation; use `assign()` for dict-sourced
arrays.

### Docs

Update `docs/agent/battle-system.md` with a dual-faced card table (mirror the TID-096
keyword-card table format: ID, Name, Branch, Cost, faces' effects, drop source) and note
the registered count change.

## Plan

Created 6 dual-faced `.tres` cards using embedded dark_* fields (model b from TID-221), covering all 4 branches with meaningfully different Light/Dark effects. Registered all 6 in CardRegistry.gd with const preloads. Created .uid sidecars for all 6. Updated test count to 56 and added 8 dual-face tests.

## Changes Made

- `data/cards/ember_covenant.tres` + `.uid` (uid://eke9lt9dt6lt): Ember spell — Light: heal_all(2), Dark: deal_damage_all(2)
- `data/cards/pyre_warden.tres` + `.uid` (uid://no5p3we34dol): Ember minion — Light: 1/5 Ward, Dark: 4/2 Surge
- `data/cards/sacred_light.tres` + `.uid` (uid://a88m0tgwpufw): Dawn spell — Light: heal_single(4), Dark: lifesteal_hit(2)
- `data/cards/hallowed_ground.tres` + `.uid` (uid://otrc5wbzfuuc): Dawn spell — Light: resurrect_last, Dark: destroy_low_hp(3)
- `data/cards/twilight_veil.tres` + `.uid` (uid://pn62dgf1jcrd): Dusk spell — Light: shield_minion(3), Dark: curse_minion(2)
- `data/cards/ash_arbiter.tres` + `.uid` (uid://v4qre7z8dvcs): Ash minion — Light: 2/4 Ward+emergence_heal_hero(2), Dark: 3/3 Surge+emergence_deal_damage(2)
- `autoloads/CardRegistry.gd`: 6 new const preloads + added to `_ensure_loaded()` array
- `tests/unit/test_card_registry.gd`: updated count to 56; added 8 dual-face tests for `get_template_for_face`

## Documentation Updates

- `docs/agent/battle-system.md`: Dual-Faced Card Catalogue table in the Dual-Faced Corruption Cards section.
