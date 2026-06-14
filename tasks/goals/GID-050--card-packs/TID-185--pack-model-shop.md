# TID-185: Pack Data Model + Shop Integration

**Goal:** GID-050
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Pack definitions, rarity tier mapping, roll logic, and merchant shop UI integration. Packs are bought at the shop, rolled at purchase time, and results passed to the opening ceremony scene.

## Research Notes

- **Pack definitions:** New file **`game_logic/PackDefs.gd`** with static pack table. Two tiers:
  - Standard: `{ id: "standard_pack", name: "Standard Pack", price: 120, card_count: 3, tier: 1 }`
  - Premium: `{ id: "premium_pack", name: "Premium Pack", price: 300, card_count: 3, tier: 2, guaranteed_min_rarity: "rare" }`
  - `tier` maps to **`CardDropUtil.TIER_WEIGHTS`** (lines 8–13): tier 1 = [80,18,2,0] (common/rare/epic/legendary weights), tier 2 = [60,30,9,1]. Index = tier-1. **Packs use tier 1 (overworld) and tier 2 (dungeon end) weights sensibly** — Standard = tier 1, Premium = tier 2 per CardDropUtil semantics.
  - `guaranteed_min_rarity` (Premium only): if set, one slot's rarity is forced to at least this value. Rare or better = indices [rare, epic, legendary].

- **Card rolling at purchase:** Roll happens immediately at buy time, not at open time (simpler, testable). Roll function in `PackDefs`:
  - `static func roll_pack(pack_id: String) -> Array[Dictionary]` — returns array of 3 dicts: `{ template_id, rarity, attack, health, cost }`. 
  - For each card: pick random template from `CardRegistry.get_all_ids()` filtering out uncraft-flagged cards (check **`data/CardData.gd`** for a `can_craft: bool` field from GID-028 v10 — if it exists, exclude where `can_craft == false`; if not, include all).
  - Call **`CardDropUtil.roll_rarity(pack_tier)`** (line 16) to get rarity string.
  - Call **`CardDropUtil.roll_stats(template_id, rarity)`** (line 45) to get `{attack, health, cost}`.
  - If `guaranteed_min_rarity` is set, on the "best slot" (highest index, to avoid overwriting slot 0), replace rarity with one that satisfies the guarantee: if rolled rarity is already >= (rare/epic/legendary), keep it; else pick one that's >= guaranteed_min_rarity re-rolling stats.
  - Return array of 3 rolled dicts.

- **SaveManager integration:** API **`SaveManager.add_card_instance(template_id, rarity, attack, health, cost)`** (line 513–530) creates a fresh UID'd card instance and appends to `owned_cards`, returns the UID. This is called once per rolled card during opening ceremony (TID-186).

- **Shop UI:** **`scenes/ui/ShopScene.gd`** (lines 95–142 in current file, card/weapon/armor sections). Add a "— Packs —" section after "— Cards —" and before "— Weapons —" (around line 108). Iterate `PackDefs` pack table, build rows via `_make_pack_row(pack_id, pack_def, coins)` (new helper). Row layout: pack name + "3 cards" description, price in gold, Buy button. Button disabled if `coins < price`. On Buy: deduct coins via `SaveManager.add_coins(-price)`, call `PackDefs.roll_pack(pack_id)` to get rolled cards, emit **`GameBus.pack_purchased(pack_id, rolled_cards_array)`** (new signal; add to GameBus.gd), route to `PackOpenScene` via SceneManager. Decision: emit signal or transition directly? **Use signal** — SceneManager listens to `GameBus.pack_purchased` and instantiates `PackOpenScene` with the rolled results (passed as constructor arg or scene property).

- **GameBus signal:** Add `pack_purchased(pack_id: String, rolled_cards: Array[Dictionary])` to **`autoloads/GameBus.gd`**. Update **`docs/agent/signals-and-constants.md`** signal table.

- **SceneManager routing:** Add code to `_on_pack_purchased(pack_id, rolled_cards)` to instantiate `PackOpenScene`, pass rolled_cards, add as overlay (same pattern as `_on_shop_requested`, lines 342–347), connect `closed` signal. Store overlay reference (new `_pack_open_overlay: Node` field).

- **Headless tests:** Test pack rolling: correct counts, rarity distribution matches tier, guaranteed_min_rarity enforced, card templates exist and are craftable, coin deduction flow, duplicate template prevention if desired (keep it simple: allow duplicates in same pack).

## Plan

1. Create `game_logic/PackDefs.gd` with PACKS table, `get_pack()`, `get_all_pack_ids()`, and `roll_pack()`.
2. Add `pack_purchased` signal to `autoloads/GameBus.gd`.
3. Add "— Packs —" section to `scenes/ui/ShopScene.gd` with `_make_pack_row()` and `_on_buy_pack()`.
4. Add SceneManager routing for `pack_purchased` signal → `PackOpenScene` overlay.
5. Write unit tests in `tests/unit/test_card_packs.gd`.

## Changes Made

- **`game_logic/PackDefs.gd`** (new): Static pack definitions (standard_pack at 120 coins tier-1, premium_pack at 300 coins tier-2 with guaranteed_min_rarity:"rare"), `PITY_THRESHOLD = 20`, `get_pack()`, `get_all_pack_ids()`, `roll_pack(pack_id, current_pity)`. Builds craftable-card pool from CardRegistry, rolls via CardDropUtil, applies guaranteed_min_rarity to slot 1, applies pity force to last slot.
- **`autoloads/GameBus.gd`**: Added `signal pack_purchased(pack_id: String, rolled_cards: Array[Dictionary])`.
- **`scenes/ui/ShopScene.gd`**: Added `const PackDefs = preload(...)`, "— Packs —" section in `_refresh()`, `_make_pack_row()` helper (shows pack name, price, buy button, pity hint label), `_on_buy_pack()` handler.
- **`autoloads/SceneManager.gd`**: Added `PACK_OPEN` State enum value, `_PackOpenSceneScript` preload, `_pack_open_overlay` field, `_on_pack_purchased()` and `_on_pack_open_closed()` handlers, connected signal in `_ready()`, cleanup in `_exit_world_cleanup()`.
- **`tests/unit/test_card_packs.gd`** (new): 31 unit tests covering pack table shape, roll counts, template validity, rarity validity, pity logic, SaveManager helpers, and migration.
- **`tests/runner.gd`**: Added `test_card_packs` suite.

## Documentation Updates

- Created `docs/agent/card-packs.md` covering pack system design, roll logic, pity counter, SceneManager routing, and shop integration.
- Updated `docs/agent/signals-and-constants.md` GameBus signal table to include `pack_purchased`.
