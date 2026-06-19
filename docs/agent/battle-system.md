# Battle System

## Key Features

- Turn-based collectible card game (TCG) battles between the player and an enemy
- Four card types: Ghost, Skeleton, Zombie, Ghoul — each with distinct mana cost, attack, and health
- Per-player 5-slot board zone for deploying minions
- Mana system that grows by 1 each turn, capped at 10
- Summoning sickness: newly played minions cannot attack on their first turn
- One attack per minion per turn (reset at turn start)
- Hero health: 30 HP per player; reduce the opponent's hero to 0 to win
- Basic AI that auto-plays and attacks on the enemy turn
- Drag-to-play card UI with hand, board, and hero views

---

## How It Works

### Data Model

All battle state is pure GDScript with no rendering dependency:

```
GameState          — root object; owns two PlayerState instances, tracks whose turn it is
  PlayerState[0]   — human player (hero, hand, board, draw pile, discard pile)
  PlayerState[1]   — AI enemy  (same structure)
    HeroState      — current HP, current mana, max mana
    ZoneState      — 5 board slots; each slot holds a CardInstance or null
    CardInstance   — runtime card (template ref, current HP, summoning_sick flag, attacks_this_turn)
```

`CardInstance` wraps a `CardData` resource (loaded from `data/cards/*.tres`) and tracks mutable runtime state separately from the static template data. Runtime-only keyword state: `shroud_active: bool` starts `true` for Shroud minions and is set `false` by game logic after the first hit is absorbed.

### Turn Sequence

1. **Turn start** — active player's max mana increments (min 1, max 10); current mana refills to max; all minion `attacks_this_turn` reset to 0; all `summoning_sick` flags cleared.
2. **Draw** — active player draws one card from their draw pile. If the draw pile is empty, fatigue damage fires instead (see below).
3. **Action phase** — active player plays cards and/or attacks until they press "End Turn":
   - *Play card*: costs mana equal to `CardData.cost`; card moves from hand to an empty board slot; new `CardInstance` is created with `summoning_sick = true`.
   - *Attack with minion*: target is any enemy minion or the enemy hero; damage is applied to both combatants; destroyed minions move to discard.
   - *Attack hero directly*: if no enemy minions block, or player targets hero explicitly.
4. **AI turn** — `BasicAI` evaluates board state, plays affordable cards greedily (lowest cost first), then attacks with every available minion (targets minions before hero).
5. **Win check** — after any damage event, if either hero drops to 0 HP `GameState` emits `battle_ended` with the result.

### Deck Fatigue (GID-077)

When a player's draw deck is empty, each draw attempt instead deals escalating damage to that player's hero:

- First failed draw: **1 damage**
- Second failed draw: **2 damage**
- Third failed draw: **3 damage**, and so on

The discard pile is **never** reshuffled back into the draw deck. Fatigue applies identically to the human player and the AI.

**Implementation:**
- `PlayerState.fatigue_counter: int` tracks how many empty draws have occurred for that player (starts at 0, never resets within a battle).
- `PlayerState.draw_card()` increments the counter and calls `hero.take_damage(fatigue_counter)` before returning `null`.
- `GameBus.fatigue_damage(player_id, damage)` is emitted so `BattleScene` can show an orange "Fatigue! −N" toast near the affected hero panel.
- `fatigue_counter` is serialised in `PlayerState.to_dict()` / `from_dict()` so mid-battle saves restore the correct count.

### Card Data

