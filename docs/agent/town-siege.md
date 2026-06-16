# Town Siege Defense

## Key Features

- Martarquas raiders periodically besiege named towns after a gating story flag is set
- 3-battle gauntlet where the player's hero HP carries over between battles
- Siege persists until fought or until 1 in-game day passes (town holds out)
- Victory awards 150 coins + a rare-or-better card, and a 3-day town discount
- Defeat costs 10% of current coins; never blocks story progression

---

## How It Works

### Trigger Conditions (SiegeDefs.should_trigger)

Three conditions must all be true for a siege to fire when entering a town map:

1. **Gating flag:** `story_flags["chapter1_warned_farsyth"]` must be `true` — set when the player speaks to Lord Farsyth in `farsyth_mansion`. No sieges fire before this.
2. **Cooldown:** `days_elapsed - last_siege_day >= 4`. At most one siege every 4 in-game days.
3. **Seeded probability:** `hash(world_seed ^ days_elapsed) % 100 < 8` — ~8% daily chance, deterministic per save+day.

Siege towns: `madrian`, `maykalene`, `blancogov`. Infinite world and dungeons never trigger.

### Save Fields (version 31)

| Field | Type | Purpose |
|---|---|---|
| `siege` | `Dictionary` | Active siege state: `{town, stage, hero_hp, day_started}` or `{}` |
| `last_siege_day` | `int` | `days_elapsed` when the last siege ended (win or loss) |
| `town_discounts` | `Dictionary` | `{town_name: expiry_day}` — discount active when `expiry_day >= days_elapsed` |

Migration from v30 adds all three fields with their defaults.

### Siege Lifecycle

```
WorldScene._check_siege_spawn(map_name)
  └─ SiegeDefs.should_trigger() → start_siege(town) if no active siege
  └─ _spawn_siege_raiders(stage) — 3 EnemyNPC nodes near TOWN_GATES[map_name]
  └─ _setup_siege_banner(map_name) — red label in HUD

Player interacts with raider NPC
  └─ GameBus.enemy_engaged.emit(raider_dict)
  └─ SceneManager._on_enemy_engaged → BattleScene launched
       └─ BattleScene._ready(): siege HP injection from save_manager.get_active_siege()

[Battle won]
SceneManager._on_battle_won()
  └─ Siege check at top (before standard rewards):
      ├─ stage 0 or 1: advance_siege_stage() → _show_siege_interstitial() → chain next raider
      └─ stage 2: _apply_siege_victory_rewards() → end_siege_victory() → restore world

[Battle lost]
SceneManager._on_battle_lost()
  └─ 10% coin loss → end_siege_defeat() → GameBus.siege_defeated.emit(coins_lost)
  └─ Falls through to normal game-over flow (no story block)

[Timeout: 1 day without engagement]
SaveManager.increment_day()
  └─ If siege age >= 1 day: end_siege_defeat() — silent, no coin loss
```

### Hero HP Carry-Over

`BattleScene._ready()` checks `save_manager.get_active_siege()`. If a siege is active, the player's hero HP is set to `siege["hero_hp"]` instead of the default 30. After each stage victory, `set_siege_hero_hp(result.hero_hp)` preserves current HP for the next stage.

### Raider Entities (TID-198)

3 `EnemyNPC` instances are spawned at `TOWN_GATES[town]` (world-space positions derived from tile coords × 2.0) with small ±offsets. Enemy type: `martarquas_raider_1/2/3` matching the current stage.

Raiders are not tracking enemies (`EnemyRegistry.is_tracking()` returns false), so they don't auto-engage — the player must walk up and interact (E key / tap).

### Siege Banner

A red `Label` added to `_hud` (the world's CanvasLayer) showing `"[Town] Under Attack!"`. Visible for the lifetime of the WorldScene while the siege is active.

### Gauntlet Interstitial (TID-198)

After each of stages 0 and 1, a `CanvasLayer` overlay shows:
- `"Wave N of 3"` in large text
- `"Hero HP: X / 30"` in smaller text (red if HP ≤ 10)

After 2 seconds it auto-dismisses and calls `GameBus.enemy_engaged` with the next raider dict. This keeps the player in the battle flow without returning to the world.

### Victory Rewards (TID-199)

`SceneManager._apply_siege_victory_rewards(town)`:
- Adds 150 coins (`SIEGE_VICTORY_COINS`)
- Picks a random card from `CardRegistry.get_all_ids()` and awards it at `roll_rarity(3)` (rare-or-better)
- Emits `GameBus.siege_victory`
- Shows toast: `"Siege Defeated! [Town] thanks you! +150 coins + rare card"`

### Town Gratitude Discount (TID-199)

`SaveManager.end_siege_victory()` calls `apply_town_discount(town)`, which sets `town_discounts[town] = days_elapsed + 3`.

`ShopScene._refresh()` checks `save_manager.is_town_discounted(town_name)` (where `town_name` is set by `SceneManager._on_shop_requested()` from `current_map`). If discounted:
- Card price: `int(CARD_PRICE * 0.8)` = 12 coins
- Weapon/equipment prices: `int(price * 0.8)` each
- Section headers show `"(20% off — Town Discount)"`

`SaveManager.increment_day()` removes expired entries from `town_discounts`.

---

## Enemy Types (EnemyRegistry)

| ID | Display Name | Tier | Deck |
|---|---|---|---|
| `martarquas_raider_1` | Martarquas Raider | 1 | ghost×2, zombie×2, ghoul |
| `martarquas_raider_2` | Martarquas Veteran | 2 | ghost, skeleton, zombie×2, ghoul×2 |
| `martarquas_raider_3` | Martarquas Warlord | 3 | ghost, skeleton×2, zombie×2, ghoul×2 |

All three have empty `drop_pool` and `coin_reward = 0` (siege has its own victory reward path).

---

## Integrations with Other Features

| System | Direction | Details |
|---|---|---|
| **SaveManager** | Owner | Stores `siege`, `last_siege_day`, `town_discounts`; version 31 migration |
| **WorldScene** | Consumer | Checks for siege on named-map load; spawns raiders and banner |
| **BattleScene** | Consumer | Reads `siege.hero_hp` to inject carry-over HP at battle start |
| **SceneManager** | Orchestrator | Gauntlet chaining via `_on_battle_won`, defeat handling via `_on_battle_lost`, victory rewards via `_apply_siege_victory_rewards`, interstitial via `_show_siege_interstitial` |
| **ShopScene** | Consumer | Reads `is_town_discounted(town_name)` and applies 0.8 multiplier |
| **GameBus** | Signal hub | `siege_victory`, `siege_defeated(coins_lost: int)` |
| **EnemyRegistry** | Data | Three raider enemy types; no auto-tracking, no drop pool |
| **SiegeDefs** | Logic | `should_trigger()`, `get_raider_deck_ids()`, `get_stage_name()`, `TOWN_GATES` |

---

## Asset Requirements

| Asset | Path | Notes |
|---|---|---|
| Siege logic | `game_logic/SiegeDefs.gd` | Pure static helpers |
| Raider data | `data/enemies/martarquas_raider_1/2/3.tres` + `.uid` | EnemyData resources |
| Tests | `tests/unit/test_siege_trigger/state/timeout/defeat/town_discount.gd` | 5 headless unit tests |
