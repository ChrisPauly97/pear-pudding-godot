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

`CardInstance` wraps a `CardData` resource (loaded from `data/cards/*.tres`) and tracks mutable runtime state separately from the static template data.

### Turn Sequence

1. **Turn start** — active player's max mana increments (min 1, max 10); current mana refills to max; all minion `attacks_this_turn` reset to 0; all `summoning_sick` flags cleared.
2. **Draw** — active player draws one card from their draw pile (shuffles discard into draw if empty).
3. **Action phase** — active player plays cards and/or attacks until they press "End Turn":
   - *Play card*: costs mana equal to `CardData.cost`; card moves from hand to an empty board slot; new `CardInstance` is created with `summoning_sick = true`.
   - *Attack with minion*: target is any enemy minion or the enemy hero; damage is applied to both combatants; destroyed minions move to discard.
   - *Attack hero directly*: if no enemy minions block, or player targets hero explicitly.
4. **AI turn** — `BasicAI` evaluates board state, plays affordable cards greedily (lowest cost first), then attacks with every available minion (targets minions before hero).
5. **Win check** — after any damage event, if either hero drops to 0 HP `GameState` emits `battle_ended` with the result.

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
- `spell_effect: String` — canonical effect key dispatched by the battle engine (e.g. `"deal_damage_single"`, `"deal_damage_all"`, `"debuff_attack"`, `"destroy_low_hp"`, `"resurrect_last"`); `""` for minions
- `spell_power: int` — numeric parameter for the effect (damage amount, stat reduction, etc.); `0` for minions

Minion cards (Ghost, Skeleton, Zombie, Ghoul) leave the four spell fields at their defaults (`""` / `0`) and are unaffected.

`CardRegistry` (autoload) loads all `.tres` files from `data/cards/` at startup and exposes `get_card(id)` for lookups.

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
- Renders each player's board as 5 slot panels
- Hero panels show current/max HP and mana pips
- Drag-to-play: card dragged from hand onto an empty board slot triggers `GameState.play_card()`
- "End Turn" button calls `GameState.end_turn()`; AI actions fire after a short tween delay for readability
- Listens to `GameBus` signals to refresh UI after each state change

### Card Frame Rendering

Each card is a plain `Control` root node with two children:
- `FrameRect` (`ColorRect`, `MOUSE_FILTER_IGNORE`, `PRESET_FULL_RECT`) — background drawn by `card_frame.gdshader`; `base_color` uniform set from `CardData.color`; `selected` bool turns the border yellow; optional `illustration` sampler (upper 55% of card interior) enabled by `has_illustration` bool
- `ContentMargin` (`MarginContainer`, `PRESET_FULL_RECT`) — wraps the `VBoxContainer` with name/stats/description labels

The `_apply_card_style()` method updates shader parameters; `_make_card_view()` creates the node tree; `_add_card_frame_children()` can rebuild it after a structure mismatch.

`ShaderMaterial` instances are created via `game_logic/CardFrameMaterial.gd` (`CardFrameMaterial.make(color, illustration)`) — the same helper is used by `InventoryScene` for its card swatches. Illustration PNGs belong in `assets/cards/`; cards without one fall back to the solid color-fill branch in the shader.

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
| **GameBus signals** | Both | `card_played`, `card_attacked`, `turn_ended`, `battle_ended` — BattleScene listens to these to refresh the UI |

---

## Asset Requirements

| Asset | Path | Notes |
|---|---|---|
| Card data resources | `data/cards/*.tres` | One `CardData` resource per card type; minion fields: id, display_name, cost, attack, health; spell fields: card_class="spell", magic_type, magic_branch, spell_effect, spell_power; optional `illustration: Texture2D` |
| Enemy data resources | `data/enemies/*.tres` | `EnemyData` resource with id, display_name, deck (Array of card id strings) |
| BattleScene scene | `scenes/battle/BattleScene.tscn` | Root scene for battle UI overlay |
| Card frame shader | `assets/shaders/card_frame.gdshader` | `canvas_item` shader; draws border + bevel + optional illustration |
| Card illustrations | `assets/textures/` | Optional per-card `Texture2D` assigned to `CardData.illustration`; falls back to solid color fill |

No 3D geometry is required — the battle system is a 2D UI overlay.