Each `CardData` resource (`data/cards/*.tres`) stores:
- `id: String` — canonical identifier (e.g. `"ghost"`)
- `display_name: String`
- `cost: int` — mana cost
- `attack: int`
- `health: int`
- `card_class: String` — `"minion"` (default) or `"spell"`
- `magic_type: String` — `"light"` | `"dark"` | `""` (non-magic cards)
- `magic_branch: String` — `"ember"` | `"dawn"` | `"dusk"` | `"ash"` | `""`
- `keywords: Array[String]` — passive keyword abilities; valid values are the constants in `game_logic/battle/Keywords.gd`: `"ward"`, `"surge"`, `"shroud"`. Defaults to `[]`; omitting from a `.tres` file is safe.
- `spell_effect: String` — canonical effect key dispatched by `_resolve_spell_effect` in `BattleScene.gd`; `""` for minions. Supported values:
  - `deal_damage_single` — deal spell_power damage to first enemy minion (or hero if board empty)
  - `deal_damage_all` — deal spell_power damage to all enemy minions
  - `deal_damage_random` — deal spell_power damage to a random enemy minion (or hero if board empty)
  - `debuff_attack` — reduce all enemy minion attack by spell_power (floor 0)
  - `destroy_low_hp` — destroy all enemy minions with health ≤ spell_power
  - `resurrect_last` — resurrect last friendly minion from discard with full HP
  - `heal_single` — restore spell_power HP to first friendly minion (cap at max_health)
  - `heal_all` — restore spell_power HP to all friendly minions (cap at max_health)
  - `shield_minion` — add spell_power armor to first friendly minion (armor reduces incoming damage)
  - `buff_attack` — increase attack of first friendly minion by spell_power
  - `lifesteal_hit` — deal spell_power damage to first enemy minion; heal caster hero by same amount
  - `mana_drain` — reduce enemy hero current mana by spell_power (floor 0)
  - `curse_minion` — reduce first enemy minion attack and health by spell_power (destroy if health ≤ 0)
  - `draw_card` — caster draws spell_power additional cards from their deck
- `spell_power: int` — numeric parameter for the effect (damage amount, stat reduction, etc.); `0` for minions

Minion cards (Ghost, Skeleton, Zombie, Ghoul) leave the spell fields at their defaults (`""` / `0`) and are unaffected.

**Emergence fields** (TID-142):
- `emergence_effect: String` — key dispatched by `_resolve_emergence` in `BattleScene.gd`; `""` for most cards. Valid values: `emergence_deal_damage`, `emergence_heal_hero`, `emergence_draw`, `emergence_buff_friendly`, `emergence_apply_poison`.
- `emergence_power: int` — numeric parameter for the effect; `0` for cards without emergence.

`_resolve_emergence(card, caster_pid)` fires immediately after a minion is placed on the board (both player and AI paths). No targeting UI — all emergence effects resolve automatically.

`CardRegistry` (autoload) loads all `.tres` files from `data/cards/` at startup and exposes `get_card(id)` for lookups.

### Keyword Card Catalogue (TID-096)

Six keyword-bearing minion cards added to `data/cards/`. `CardData.keywords` is `PackedStringArray`; serialize in .tres as `keywords = PackedStringArray("ward")` or `PackedStringArray("shroud", "ward")` for multiple.

| ID | Name | Branch | Cost | ATK | HP | Keywords | Drop source |
|---|---|---|---|---|---|---|---|
| iron_revenant | Iron Revenant | Ash | 3 | 1 | 5 | ward | ghoul_pack |
| surge_spirit | Surge Spirit | Ember | 2 | 3 | 1 | surge | undead_basic |
| shrouded_wraith | Shrouded Wraith | Dusk | 3 | 2 | 3 | shroud | undead_horde |
| dawn_guardian | Dawn Guardian | Dawn | 4 | 2 | 6 | ward | ghoul_pack |
| blitz_ghoul | Blitz Ghoul | Ash | 4 | 4 | 2 | surge | undead_elite |
| veiled_paladin | Veiled Paladin | Dawn | 5 | 3 | 4 | shroud, ward | undead_elite |

All 6 appear in ShopScene automatically (CardRegistry scans `data/cards/`). None are in the starter deck.

### Keyword UI (TID-095)

**Card badges** (`BattleScene._update_keyword_badges(hbox, card)`):
- Called from `_build_card_vbox()` (always adds "KeywordRow" HBox) and `_update_card_view()` (refreshes it each frame).
- Shows one colored Label per active keyword: Ward = `Color(0.35, 0.5, 1.0)`, Surge = `Color(1.0, 0.6, 0.15)`, Shroud = `Color(0.8, 0.8, 0.88)`. Font 1.8% vh.
- Shroud badge is hidden when `card.shroud_active == false` (consumed) — updates automatically on `_refresh_all()`.
- Badges appear in hand and on-board cards. Empty KeywordRow (no keywords) collapses to zero height.

