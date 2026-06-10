# TID-220: Content: Signature Cards + Conditions for the 4 Existing Enemy Types

**Goal:** GID-061
**Type:** agent
**Status:** pending
**Depends On:** TID-219

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The content pass: author one signature card `.tres` per existing enemy type, assign each enemy a capture condition (+ param) tuned to its deck, and wire everything into the registries. With TID-218 (fields + tracking) and TID-219 (victory flow + save tracking) in place, this task makes Soulbinding live end-to-end.

## Research Notes

### The 4 existing enemy types (`data/enemies/*.tres`) — exact ids

| id | display_name | Deck | coin_reward | tier | drop_pool (must NOT gain signature ids) |
|---|---|---|---|---|---|
| `undead_basic` | Undead Wanderer | 3× ghost, 3× skeleton, 3× zombie, 1× ghoul | 5 | 1 | ghost, skeleton, mend, wither, surge_spirit, ember_imp |
| `undead_horde` | Horde Shambler | 4× ghost, 3× skeleton, 2× zombie, 2× ghoul | 8 | 2 | skeleton, zombie, dawn_acolyte, dusk_wraith, shrouded_wraith, dusk_seer, void_creeper |
| `ghoul_pack` | Ghoul Pack Leader | 4× ghoul, 4× zombie, 4× skeleton | 12 | 3 | zombie, ghoul, dawn_paladin, dusk_vampire, iron_revenant, dawn_guardian, dawn_healer |
| `undead_elite` | Undead Warlord | 5× ghoul, 4× zombie, 3× skeleton | 20 | 4 | ghoul, restore, drain, blitz_ghoul, veiled_paladin, ash_warden |

None are bosses (`is_boss` absent/false in all four `.tres`).

### Authoring CardData .tres files

- Script: `data/CardData.gd` (`class_name CardData`). Fields: `id`, `card_name`, `cost`, `attack`, `health`, `card_class` ("minion"/"spell"), `description`, `color: Color`, `magic_type` ("light"/"dark"/""), `magic_branch` ("ember"/"dawn"/"dusk"/"ash"/""), `spell_effect`, `spell_power`, `auto_resolve`, `emergence_effect`, `emergence_power`, `keywords: PackedStringArray`, `can_craft` (set **false** for signatures), `is_unique` (set **true** for signatures — TID-219 makes `to_template_dict()` expose it so InventoryScene hides sell/scrap).
- File format — copy `data/cards/ghost.tres`:
  ```
  [gd_resource type="Resource" script_class="CardData" load_steps=2 format=3 uid="uid://<12 lowercase alnum>"]

  [ext_resource type="Script" path="res://data/CardData.gd" id="1_<name>"]

  [resource]
  script = ExtResource("1_<name>")
  id = "<id>"
  card_name = "..."
  ...
  ```
  Generate the header uid AND a `.uid` sidecar per CLAUDE.md: `python3 -c "import random,string; print('uid://'+''.join(random.choices(string.ascii_lowercase+string.digits,k=12)))"`. Sidecar filename: `<name>.tres.uid` containing one `uid://...` line (note: a few legacy files are named `<name>.uid`, e.g. `dawn_healer.uid` — use the `.tres.uid` form for new files).
- Keywords serialize as `keywords = PackedStringArray("ward")`; valid keys are in `game_logic/battle/Keywords.gd` (`ward`, `surge`, `shroud`). Spell `spell_effect` keys and emergence keys are listed in `docs/agent/battle-system.md` (lines 57–80).

### CardRegistry registration (`autoloads/CardRegistry.gd`)

Per CLAUDE.md Android rules, every new card needs:
1. A `const _C_<NAME> := preload("res://data/cards/<name>.tres")` (alphabetical block, lines 5–50).
2. An entry in the `all` array inside `_ensure_loaded()` (lines 59–69).
No directory scanning — miss either step and the card silently won't exist on Android.

### Enemy .tres edits

Each of the 4 enemy files gets `signature_card = "<card_id>"`, `capture_condition = "<key>"`, and (where applicable) `capture_param = N` appended under `[resource]` — fields exist after TID-218. Do **not** add signature ids to `drop_pool`.

### Condition assignment (tune in Plan; suggested pairings using TID-218's keys)

| Enemy | Suggested condition | Rationale |
|---|---|---|
| `undead_basic` | `win_by_turn` (param ~9, i.e. player's 5th turn — `GameState.turn_number` counts half-rounds, player turns are odd) | Easy intro hunt vs the weakest deck |
| `undead_horde` | `spell_final_blow` | Wide ghost/skeleton board rewards AoE spells (`wither`, `scorch`-style) |
| `ghoul_pack` | `no_minion_hero_attacks` | Forces spell/attrition wins vs a midrange deck |
| `undead_elite` | `hero_hp_at_most` (param ~10) | High-risk clutch win vs the hardest deck |

### Card design guardrails

- Cost/stat reference points from existing catalogue (`docs/agent/battle-system.md` lines 88–95): `iron_revenant` 3-mana 1/5 ward, `blitz_ghoul` 4-mana 4/2 surge, `veiled_paladin` 5-mana 3/4 shroud+ward. Signatures should be desirable but not auto-include — roughly on-curve with one distinctive keyword/emergence/spell twist each, themed to their enemy (e.g. Undead Wanderer → cheap surge spirit; Undead Warlord → big ghoul finisher).
- Rarity: granted via `SaveManager.add_card_instance(id, rarity, ...)` from TID-219's `signature_capture` handling — the rarity chosen there should match what these cards' stats assume (`CardDropUtil.roll_stats` scales by rarity).
- `card_class = "legendary"` triggers achievement-gating in `CardRegistry.is_unlocked()` (line 108–120) — avoid it; use `"minion"`/`"spell"` with `is_unique = true`, `can_craft = false`.

### Verification

- TID-219's shop exclusion uses `EnemyRegistry.get_all_signature_card_ids()` — after authoring, confirm all 4 signature ids are returned and absent from `ShopScene` listings and every `drop_pool`.
- Tests: extend the headless suite — every enemy id has non-empty `signature_card` + valid `capture_condition` key; every signature id resolves via `CardRegistry.get_template()`; no signature id appears in any `EnemyRegistry.get_drop_pool()`. Run `godot --headless --path . -s tests/runner.gd`.
- Also run `godot --headless --editor --quit` once locally if available, so the editor validates/normalizes the new `.tres` + `.uid` files (CI does this too, per CLAUDE.md).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
