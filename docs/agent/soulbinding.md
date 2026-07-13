# Soulbinding — Every Enemy Is a Card

## Key Features

- Each of the 4 main enemy types has a **signature card** obtainable only by winning under a special **capture condition**
- Signature cards cannot be purchased in the shop, cannot be scrapped/sold, and cannot be crafted
- Each signature is a one-time capture per save; repeat wins show the hunt-status line instead
- Conditions are evaluated by `CaptureTracker` in pure logic with no rendering dependency

## How It Works

### Data Layer

**`data/EnemyData.gd`** — three new `@export` fields:
- `signature_card: String` — card id of the signature (empty = no signature)
- `capture_condition: String` — condition key (see table below)
- `capture_param: int` — numeric param for parameterized conditions

**`autoloads/EnemyRegistry.gd`** — four new static accessors:
- `get_signature_card(type_id) -> String`
- `get_capture_condition(type_id) -> String`
- `get_capture_param(type_id) -> int`
- `get_all_signature_card_ids() -> Array[String]` — used by ShopScene to exclude signatures

### Condition Vocabulary

| Key | Meaning | Param |
|---|---|---|
| `spell_final_blow` | The player's last spell cleared the enemy board (≥1→0 minions) | — |
| `hero_hp_at_most` | Win with player hero HP ≤ N | N |
| `no_minion_hero_attacks` | Win without attacking the enemy hero with a minion | — |
| `win_by_turn` | Win at or before `GameState.turn_number` N | N |

### CaptureTracker (`game_logic/battle/CaptureTracker.gd`)

- `extends RefCounted`, pure logic, no rendering
- Constructed in `BattleScene._ready()` after state setup, with condition + param from `EnemyRegistry`
- Key methods:
  - `note_minion_attacked_hero(attacker_pid)` — called in `_on_enemy_hero_input` when a player minion attacks enemy hero
  - `note_spell_resolved(caster_pid, board_count_before, board_count_after)` — called at end of `_resolve_spell_effect`
  - `is_satisfied(state: GameState) -> bool` — called at `_check_game_over` winner-0 path
  - `condition_text() -> String` — human-readable description for hunt-status UI

### Victory Flow (`scenes/battle/BattleScene.gd`)

At `_check_game_over` winner-0 path (non-boss, non-duel, non-puzzle):
1. Query `EnemyRegistry.get_signature_card(enemy_type)` and `SaveManager.is_signature_captured(sig_id)`
2. Three outcomes:
   - **Uncaptured + condition met** → `_show_soulbind_overlay(reward_card, sig_id, condition_text)` — violet-accented overlay emits `"signature_capture": sig_id` in `battle_won`
   - **Uncaptured + condition NOT met** → `_show_victory_overlay(reward, "", sig_id, condition_text, false)` — normal overlay with hunt-status line
   - **No signature or already captured** → `_show_victory_overlay(reward, "")` — unchanged behavior

### Reward Granting (`autoloads/SceneManager.gd`)

In `_on_battle_won`, after the normal `card_reward` grant:
- If `result["signature_capture"]` is non-empty: grant the signature card via `CardDropUtil.roll_stats(id, "rare")` + `SaveManager.add_card_instance(...)` + `SaveManager.mark_signature_captured(id)`

### Save Persistence (`autoloads/SaveManager.gd`)

- `var captured_signatures: Array[String] = []`
- `mark_signature_captured(card_id)` — append-if-absent + dirty
- `is_signature_captured(card_id) -> bool`
- Persisted in JSON save dict under `"captured_signatures"`
- Migration v34→v35 backfills empty array for old saves
- Reset to `[]` in `new_game()`

### Shop Exclusion (`scenes/ui/ShopScene.gd`)

```gdscript
var _sig_ids: Array[String] = EnemyRegistry.get_all_signature_card_ids()
for id in CardRegistry.get_all_ids():
    if _sig_ids.has(id):
        continue  # never sold
```

### Sell/Scrap Protection (`scenes/ui/InventoryScene.gd`)

`CardData.to_template_dict()` now includes `"is_unique": is_unique` and `"can_craft": can_craft`. InventoryScene already hides the sell/scrap row when `tmpl.get("is_unique", false)` is true.

## The 4 Signature Cards

| Enemy | id | Card | Condition | Theme |
|---|---|---|---|---|
| `undead_basic` | `sig_wanderer` | Restless Runner (2-mana 2/1 Surge) | `win_by_turn` (≤9) | Speed — beat it fast |
| `undead_horde` | `sig_shambler` | Shambling Vanguard (3-mana 3/3, Emergence: deal 2 to enemy hero) | `spell_final_blow` | Board-clear AoE spell |
| `ghoul_pack` | `sig_pack_leader` | Pack Alpha (4-mana 2/5 Ward) | `no_minion_hero_attacks` | Attrition / spell win |
| `undead_elite` | `sig_warlord` | Death Commander (5-mana 4/4 Shroud) | `hero_hp_at_most` (≤10) | High-risk clutch win |

All signature cards: `is_unique = true`, `can_craft = false`.

## Integrations with Other Features

- **CardRegistry** — 4 new `const _C_SIG_*` preloads keep them in the APK
- **GameBus** — uses `battle_won` signal with new optional key `"signature_capture"`; no new signals needed
- **Battle persistence (GID-034)** — tracker flags are NOT persisted in `pending_battle_state`; a fled-and-resumed battle resets the tracker (same precedent as `_hero_power_used`)
- **Bestiary (GID-045)** — no dependency; signatures could surface as a third reveal tier later
- **Tutorial popups (GID-031/GID-117)** — `BattleScene._check_game_over` emits `tutorial_popup_requested("soulbinding")` whenever an uncaptured signature renders on the victory screen (soulbind overlay or hunt-status line); once-per-save via the `seen_tutorial_soulbinding` story flag. Tier-1 `undead_basic` carries `sig_wanderer`, so the teaser is reachable on the first free-roam victory

## Asset Requirements

- `.tres` files: `data/cards/sig_wanderer.tres`, `sig_shambler.tres`, `sig_pack_leader.tres`, `sig_warlord.tres`
- `.uid` sidecars for each (e.g. `sig_wanderer.tres.uid`)
- No new shaders or textures needed (sprite colors defined in `.tres` via `color` field)