**Ward visual feedback**:
- `_apply_card_style()` darkens enemy board minions (by 0.45) that are not in `_get_ward_valid_targets()` when an attacker is selected.
- `_refresh_hero()` sets `is_attack_targetable = false` when any enemy Ward minion is alive, removing the red border/background from the hero attack target.

**Card inspect overlay** (`CardInspectOverlay.gd`):
- After spell-effect section: separator + one Label per keyword in `_card.keywords`.
- Format: `"Surge — Can attack the turn it is summoned."` / `"Shroud — Absorbs the first hit. (Active)"` or `"(Consumed)"`.

### Keyword Game Logic (TID-094)

All keyword logic uses `const Keywords = preload("res://game_logic/battle/Keywords.gd")` — do NOT use bare string literals.

**Ward** — Targeting constraint. When any entity (player or AI) selects an attack target:
- Among the defender's minions, only Ward minions may be targeted while any Ward minion is alive.
- The enemy hero cannot be attacked while any Ward minion is alive on that side.
- Implementation: `BattleScene._get_ward_valid_targets()` filters enemy minions to Ward-bearing ones when present; `_on_enemy_card_input` rejects clicks on non-Ward targets (keeps attacker selected); `_on_enemy_hero_input` early-returns when Ward minions live. `BasicAI.decide_turn/describe_turn` collect `ward_targets` and use them as the target list when non-empty.

**Surge** — On placement. `PlayerState.play_card()`: after `board.add_card(card)`, if `card.keywords.has(Keywords.SURGE)`, set `card.summoning_sick = false`. No other change — `can_attack()` already checks `summoning_sick`.

**Shroud** — Hit absorption. `CardInstance.take_damage()`: if `shroud_active` is true, set it false and return (entire hit absorbed, health unchanged). Runs before armor reduction. Shroud absorbs only the first hit, regardless of damage amount. Does not apply to heroes — only minions carry `shroud_active`.

### BasicAI Logic (`ai/BasicAI.gd`)

```
1. Collect playable cards (cost ≤ current mana), sort by cost ascending
2. For each card: play it into the first empty slot, subtract mana; repeat until no affordable cards or no empty slots
3. For each non-sick minion with attacks_this_turn == 0:
   a. If enemy has minions → attack the weakest (lowest HP) minion
   b. Otherwise → attack enemy hero directly
```

### BattleScene UI (`scenes/battle/BattleScene.gd`)

