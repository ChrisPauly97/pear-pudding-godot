# TID-201: Spectral Enemy Data + Drops

**Goal:** GID-055
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Three new spectral `EnemyData` resources define night-exclusive enemy types with thematic decks and boosted card drops. They are registered with `EnemyRegistry` and selected by spawn depth (randomized per-night) with rarity-weighted distribution.

## Research Notes

- **Three spectral variants:** `spectre_wisp` (tier 1), `spectre_haunt` (tier 2), `spectre_dread` (tier 3). Create `.tres` resource files in **data/enemies/**.
  - **spectre_wisp**: `id: "spectre_wisp"`, `display_name: "Wisp"`, `difficulty_tier: 1`, `coin_reward: 8` (1.6× vs undead_basic at 5), deck: spectral ghost/shadow cards (to be selected from existing card pool)
  - **spectre_haunt**: `id: "spectre_haunt"`, `display_name: "Phantom"`, `difficulty_tier: 2`, `coin_reward: 12` (1.5× vs undead_horde at 8), deck: stronger spectral cards
  - **spectre_dread**: `id: "spectre_dread"`, `display_name: "Wraith"`, `difficulty_tier: 3`, `coin_reward: 18` (1.5× vs ghoul_pack at 12), deck: apex spectral cards

- **Deck composition:** Use existing card IDs. Sample candidates from **data/cards/*.tres**: `"ghost"`, `"skeleton"`, `"zombie"`, `"ghoul"`, `"shadow_bolt"`, `"soul_rend"`, `"wither"`, `"brittle"`. A spectral wisp deck might be 4× ghost + 4× shadow_bolt + 2× soul_rend (10 cards). Confirm all card IDs exist in CardRegistry before finalizing.

- **EnemyData fields:** From **data/EnemyData.gd** and **data/enemies/undead_basic.tres**:
  - `id: String` — unique identifier
  - `display_name: String` — shown in battle
  - `deck: PackedStringArray` — cards in hand during battle (loaded into draw pile via **autoloads/EnemyRegistry.gd** line 39: `result.assign(...)`)
  - `drop_pool: PackedStringArray` — cards that can drop on victory
  - `coin_reward: int` — coin drop amount
  - `difficulty_tier: int` — 1–4, feeds into **game_logic/CardDropUtil.gd** line 16 `roll_rarity(source_tier: int)` for weighted rarity rolls
  - `is_boss: bool` — false for spectres (default)
  - `drop_pool`: List 5–6 cards per spectre (mix of shadow/spectral cards and generics)

- **Boosted drops:** In **autoloads/SceneManager.gd** lines 253–302, the `_on_battle_won()` function reads `enemy_type` from `save_manager.pending_battle_enemy_data`, then calls `EnemyRegistry.get_difficulty_tier(enemy_type)` at line 260, passing that tier to `CardDropUtil.roll_rarity(drop_tier)` at line 273. To boost spectral drops, pass `drop_tier + 1` (capped at 4) when the enemy is spectral. Simplest implementation: add a field `night_drop_boost: bool = true` to spectral EnemyData, then in `_on_battle_won()` check `save_manager.pending_battle_enemy_data.get("night_drop_boost", false)` and increment tier. Alternative: set a flag on the enemy entity node during spawn and copy it to pending data. Decision: add field to EnemyData for clarity.

- **Post-battle drop path:** Battle result is emitted from **scenes/battle/BattleScene.gd** as a signal `GameBus.battle_won.emit(result)` where result is a Dictionary. SceneManager receives it at line 74 and calls `_on_battle_won(result)`. The result dict includes `"card_reward"` (single string) or `"card_rewards"` (array for bosses). For spectres, they emit single `"card_reward"` entries; the rarity boost happens at line 273 when rolling the rarity.

- **EnemyRegistry registration:** All spectral EnemyData `.tres` files in **data/enemies/** are auto-loaded by `_ensure_loaded()` at line 16–31, which iterates files and calls `ResourceLoader.load()`. Per CLAUDE.md: never use `ResourceLoader.load()` on Android; instead, add preload constants and iterate them. However, EnemyRegistry already uses `ResourceLoader.load()` (line 27), so it's the existing pattern. For v1, keep it consistent; if Android porting is needed later, refactor to preloads. Create the `.tres` files and ensure they contain the required fields.

- **UID sidecar:** Per CLAUDE.md, create a `.uid` companion file for each `.tres` using format `uid://` + 12 random alphanumeric chars. Generate via `python3 -c "import random,string; print('uid://'+''.join(random.choices(string.ascii_lowercase+string.digits,k=12)))"` for each file.

- **Deck validation tests:** Headless tests verify all card IDs in spectral decks exist in CardRegistry (call `CardRegistry.get_template(card_id)` and check non-empty result). Verify `difficulty_tier` is 1–3. Verify `coin_reward` is reasonable.

- **Drop rarity boost test:** Create a minimal pending battle dict with a spectral enemy, call `_on_battle_won({...})`, and verify the stored card's rarity is one tier higher than a non-boosted equivalent (e.g., tier 2 spectral → tier 3 rarity, capped at legendary).

## Plan

Add three spectral enemy entries inline in `EnemyRegistry._ensure_loaded()` (matching existing pattern for all enemies). Add `night_drop_boost: true` field to each spectre entry. Add `get_night_drop_boost()` static method. In `SceneManager._on_battle_won()`, apply the tier boost before rolling drop rarity. Spectral enemies bypass `defeated_enemies` tracking.

## Changes Made

- **`autoloads/EnemyRegistry.gd`**: Added `spectre_wisp` (tier 1, coin 8), `spectre_haunt` (tier 2, coin 12), `spectre_dread` (tier 3, coin 18) entries to `_ensure_loaded()` dict. Each has `night_drop_boost: true`, `is_tracking: true` (via `is_tracking()` method update), 10–14 card decks from existing card pool, 6–7 card drop pools. Added `get_night_drop_boost(type_id)` static method. Updated `is_tracking()` to include the three spectre types.
- **`autoloads/SceneManager.gd`**: In `_on_battle_won()`, reads `EnemyRegistry.get_night_drop_boost(enemy_type)` and applies `drop_tier = mini(drop_tier + 1, 4)` before rolling card rarity. Spectral enemies (`enemy_type.begins_with("spectre_")`) skip `mark_enemy_defeated()` and `record_enemy_defeated()`. Added XP rewards for all three spectre types to `_XP_TABLE`.

## Documentation Updates

Updated `docs/agent/night-hunts.md` (created by TID-200).