- Renders hand as a horizontal row of card buttons
- Renders each player's board as 5 slot panels with status icons (P/A/F/S colored labels)
- Hero panels show current/max HP, mana pips, and status icons
- Drag-to-play: card dragged from hand onto an empty board slot triggers `GameState.play_card()`
- **Emergence (TID-142):** `_resolve_emergence(card, caster_pid)` fires after any minion is placed on board. 5 effects: `emergence_deal_damage` (damage enemy hero), `emergence_heal_hero` (heal caster hero), `emergence_draw` (draw cards), `emergence_buff_friendly` (buff random other friendly), `emergence_apply_poison` (poison random enemy). Emergence text shown on card face in amber. 5 new minion cards: Ember Imp (Ember), Dawn Healer (Dawn), Dusk Seer (Dusk), Ash Warden (Ash), Void Creeper (Dusk).
- **Inline ability text (TID-140):** `_SPELL_EFFECT_LABELS` constant in BattleScene maps each `spell_effect` key to a human-readable string with `[power]` placeholder. `_get_card_ability_text(card)` resolves it for a given CardInstance. Spell cards show the resolved text in green on the card face (replacing the flavor description); spell StatsLabel shows `"(cost)"` only (not `"0/0 (cost)"`). Minion cards keep their description. `CardInspectOverlay._SPELL_EFFECT_LABELS` mirrors this dict — keep both in sync.
- **Spell targeting (TID-058, TID-141):** `_ENEMY_TARGETED_EFFECTS = ["deal_damage_single", "curse_minion", "lifesteal_hit"]` and `_FRIENDLY_TARGETED_EFFECTS = ["heal_single", "shield_minion", "buff_attack"]`. Dragging one of these spells to the board enters targeting mode: enemy effects cyan-highlight the enemy board (and hero for `deal_damage_single`); friendly effects cyan-highlight the player's own board. `_targeting_friendly` flag distinguishes the two modes. If no valid targets exist (friendly board empty, or enemy board empty for non-hero spells) targeting is skipped and the spell auto-resolves. All six spells honour the `explicit_target` dict in `_resolve_spell_effect()`; slot-0 fallback kept for AI auto-resolve path.
- **Enemy intent banner (TID-059):** before AI actions execute, a centered panel shows what the AI plans (e.g. "Enemy will play Ghost"); hides when actions complete
- **Battle SFX (TID-080):** Full coverage — `card_draw` plays at player turn start (after game-over check in `_on_turn_ended(0)`); `card_play` plays on card drop; `spell_resolve` plays at the top of `_resolve_spell_effect` (covers player, AI, and auto-resolved spells); `attack` plays on all minion attacks; `battle_win`/`battle_lose` play at game end. All SFX are registered in `AudioManager.SFX_PATHS`; AudioManager silently no-ops if the wav file is absent.
- **Background music (TID-081):** `AudioManager.play_music(path)` loads an OGG file, plays it at −6 dB (≈0.5 linear), and loops via `finished` signal reconnect; same-track guard prevents restarts; graceful no-op if file absent. `BattleScene._ready()` calls `AudioManager.play_music("res://assets/audio/music/battle.ogg")`. `WorldScene` detects biome changes in `_update_chunks()` via `InfiniteWorldGen.biome_for_chunk()` and plays the matching track from `_BIOME_MUSIC` (grasslands / forest / desert / scorched / mountains). Named-map worlds play `dungeon.ogg`. On `GameBus.battle_won`, WorldScene resumes the correct world track (biome or dungeon). All music files are under `assets/audio/music/*.ogg`; absent files are silently skipped.
- **Status effect processing (TID-061):** at start of each player's turn, poison ticks (damage = value, decrement), freeze decrements, hero stun decrements; minion stun handled by `CardInstance.start_turn()` via `out_of_play`
- **Screen shake (TID-079):** `_trigger_shake(magnitude, duration)` tweens the BattleScene root Control's `position` through random ±magnitude offsets every 0.05s for the specified duration, then snaps back to origin. `_is_shaking` flag prevents overlapping shakes. `_check_shake_from_snapshot(snap)` evaluates the HP-diff snapshot: hero death triggers a 10px/0.35s shake; any single-step hit of ≥5 HP triggers a 5px/0.2s shake. Called at all 8 snapshot sites.
- **Hit flash (TID-078):** `_flash_node(node, color)` instantly sets a node's `modulate` to the flash color then tweens back to white over 0.25s. Red `(1, 0.3, 0.3)` for damage, green `(0.3, 1, 0.5)` for healing. At direct attack sites the target/attacker panels are captured before damage and flashed immediately (before `remove_card`, so dying minions flash too). At spell/AI/status sites `_flash_from_snapshot()` reuses the HP-diff snapshot to flash all surviving cards/heroes that had HP changes.
- **Floating damage/heal numbers (TID-077):** a `CanvasLayer` at layer 128 holds transient Label nodes. Before each damage/healing action, `_snapshot_hp_positions()` captures the HP and screen position of every card and hero on the board. After the action, `_spawn_float_labels_from_snapshot()` compares current HP to the snapshot and spawns labels for any delta. Labels tween upward 70px and fade from opaque to transparent over 0.8s, then `queue_free()`. Red (`#FF4444`) for damage, green (`#44FF88`) for healing. Covers: player minion attacks, player spells (non-targeted and targeted), AI actions, status tick damage, and auto-spell resolution.
- "End Turn" button calls `GameState.end_turn()`; AI actions fire after a short delay for readability
- Listens to `GameBus` signals to refresh UI after each state change

### Status Effects Data Model (TID-060)

`CardInstance` and `HeroState` each carry a `status_effects: Dictionary` (key: effect_id, value: int duration/stacks):

| Effect | Stored on | Behaviour |
|---|---|---|
| `poison` | CardInstance, HeroState | Deal value damage at turn start; value decrements each tick; removed at 0 |
| `armor` | CardInstance, HeroState | Absorbs incoming damage in `take_damage()`; remaining armor updated after each hit |
| `freeze` | CardInstance, HeroState | Minion: blocks `can_attack()`; hero: blocks `can_play()` via PlayerState; decrements at turn start |
| `stun` | CardInstance, HeroState | Like freeze but also bridges to `CardInstance.out_of_play` for minion attack blocking; hero stun decremented in BattleScene |

Helper methods on both types: `apply_status(id, val)`, `has_status(id)`, `get_status_value(id)`, `clear_status(id)`, `take_damage(dmg)`.

New GameBus signals: `status_applied(entity_id, effect_id, value)`, `status_ticked(entity_id, effect_id, remaining)`.

---

## Friendly Duel Mode (TID-143)

Duels are battles with coin wagers that do not award cards, XP, or mark enemies as defeated.

### How to start a duel
Emit `GameBus.duel_requested(enemy_data, wager)` from any NPC interaction. `SceneManager` handles the signal: it launches `BattleScene` with `duel_wager` set, exactly like a normal battle launch except no `pending_battle` is saved and enemy defeat is not tracked.

### GameState fields
- `friendly_duel: bool` — set `true` when `BattleScene.duel_wager > 0`. Persisted in `to_dict`/`from_dict` so mid-duel save/restore works.
- `wager_coins: int` — coin amount at stake; copied from `duel_wager`.

### End-of-battle branching (BattleScene._check_game_over)
When `_state.friendly_duel` is true the normal `battle_won`/`battle_lost` paths are bypassed:
- **Player wins** → `_show_duel_victory_overlay`: adds `wager_coins` to `SaveManager.coins`, then emits `GameBus.duel_won`.
- **Player loses** → `_show_duel_loss_overlay`: deducts `wager_coins` (floor 0), then emits `GameBus.duel_lost`.

`SceneManager` listens to `duel_won` and `duel_lost` and simply restores the world scene — no `GameOverScene`, no card/weapon/XP rewards.

### Duelist enemy types
Two duelist `EnemyData` resources in `data/enemies/`:
| ID | Display Name | Tier | Deck |
|---|---|---|---|
| `duelist_novice` | Novice Duelist | 1 | ghost×3, skeleton×3, zombie×2, ghoul, mend |
| `duelist_adept` | Adept Duelist | 2 | ghost×2, skeleton×2, zombie×2, ghoul×2, mend, wither, surge_spirit, ember_imp |

Both have empty `drop_pool` and `coin_reward = 0` (wager is handled outside the normal reward path).

---

## Integrations with Other Features

| System | Direction | Details |
|---|---|---|
| **World / Enemies** | Trigger → Battle | `GameBus.enemy_engaged(enemy_data)` fires when the player walks into an enemy; `enemy_data["enemy_deck"]` carries the enemy's card list |
| **EnemyRegistry** | Data source | `EnemyRegistry.get_enemy(type)` returns enemy deck composition by type string |
| **CardRegistry** | Data source | `CardRegistry.get_card(id)` resolves card template for each card in the deck |
| **SaveManager** | Player deck | `SaveManager.player_deck` is the `Array[String]` of card IDs loaded into `PlayerState[0]` at battle start |
| **SceneManager** | Scene routing | `GameBus.battle_won` → SceneManager grants reward card + restores WorldScene; `GameBus.battle_lost` → SceneManager loads GameOverScene |
| **EnemyRegistry** | Drop pool | `EnemyRegistry.get_drop_pool(enemy_type)` returns cards that may drop; BattleScene picks one at random and shows the victory overlay |
| **Inventory / Deck** | Deck source | Player's active battle deck is built from `SaveManager.player_deck` (managed in InventoryScene) |
| **GameBus signals** | Both | `card_played`, `card_attacked`, `turn_ended`, `battle_ended`, `status_applied`, `status_ticked` — BattleScene listens to turn_ended to refresh the UI; status signals available for future subscribers |

---

## Asset Requirements

| Asset | Path | Notes |
|---|---|---|
| Card data resources | `data/cards/*.tres` | One `CardData` resource per card type; minion fields: id, display_name, cost, attack, health, keywords (PackedStringArray); spell fields: card_class="spell", magic_type, magic_branch, spell_effect, spell_power |
| Enemy data resources | `data/enemies/*.tres` | `EnemyData` resource with id, display_name, deck (Array of card id strings) |
| BattleScene scene | `scenes/battle/BattleScene.tscn` | Root scene for battle UI overlay |
| Card slot textures | `assets/textures/` | Optional card art per id (falls back to colored panel if missing) |

No 3D geometry or shaders are required — the battle system is a 2D UI overlay.

---

## Battle UX Essentials (GID-026)

### Card Inspect Overlay (TID-086)

`scenes/battle/CardInspectOverlay.gd` — instantiated by `BattleScene._show_card_inspect(card)`.

- Full-screen dimmed backdrop (tap outside → dismiss)
- Centered panel showing: card color bar, name, class/magic type, cost/attack/health, description, spell effect in plain English, active status effects
- Close button + Escape key to dismiss
- Trigger: right-click on any card panel (all zones, always active via `_bind_card_input`)
- Mobile/touch: tap a hand card without dragging (tracked via `_drag_moved` flag in `_input()`)
- `_SPELL_EFFECT_LABELS` dictionary maps effect IDs to human-readable strings with `[power]` substitution

### Pause System (TID-088)

`BattleScene` manages pause state via `_paused: bool` and `_pause_overlay: CanvasLayer`.

- Pause button ("II") at top of SidePanel, `process_mode = ALWAYS`, `~5% vh` square
- `get_tree().paused = true/false` — pauses all non-ALWAYS nodes (AI timers, process loop, tweens)
- Pause overlay: `CanvasLayer` layer 200 with `process_mode = ALWAYS`; contains: Resume, Settings, Return to Menu
- "Return to Menu" shows inline confirm dialog before navigating away
- "Settings" opens `SettingsScene` inline in the pause overlay's CanvasLayer
- Escape key toggles pause (desktop only)
- `NOTIFICATION_APPLICATION_FOCUS_OUT` auto-pauses on app backgrounding (mobile)

### Mid-Battle State Persistence (GID-034)

When a player leaves a battle mid-fight (via "Return to Menu" confirm or app background kill), the full `GameState` is serialized and stored in `SaveManager.pending_battle_state`. On re-entry the battle is restored exactly.

**Serialization:** every battle state class has `to_dict()` / `from_dict()`:
- `GameState.to_dict()` — root entry point; captures `current_player_idx`, `turn_number`, and both `PlayerState` dicts
- `PlayerState.to_dict()` — hero, board, hand, draw_deck, discard, pending_auto_spells, bonus_draw
- `HeroState.to_dict()` — health, max_health, mana, max_mana, attack, status_effects
- `ZoneState.to_dict()` — Array[5] of CardInstance dicts or null
- `CardInstance.to_dict()` — all 21 fields including summoning_sick, attack_count, shroud_active, out_of_play, status_effects

`CardInstance.from_dict()` calls `new()` (the empty-dict no-op path of `_init`) then sets fields directly, preserving `instance_id` for cross-reference equality.

**Save triggers:**
- "Yes, leave" confirm in pause menu: `_state.to_dict()` → `SaveManager.set_pending_battle_state()` → `save_manager.save()` → `go_to_menu()`
- `NOTIFICATION_APPLICATION_FOCUS_OUT`: same save before auto-pausing

**Restore path (BattleScene._ready):**
```gdscript
var saved = SceneManager.save_manager.pending_battle_state
if not saved.is_empty():
    _state = GameState.from_dict(saved)
    SceneManager.save_manager.clear_pending_battle_state()
else:
    _state = GameState.new()
    # … normal deck build + start_turn(1)
```

**Cleared on:** `SceneManager._on_battle_won()` and `_on_battle_lost()` both call `save_manager.clear_pending_battle_state()` alongside `clear_pending_battle()`.

**Note:** `_hero_power_used` is not persisted — the player always gets their hero power back on resume, which is acceptable.

---

## Puzzle Battle Mode (GID-040)

Handcrafted "win-this-turn" puzzles found at glowing shrines in named maps. Each puzzle teaches a keyword interaction and rewards a rare card on first solve.

### Data Resources

**`game_logic/battle/PuzzleData.gd`** — `extends Resource`

| Field | Type | Description |
|---|---|---|
| `puzzle_id` | String | Unique key (matches PuzzleRegistry and SaveManager.solved_puzzles) |
| `title` | String | Display name |
| `hint_text` | String | Shown after a failed attempt |
| `player_hand` | Array[String] | Card IDs in the player's starting hand |
| `player_board` | Array[String] | Card IDs pre-placed on the player's board (no summoning sickness) |
| `player_mana` | int | Starting mana for the player |
| `player_hero_hp` | int | Player hero HP |
| `enemy_board` | Array[String] | Enemy board card IDs (no summoning sickness) |
| `enemy_hero_hp` | int | Enemy hero HP |
| `enemy_board_buffs` | Array[String] | Keyword buffs in `"slot_idx:keyword"` format |
| `reward_card_id` | String | Card awarded on first solve |

**`autoloads/PuzzleRegistry.gd`** — autoloaded node + static methods

- `get_puzzle(id: String) -> PuzzleData` — looks up by `puzzle_id`
- `all_ids() -> Array[String]` — returns all registered IDs
- All `.tres` files are const-preloaded (Android export safety)

### Puzzle Catalogue

| Puzzle ID | Map | Mechanic | Solution hint |
|---|---|---|---|
| `puzzle_surge_lethal` | madrian | Surge — attack immediately | Play Surge Spirit (2 mana), attack hero directly |
| `puzzle_ward_bypass` | maykalene | Ward — must kill Ward minion first | Skeleton kills Ward Ghost (2≥1HP), then Ghost attacks hero |
| `puzzle_shroud_timing` | farsyth_mansion | Shroud — absorbs first hit | Wraith attacks skeleton (Shroud absorbs 2 ATK, wraith lives), Ghost kills hero |
| `puzzle_attack_order` | blancogov | Attack sequencing | Ghost kills Ward Surge Spirit (both die), Skeleton kills hero |
| `puzzle_mana_efficiency` | blancogov_temple | Optimal mana spend | Blitz Ghoul (4 mana, Surge) + Spark spell (1 mana) = exactly 5 damage on hero |

### State Flow

```
GameBus.puzzle_requested(puzzle_id)
  └─ SceneManager._on_puzzle_requested()
       ├─ PuzzleRegistry.get_puzzle(id) → PuzzleData
       ├─ BattleScene instantiated with puzzle_data set
       └─ _state = GameState.load_puzzle(puzzle_data)

BattleScene._on_end_turn() [puzzle_mode]
  └─ game not won → _show_puzzle_fail()  [resets board, shows hint]

BattleScene._check_game_over() [puzzle_mode, winner == 0]
  └─ _show_puzzle_victory()
       └─ GameBus.puzzle_solved.emit(puzzle_data_id)
            └─ SceneManager._on_puzzle_solved()
                 ├─ Award reward_card_id as "rare" (first solve only)
                 ├─ SaveManager.mark_puzzle_solved(id)
                 └─ Restore world scene

BattleScene._on_puzzle_give_up()
  └─ SceneManager.return_from_puzzle()  [no reward]
```

### `GameState.load_puzzle(pdata)`

Static constructor that seeds a battle state from PuzzleData:
- Sets `puzzle_mode = true`, `puzzle_data_id`
- Clears default decks; no draw pile
- Populates player hand (no summoning sickness)
- Populates player/enemy boards (no summoning sickness, `attack_count = 1` so can attack immediately)
- Applies `enemy_board_buffs` keywords after board population
- Sets current_player_idx = 0 (always player's turn)
- Not persisted via `set_pending_battle_state` — no mid-puzzle save/restore

### Puzzle-Mode BattleScene Modifications

- "End Turn" button relabeled "Check" — pressing without lethal shows `_show_puzzle_fail()` overlay
- "Give Up" button added to SidePanel — calls `SceneManager.return_from_puzzle()` with no reward
- AI turn entirely skipped when `_state.puzzle_mode` is true
- `_show_puzzle_fail()`: reloads puzzle state via `GameState.load_puzzle(_puzzle_data_ref)`, shows hint text overlay
- `_show_puzzle_victory()`: green overlay, then `SceneManager.return_from_puzzle()` via Continue button

### World Integration

`game_logic/world/resources/MapPuzzleShrine.gd` — tile-positioned resource entity with `puzzle_id`.
`scenes/world/entities/PuzzleShrine.gd/.tscn` — glowing blue prism mesh with point light; dims when puzzle already solved.
`WorldScene._spawn_named_map_shrines()` — mirrors `_spawn_named_map_scrolls()`; interact via `_handle_interact()`.
`MapData.shrines: Array[Resource]` — serialized alongside scrolls, enemies, etc.
`WorldMap.shrines: Array[Dictionary]` — runtime list of `{id, x, z, puzzle_id}` dicts.

### SaveManager Fields (version 18)

`solved_puzzles: Array[String]` — list of solved puzzle IDs. Migrated from v17 via `_migrate_v17_to_v18` (backfills `[]`).

---

## Companion System (GID-041, TID-159)

One equipped companion grants a single passive battle effect. Excluded from puzzle battles and friendly duels; allowed in Spire runs.

### Data

`data/CompanionData.gd` — Resource with:
- `companion_id: String`, `display_name: String`, `description: String`
- `passive_type: String` — `"extra_mana"`, `"draw_card"`, or `"hero_armor"`
- `passive_value: int` — magnitude of the effect
- `unlock_story_flag: String` — story flag that must be set to unlock; `""` = always available
- `portrait: Texture2D` — optional portrait (falls back to a blue placeholder)

### Registry

`autoloads/CompanionRegistry.gd` (extends Node, registered as autoload) — static preload pattern matching `PuzzleRegistry`. Methods:
- `get_companion(id) -> CompanionData`
- `all_ids() -> Array[String]`
- `is_unlocked(id) -> bool` — checks unlock_story_flag against SaveManager; always true when flag is empty

### Passive Application

**Battle-start effects** (called once after `start_turn(1)` in `BattleScene._ready`):
- `"extra_mana"` — adds to `player.hero.mana`, capped at 10 (turn-1 mana boost only; does not change max_mana growth)
- `"hero_armor"` — calls `player.hero.apply_status("armor", value)`

**Turn-start effects** (called in `BattleScene._ready` for turn 1 AND in `_on_turn_ended(0)` for every subsequent player turn):
- `"draw_card"` — calls `player.draw_card()` × `passive_value`

### HUD

`BattleScene._add_companion_hud()` — adds a VBox to SidePanel showing companion portrait (or blue placeholder) + name + passive description. Called after `_add_hero_power_button()`. No-op if no companion is equipped or companion is not unlocked.

### CharacterScene Slot

Below the equipment slots, a "Companion" section shows a slot button. Tapping opens a picker listing all registered companions (locked ones greyed with their flag name). Uses `SaveManager.equip_companion(id)` / `unequip_companion()`.

### Companion Catalogue (GID-041, TID-160)

| id | display_name | passive_type | passive_value | unlock_story_flag |
|----|--------------|--------------|---------------|-------------------|
| `maiteln` | Maiteln | `draw_card` | 1 | `story_intro_complete` |

Maiteln's locked-state text in the picker: "Travel with Maiteln in the story to unlock."

First-equip: on first equip, `set_story_flag("companion_maiteln_first_equip")` is set and `SceneManager.show_toast("Maiteln", "Maiteln chuckles. 'Try to keep up, boy.'")` fires.

`story_intro_complete` is the earliest story flag set when Maiteln is encountered (GID-001). If GID-020 adds a "Maiteln joins" flag later, update `maiteln.tres` to use that flag.

### SaveManager Fields (version 26)

`active_companion: String` — currently equipped companion id, default `""`. Migrated from v25 via `_migrate_v25_to_v26` (backfills `""`). Mutators: `equip_companion(id)` and `unequip_companion()`.
