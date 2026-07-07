# UI and Scene Management

## Key Features

- `SceneManager` autoload owns the scene stack and routes all transitions (menu ↔ world ↔ battle ↔ game-over)
- Battle is an overlay: the world scene is detached from the tree during a fight and restored on win
- Map stack navigation supports arbitrarily deep dungeon nesting
- Day/night cycle updates sun/moon energy and sky colour every 0.5 seconds
- HUD elements: interact prompt, map name label, coin counter, dialogue fade
- All controls sized relative to viewport height (not fixed pixels) for resolution independence
- In-game `MapEditorScene` for level design and debug
- Mobile: `VirtualJoystick` overlay added at runtime when touchscreen detected
- M key opens `MapViewOverlay` in named maps: full 100×100 tile grid as a color-coded image with entity dots; not available in infinite world mode
- All modal overlay scenes extend `BaseOverlay` (GID-073); shared builder helpers in `UiUtil`

---

## Overlay Framework (GID-073)

### BaseOverlay (`scenes/ui/BaseOverlay.gd`)

All modal overlay scenes extend `"res://scenes/ui/BaseOverlay.gd"` using a string-path extends (not class_name). The base class provides:

| Member | Description |
|---|---|
| `signal closed` | Emitted when the overlay should close |
| `_vh`, `_vw` | Viewport height/width, set in `_ready()` |
| `_build_backdrop(alpha, close_on_tap)` | Full-screen dark ColorRect; optional tap-to-close |
| `_build_centered_panel(w, h)` | Centered PanelContainer (no custom style applied) |
| `_build_margin_vbox(parent, margin_frac, sep_frac)` | MarginContainer + VBoxContainer inside parent |
| `_make_dark_glass_style()` static | StyleBoxFlat with dark-blue glass look (for SettingsScene, CardInspectOverlay) |
| `_close()` | Emits `closed`; scenes that also need `queue_free()` override this |
| `_input(event)` | Handles `ui_cancel` → `_close()` |

Overlays that additionally need `queue_free()` on close override `_close()`:
```gdscript
func _close() -> void:
    closed.emit()
    queue_free()
```

### UiUtil (`scenes/ui/UiUtil.gd`)

Static helper file (preload with `const _UiUtil = preload("res://scenes/ui/UiUtil.gd")`):

| Static method | Description |
|---|---|
| `rarity_color(rarity)` | Returns Color for common/rare/epic/legendary |
| `rarity_badge(rarity)` | Returns `[C]`/`[R]`/`[E]`/`[L]` badge string |
| `effect_summary(type, value, count, card_id)` | Human-readable weapon effect text |
| `make_title_label(text, vh)` | Gold-colored, center-aligned label at `vh*0.038` |
| `make_body_label(text, vh)` | Light gray label at `vh*0.022` |
| `make_separator()` | HSeparator |
| `make_close_button(vh, on_pressed)` | Standard Close button |

### Migrated Overlays

All 9 modal overlays extend BaseOverlay (as of GID-073): `InventoryScene`, `ShopScene`, `SkillTreeScene`, `CharacterScene`, `JournalScene`, `AchievementsScene`, `SettingsScene`, `TutorialPopup`, `CardInspectOverlay` (scenes/battle).

`BiomeSelectionScene` is a full-screen new-game scene (not a modal), so it does not extend BaseOverlay.

---

## Menu Hub (GID-081)

### MenuHubScene (`scenes/ui/MenuHubScene.gd`)

Unified tabbed shell that hosts all four player-facing screens (Deck/Bag, Character, Skills, Journal) as switchable pages. Added in TID-296/297; replaces the four separate SceneManager overlay states.

**Structure:** backdrop → centered panel → VBox with [tab bar row, content area].

**Tab bar layout:** `[Close] [Deck/Bag] [Character] [Skills] [Journal]` — Close is on the LEFT so it never overlaps the minimap in the top-right corner.

**Layering:** `SceneManager.open_menu_hub()` wraps the hub in a `CanvasLayer` (layer 10, stored as `_menu_hub_layer`) so it renders above the HUD CanvasLayer (default layer 1). The layer is freed in `_on_menu_hub_closed()` and `_exit_world_cleanup()`.

**Tab IDs:** `"deck"`, `"character"`, `"skills"`, `"journal"`.

**Public API:**
```gdscript
hub.show_tab("skills")          # switch to a tab; safe to call any time
SceneManager.open_menu_hub("character")  # open or switch from world
```

**SceneManager routing:**
- `GameBus.inventory_requested` → `open_menu_hub("deck")`
- `GameBus.journal_requested` → `open_menu_hub("journal")`
- `GameBus.character_requested` → `open_menu_hub("character")`
- `GameBus.skill_tree_requested` → `tutorial_popup_requested.emit("skill_tree")` + `open_menu_hub("skills")`

If the hub is already open (`State.MENU_HUB`), `open_menu_hub(tab)` switches tabs on the existing hub instance instead of stacking a second overlay.

The four GameBus signals are preserved as the public API — HUD buttons, WorldScene key handlers, and other callers still emit them unchanged.

**Page contract:** Pages that embed in the hub receive `hub_mode = true` set before `add_child()`. In hub mode a page:
- Skips `_build_backdrop()` and `_build_centered_panel()`; instead builds a `MarginContainer` (FULL_RECT) → `VBoxContainer` into `self`
- Omits its Close button
- Does not emit `closed` on neutral actions (e.g., Save in InventoryScene)
- Overrides `_input()` to return early so it does not consume `ui_cancel` (Escape must close the hub, not the page)

All four pages are migrated (TID-296/297): `InventoryScene`, `CharacterScene`, `SkillTreeScene`, `JournalScene`.

**Key bindings and tab cycling (TID-299):**

| Action | Key | Mobile equivalent |
|---|---|---|
| Open hub → Deck/Bag | I | "Menu" HUD button |
| Open hub → Character | C | Tab bar "Character" button |
| Open hub → Skills | K | Tab bar "Skills" button |
| Open hub → Journal | J | Tab bar "Journal" button |
| Previous tab | `[` | Tab bar buttons |
| Next tab | `]` | Tab bar buttons |
| Close hub | Escape / ui_cancel | "Close" button in hub tab bar |

Tab cycling (`[`/`]`) is handled in MenuHubScene's `_input()` which also re-declares `ui_cancel` → `_close()` to prevent page nodes from consuming it first.

**State:** `SceneManager.State.MENU_HUB`. The four old states (INVENTORY, CHARACTER, SKILL_TREE, JOURNAL) are retained in the enum for backwards-compatibility but are no longer used by routing.

---

## HUD Action Registry & Party Panel (GID-107)

### The problem it solves

Every multiplayer/social task from GID-090 through GID-102 added its own `Button.new()` directly to `WorldScene.gd`'s HUD `CanvasLayer`, hand-positioned with `Vector2(vh*..., vw*...)` math, because there was no shared placement primitive. By the time GID-107 shipped this had produced 39 `Button.new()` call sites and several silent pixel overlaps: Leaderboard on top of Pause, Challenge-to-Battle on top of the Android USE button, the Ranked toggle on top of Trade, and (found later, still unmigrated — see `tasks/backlog/BID-043*.md`) Siege on top of Tournament.

### WorldHUD zones (`scenes/world/WorldHUD.gd`)

Each zone is a real `Container` node (`VBoxContainer` or `HBoxContainer`) childed directly to `_hud`, anchored at a fixed viewport-relative position. Godot's `BoxContainer` only allocates layout space to *visible* children, so a hidden action in a zone takes no space and two actions in the same zone cannot pixel-overlap — the auto-stacking is the actual anti-overlap mechanism, not a convention.

| Zone constant | Position | Contents |
|---|---|---|
| `ZONE_SYSTEM` | top-left `(vh*0.01, vh*0.01)` | Pause |
| `ZONE_NAV` | top-right, under the minimap | Menu/Bag, Mount, **Party** |
| `ZONE_ABILITY` | left column, `(vh*0.01, vh*0.17)` | Ghost Phase / Skeleton Dig cantrips |
| `ZONE_CONTEXT` | bottom-center, `(vw*0.5 - vh*0.17, vh*0.80)` | Interact (Android), Challenge/Ranked, Trade, Spectate |
| `ZONE_SOCIAL` | bottom-right, `(vw - vh*0.32, vh*0.87)` | Emote, Ping, Chat |

### API

```gdscript
# Simple press-callback button — creates on first call, idempotent thereafter
# (matches the existing _ensure_*_button() re-entrancy pattern used elsewhere).
_world_hud.register_action(id: String, label: String, zone: String, callback: Callable,
    visible_when: Callable = Callable(), min_size: Vector2 = Vector2.ZERO) -> Button

_world_hud.unregister_action(id: String) -> void
_world_hud.refresh_visibility(id: String = "") -> void   # re-evaluates visible_when
_world_hud.set_action_visible(id: String, v: bool) -> void  # direct setter (per-frame proximity checks)
_world_hud.get_action_button(id: String) -> Button
_world_hud.get_zone_container(zone: String) -> Container
```

A button that needs a `.toggled` connection (`toggle_mode = true`) rather than a plain `.pressed` callback — the Ranked toggle, the Ping toggle — can't go through `register_action` (its `callback` param is unconditionally wired to `.pressed`). Build it directly and parent it into the zone via `get_zone_container()` instead; see `WorldScene._ensure_challenge_button()`'s Ranked toggle for the pattern.

`WorldHUD.is_touch_on_hud_button(pos)` recurses into zone `Container` children (not just direct `_hud` children) so the Android tap-to-move guard still sees every registered button.

### Button press feedback + overlay pop (`scenes/ui/UiFx.gd`, TID-429)

`UiFx.attach(btn: BaseButton)` wires scale-on-press feedback (pivot-centered,
~0.93 down on `button_down`, back to 1.0 on `button_up`, `TRANS_QUAD`/
`EASE_OUT`, 0.08s) plus a `ui_click` SFX, skipped automatically when the
button is `disabled` (Godot doesn't fire `button_down` for a disabled
`BaseButton` anyway). Idempotent via a `has_meta("_uifx_attached")` guard, so
it's safe to call from a registry that re-registers the same button.
`register_action()` calls it for every HUD action; the remaining
hand-built HUD buttons (`_siege_btn`, `_auction_btn`, `_draft_duel_btn`,
`_tournament_btn`, `_ranked_toggle_btn`, `_ping_btn`, `_chat_send_btn` — the
same allow-list `test_hud_registry_guardrail.gd` tracks) call it explicitly
right after construction. `BaseOverlay` exposes `_attach_button_fx(btn)` as a
convenience wrapper for subclasses (used by `PartyPanel`'s action grid and
roster-row friend buttons); `UiUtil.make_close_button()` /
`make_rarity_selector()` call `UiFx.attach()` directly, covering every
overlay that uses those shared factories. `MenuScene._add_btn()` and
`BattleScene`'s End Turn/Menu buttons attach it too. `UiFx.pop_in(panel)`
(scale 0.96→1.0 + fade 0→1 over 0.12s, doesn't touch `mouse_filter`) is
called from `BaseOverlay._build_centered_panel()` — every overlay built on
top of it gets the open pop for free.

### Party panel (`scenes/ui/PartyPanel.gd`)

A single "Party" button in `ZONE_NAV` opens a `BaseOverlay`-based panel (same pattern as `GhostDuelOverlay`/`LeaderboardOverlay`/`PartyStashOverlay`: `extends BaseOverlay` by path string, `.new()`-instantiated, built from plain data/Callables the caller supplies rather than reaching into `WorldScene` internals). It consolidates the always-on co-op affordances that used to be individually-positioned buttons:

| Section | Gating | Notes |
|---|---|---|
| Roster | `_coop_active` | List of party members + per-peer add-friend button. Recomputed by `WorldScene._refresh_coop_roster()` into `_party_roster_rows`, pushed to the panel via `refresh_roster()` if open. |
| Loot Mode toggle | Host + `SessionStore.is_open()` | `_on_loot_mode_toggle_pressed()` unchanged; label refreshed via `refresh_loot_label()`. |
| Stash | co-op active | Opens `PartyStashOverlay` (Party panel closes first). |
| Leaderboard | co-op active | Opens `LeaderboardOverlay`. |
| Ghost Duels | Host + `SessionStore.is_open()` | A client never opens `SessionStore` locally, so this naturally stays hidden for clients. |
| Team Duel (2v2) | Host, not dedicated server, `State.WORLD`, ≥3 connected clients, no pending challenge | Mirrors the old `_update_team_duel_button_visibility()` condition exactly. |
| Dungeon Crawl | Host only | Host is the seed authority (avoids two peers racing to open different dungeons). |

Each section's `show_*` flag is computed fresh in `WorldScene._open_party_panel()` from the exact condition its old standalone button used — opening the panel is a placement change, not a behavior change. Pressing most actions closes the panel first (`close_after = true` in `PartyPanel._add_action_button`) so it doesn't visually stack behind the overlay it just opened; Loot Mode is the one exception (stays open so the label refresh is visible immediately).

The Auction House button (`_auction_btn`) and the Siege/Draft Duel/Tournament buttons are the same shape of always-on/host-gated clutter but were not in GID-107's original scope (Auction/Siege/Draft/Tournament all shipped from GID-102–105, overlapping with or after GID-107's authoring) — see `tasks/backlog/BID-042*.md` and `BID-043*.md`.

### Contextual action bar (`ZONE_CONTEXT`)

Proximity-/state-gated actions share one bottom-center zone instead of each computing an independent position. **Priority order:** the world-interact prompt (door/chest/NPC/scroll, Android-only `WorldHUD._interact_btn`) always wins the zone over any social action — `WorldHUD.is_interact_visible()` is checked at the top of both `WorldScene._update_challenge_proximity()` and `_update_social_proximity()`, hiding Challenge/Ranked or Trade/Spectate and returning early if true. This is a new explicit rule; previously these checks ran independently and could show two overlapping prompts simultaneously. Desktop's interact prompt is a separate screen-centered `Label` (`WorldScene.tscn`'s `InteractPrompt`, anchored at 0.5/0.5 — not viewport-relative like everything else, a pre-existing minor inconsistency, out of scope) and never contends with `ZONE_CONTEXT`, so it's intentionally excluded from `is_interact_visible()`.

Challenge/Ranked and Trade/Spectate can still be visible at the same time as each other (unchanged from before — both key off the same nearby-peer proximity check); zone-stacking means that no longer produces a pixel overlap even so.

### Social strip (`ZONE_SOCIAL`)

Emote, Ping, and Chat trigger buttons, left-to-right in that registration order. Chat's scrolling log panel (left side, always visible while co-op is active) and its free-text input + send row (bottom, `vh*0.93`) are separate elements not part of the strip — they don't compete for the same screen region, so there was no clutter motivation to move them.

### Anti-clutter regression test

`tests/unit/test_hud_registry_guardrail.gd` scans `WorldScene.gd`'s source text for `_hud.add_child(<Button-typed var>)` calls and fails if any identifier isn't in its `_ALLOWED_DIRECT_HUD_CHILDREN` allow-list (the pre-existing, reviewed exceptions: Siege/Auction/Draft Duel/Tournament buttons, the Chat send button, and the two `.toggled`-based fallback parents). Adding a new HUD button that bypasses the registry fails this test; the fix is either to use `register_action()`/`get_zone_container()`, or — if genuinely justified — add a reviewed entry to the allow-list.

---

## How It Works

### SceneManager (`autoloads/SceneManager.gd`)

The central scene router. It is an autoload and the only node that calls `get_tree().change_scene_to_*()` or manually adds/removes scenes.

**State machine:**
```
MENU → WORLD (new game or continue)
WORLD → [GAMBIT PICKER] → BATTLE (enemy_engaged signal; picker skipped on resume or auto-skip)
BATTLE → WORLD (battle_won signal)
BATTLE → GAME_OVER (battle_lost signal)
GAME_OVER → MENU (return to menu button)
WORLD ← → WORLD (map transition via map_stack)
WORLD ← → MENU_HUB (overlay, world stays in tree; one state replaces INVENTORY/CHARACTER/SKILL_TREE/JOURNAL)
WORLD ← → SHOP (overlay, world stays in tree)
WORLD → SPIRE_FLOOR (SceneManager.enter_spire via entrance panel in WorldScene)
SPIRE_FLOOR → SPIRE_FLOOR (SceneManager.exit_map detects spire_ prefix → _advance_spire_floor)
```

`open_menu_hub(tab)` is the single entry point for all four player screens. If state is already MENU_HUB, it calls `show_tab(tab)` on the live hub instead of stacking a second overlay. The old INVENTORY/CHARACTER/SKILL_TREE/JOURNAL state enum values are kept for backwards-compatibility but are no longer routed to.

**Gambit picker flow (GID-063):**

`SceneManager._on_enemy_engaged()` is split into two phases:
1. Guards + context stamping (as before).
2. If `save_manager.pending_battle_enemy_data` is non-empty (resume) OR `get_setting("auto_skip_gambits")` is `true` → call `_start_battle(enemy_data)` directly.
3. Otherwise → show `GambitPickerOverlay` in a `CanvasLayer` (layer 200). On `gambit_chosen(id)`, write `enemy_data["gambit_id"] = id` (if non-empty) and call `_start_battle(enemy_data)`.

`_start_battle(enemy_data)` contains the original `set_pending_battle` / `TransitionManager.transition` / world-detach logic. Keeping picker and battle start separate prevents the `CanvasLayer` from racing with the transition.

`GambitPickerOverlay` (`scenes/battle/GambitPickerOverlay.gd`) extends `BaseOverlay`. Signal: `gambit_chosen(gambit_id: String)` (empty = no gambit). Includes "Don't ask again" checkbox; checking it saves `set_setting("auto_skip_gambits", true)`. Escape key emits no-gambit on desktop.

**Spire routing:**

`enter_spire()` — called from the Spire entrance panel in madrian (door `target_map = "spire"`):
- If `save_manager.is_spire_active()` → resumes at `spire_floor_<floor>_<seed>` via `enter_map()`.
- Else → `start_spire_run(randi())`, pushes `spire_floor_1_<seed>` via `enter_map()`.

`exit_map()` — if `current_map.begins_with("spire_floor_")` and spire is active → calls `_advance_spire_floor()` (increments floor counter, loads next floor) instead of popping the map stack.

`_on_battle_won()` — Spire branch: saves `hero_hp`, sets cleared flag for the exit door, shows `SpireDraftScene` overlay, skips standard card/coin rewards.

`_on_battle_lost()` — Spire branch: calls `_restore_spire_entry_point()` then `save_manager.end_spire_run()`, emits `GameBus.spire_run_ended`, shows `RunSummaryScene` with `spire_stats` set. Does NOT route to `GameOverScene`.

`go_to_menu()` — Spire retreat branch: same flow as death when `is_spire_active()` and state is WORLD. Player retreats voluntarily, run ends, Spire summary shown.

`_restore_spire_entry_point()` — pops the pre-Spire map from `map_stack` and sets `save_manager.current_map` so that continue-after-run-end loads the entrance town (madrian), not a floor.

Madrian entrance door: `entity_id = "spire_entrance"`, tile (70, 36), `target_map = "spire"`. WorldScene intercepts this and calls `_show_spire_entrance_panel()` instead of `enter_map()`.

**Battle overlay pattern:**
```gdscript
# On enemy_engaged:
_world_node = get_tree().current_scene   # keep reference
get_tree().root.remove_child(_world_node) # detach (not free)
var battle = BattleScene.instantiate()
get_tree().root.add_child(battle)

# On battle_won:
get_tree().root.remove_child(battle)
battle.queue_free()
get_tree().root.add_child(_world_node)   # restore world
```

This keeps all world state (chunk cache, player position, NPC nodes) alive during the battle without re-loading.

### Map Transitions

`SceneManager.enter_map(map_name, target_door_id)`:
1. Push `{ map: current_map, pos: player_pos, return_door: current_door_id }` to `SaveManager.map_stack`
2. Replace `WorldScene`'s `WorldMap` with the new map loaded from file
3. Teleport player to the door tile whose ID matches `target_door_id`

`SceneManager.exit_map_via_door(door_node)`:
1. Pop top entry from `SaveManager.map_stack`
2. Restore previous `WorldMap`
3. Teleport player to the saved return door tile

### TransitionManager (`autoloads/TransitionManager.gd`)

Global CanvasLayer (layer 100, `PROCESS_MODE_ALWAYS`) that provides fade-to-black transitions between scenes.

- Full-screen black `ColorRect` starts fully transparent with `MOUSE_FILTER_IGNORE`
- `transition(change_fn: Callable)` — fire-and-forget coroutine: fades to black (0.2s), calls `change_fn`, awaits one process frame, fades back in (0.2s)
- Both tweens use `TWEEN_PAUSE_PROCESS` so they work when `get_tree().paused = true`
- `_transitioning` guard prevents overlapping transitions; if one is already running, `change_fn` is called immediately without a new fade
- All `SceneManager` scene swaps are wrapped in `TransitionManager.transition(func() -> void: ...)` lambdas

### MenuScene (`scenes/ui/MenuScene.gd`)

- **New Game** and **Continue** buttons both → `SceneManager.go_to_slot_select()` (slot select screens handles the distinction)
- **Settings** button → opens `SettingsScene` overlay
- Animated title: scale 0.85→1.0 + alpha 0→1 on load (0.5s tween), then idle scale-breathe loop 1.0→1.02→1.0 (3s period)
- Version label bottom-left: reads `ProjectSettings.get_setting("application/config/version")`

### SlotSelectScene (`scenes/ui/SlotSelectScene.gd`)

- Shows 3 save slots with per-slot metadata (current map, coins, last_saved timestamp)
- Occupied slot: **Continue** (loads that slot) + **Delete** (requires confirm dialog)
- Empty slot: **New Game** (routes to `BiomeSelectionScene`)
- Back button returns to `MenuScene`
- Calls `SaveManager.set_active_slot(n)` before any navigation

### OverworldPauseOverlay (`scenes/ui/OverworldPauseOverlay.gd`)

CanvasLayer (layer 200, `PROCESS_MODE_ALWAYS`) that pauses the game tree.

- Sets `get_tree().paused = true` in `_ready()`; restores on close
- Signals: `resumed`, `quit_to_menu`
- **Resume** button / `pause` action in `_input()`: unpauses and emits `resumed`
- **Settings** button: adds `SettingsScene` as a child overlay
- **Save & Quit**: calls `SaveManager.save()` then `SceneManager.go_to_menu_direct()`, emits `quit_to_menu`
- Triggered from `WorldScene._open_pause()` (HUD "II" button or `pause` input action)

### SettingsScene (`scenes/ui/SettingsScene.gd`)

Overlay (extends Control, emits `closed`) showing volume and accessibility controls. Entry points: MenuScene Settings button, OverworldPauseOverlay, and BattleScene pause menu.

**Audio section:**
- **Music Volume** HSlider (0–1, default 0.5) — calls `AudioManager.set_music_volume(v)` and `SaveManager.set_setting("music_volume", v)`
- **SFX Volume** HSlider (0–1, default 1.0) — calls `AudioManager.set_sfx_volume(v)` and `SaveManager.set_setting("sfx_volume", v)`

**Accessibility & Comfort section:**
- **Screen Shake** `CheckButton` — persists `"screen_shake"` (default `true`); `BattleScene._trigger_shake()` checks this before shaking
- **Text Scale** `OptionButton` (Small=0.85 / Normal=1.0 / Large=1.25) — persists `"text_scale"` (default `1.0`)
- **Haptics** `CheckButton` (shown only on `OS.has_feature("mobile")`) — persists `"haptics"` (default `true`); `BattleScene._haptic(ms)` checks before calling `Input.vibrate_handheld(ms)`

**Battle section (GID-069 TID-254):**
- **Battle Speed** toggle row (Normal / Fast) — persists `"battle_speed"` (`"normal"` / `"fast"`); `BattleScene._ready()` reads this and sets `_speed_scale = 0.45` for fast mode. Default `"normal"` requires no migration.

**Keybindings section (GID-109 / TID-409+410) — desktop only:**
- Hidden entirely on `OS.has_feature("mobile") or OS.has_feature("android")`.
- One row per action in `SceneManager.REBINDABLE_ACTIONS` (13 total): Action Name label | Current Key label | "Change" button.
- "Change" shows a fullscreen capture overlay (`_show_capture_overlay`); next key press (not Esc) is saved to `SaveManager.settings["keybindings"][action] = physical_keycode` and `SceneManager.apply_keybindings()` is called immediately.
- Escape during capture cancels without changing.
- Conflict detection: if the chosen key is already used by another action, the key label turns amber and a tooltip names the conflicting action. The binding is still saved.
- "Reset to Defaults" clears the `"keybindings"` setting dict entirely and calls `apply_keybindings()` (which reloads from project defaults via `InputMap.load_from_project_settings()`).

Values apply immediately on change and persist across sessions. Dismissed by Close button, tapping the backdrop, or Escape key.

### BiomeSelectionScene (`scenes/ui/BiomeSelectionScene.gd`)

- Displays one button per biome (Grasslands, Forest, Desert, Scorched, Mountains)
- On selection: calls `SceneManager.start_new_game_with_biome(biome_id)` then transitions to `WorldScene`
- Back button → `SlotSelectScene` (not MenuScene directly)
- UI scales buttons by viewport height

### GameOverScene (`scenes/ui/GameOverScene.gd`)

- Shown after `GameBus.battle_lost` for **spire** and **siege** losses only
- "Return to Menu" button frees the game-over scene and loads `MenuScene`
- Does **not** delete the save file; player can continue from the last save

### Defeat Overlay (GID-069 TID-250)

Regular (non-spire, non-siege) battle losses no longer route to `GameOverScene`. Instead:

1. `SceneManager._on_battle_lost()` copies the enemy data into `_defeat_pending_enemy_data`, calls `clear_pending_battle_state()`, frees `_battle_overlay`, and re-adds the world scene via `TransitionManager.transition()`.
2. `_show_defeat_overlay()` adds a `CanvasLayer` (layer 200) on top of the restored world with three buttons: **Retry Battle**, **Respawn**, **Return to Menu**.

**Button behaviours:**
- **Retry Battle** (`_on_defeat_retry()`): frees the overlay, calls `_start_battle(_defeat_pending_enemy_data)` — starts a fresh battle against the same enemy.
- **Respawn** (`_on_defeat_respawn()`): frees the overlay, calls `save_manager.clear_pending_battle()`, sets a 3 s `engage_cooldown` on the nearest EnemyNPC to prevent instant re-engagement.
- **Return to Menu** (`_on_defeat_menu()`): frees the overlay, calls `clear_pending_battle()`, then `go_to_menu()`.

**SceneManager fields:**
- `_defeat_overlay: Node` — reference to the overlay CanvasLayer (freed on any choice).
- `_defeat_pending_enemy_data: Dictionary` — enemy data saved at loss time; cleared after Retry or Menu.

**`_exit_world_cleanup()`** frees `_defeat_overlay` if it exists when the player exits the world (e.g. go_to_menu from inside the overlay).

### Day/Night Cycle

In `WorldScene._process()`:
```gdscript
_time_of_day = fmod(_time_of_day + delta / DAY_LENGTH, 1.0)  # DAY_LENGTH = 600 s
if _cycle_update_timer >= 0.5:
    _apply_lighting(_time_of_day)
    _cycle_update_timer = 0.0
```

`_apply_lighting()`:
- `sun_light.light_energy = max(0, sin(time_of_day * PI))`
- `moon_light.light_energy = max(0, -sin(time_of_day * PI))`
- `WorldEnvironment` sky colour lerped between day and night palettes

`time_of_day` is read from `SaveManager` on load and written back on map exit.

### HUD (`WorldHUD.gd` / `WorldScene.gd`)

HUD elements are constructed by `WorldHUD.gd` (owned and set up by WorldScene). They are parented to a `CanvasLayer` (always on top):

**System/navigation controls (TID-298 declutter):**
- **Pause button** (`II`) — top-left `(vh*0.01, vh*0.01)`, size `vh*0.07 × vh*0.07`. Opens `OverworldPauseOverlay` (which contains Resume / Settings / Save & Quit). Replaces the old Menu + II pair.
- **Menu/Bag button** — right side under the minimap. Opens `MenuHub` on the Deck/Bag tab via `SceneManager.open_menu_hub("deck")`. Replaces the old four-button stack (Inventory / Journal / Character / Skills).
- **Mount button** — right side below Menu button, hidden until the player owns a mount on the main map. Calls `_toggle_mount()`.

**Action cluster (TID-298):**
- **[G] Phase** cantrip button — left side at `vh*0.17`. Calls `_activate_ghost_phase()`. Visible only when `CantripManager.is_available("ghost_phase", deck_ids)`. Refreshed on `GameBus.inventory_changed`.
- **[D] Dig** cantrip button — left side below Phase. Calls `_activate_skeleton_dig()`. Gated on `CantripManager.is_available("skeleton_dig", deck_ids)`.
- `WorldHUD.refresh_action_cluster()` rechecks availability and updates visibility; connected to `GameBus.inventory_changed`.

**Informational elements (unchanged):**
- **Interact prompt** — on desktop: `_interact_label` Label (`"[E] Interact"`); on Android: `_interact_btn` Button (`"USE"`, `vh * 0.18 × vh * 0.08`) positioned center-bottom at `vh * 0.80`. Both are hidden until the player is within `INTERACT_RANGE` of a door, chest, NPC, or scroll. On Android the button calls `_handle_interact()` directly when tapped.
- **Map name label** — displayed for 3 seconds on map load, then fades. Font `vh * 0.032`.
- **Coin counter** — reads `SaveManager.coins` each frame. Font `vh * 0.03`.
- **Level label** — `"Lv.X"` bottom-left, font `vh * 0.028`.
- **XP bar** — `ProgressBar` beside level label, height `vh * 0.032`.
- **XP fraction label** — `"current / next XP"` beside bar, font `vh * 0.025`.
- **Dialogue label** — shown above NPC; fades out after 4 seconds. Font `vh * 0.03`.
- **Tutorial tip label** — yellow-tinted one-shot hints; auto-hides after 5 seconds (`TIP_DURATION`). Font `vh * 0.03`. Four triggers, each shown exactly once (flag stored in `SaveManager.story_flags`):
  - World entry → inventory button hint (`tutorial_inventory_tip`)
  - First NPC proximity → talk hint (`tutorial_npc_tip`)
  - First chest proximity → open hint (`tutorial_chest_tip`)
  - First enemy proximity → battle hint (`tutorial_enemy_tip`)
  - Android vs desktop control names chosen via `OS.has_feature("android")`
- **Minimap** — circular, diameter `vh * 0.20` (top-right corner). See Minimap section.
- **Compass ribbon** — `vh * 0.04` tall, `vw * 0.40` wide, centred at the top of the screen (`vh * 0.01` from top). See Compass Ribbon section below.

### Compass Ribbon (`scenes/ui/CompassRibbon.gd`)

A horizontal `Control` node parented to the HUD `CanvasLayer`. It shows cardinal-direction tick marks (W/S/E/N) and coloured dot markers registered by other systems.

**Bearing math:**
The isometric camera faces NE (azimuth −45°), so NE is permanently at the ribbon centre. The mapping from world bearing `θ` (radians, `atan2(dz, dx)`) to ribbon local X:
```
ribbon_x = ribbon_width/2 + (deg(θ) + 45) / 360 * ribbon_width
```
Clamped to `[0, ribbon_width]`. Cardinal positions (ribbon_width = W):
| Direction | Bearing | ribbon_x |
|-----------|---------|----------|
| West  | −π   | W × 0.125 |
| South | −π/2 | W × 0.375 |
| NE ↑  | −π/4 | W × 0.500 (centre) |
| East  | 0    | W × 0.625 |
| North | +π/2 | W × 0.875 |

Bearings > 135° (SW/behind the camera) clamp to the right edge.

**Marker API:**
```gdscript
compass.add_marker("waypoint", Color.YELLOW, func() -> Variant: return world_pos)
compass.remove_marker("waypoint")
compass.set_current_map("maykalene")  # call on every map transition
```
`get_pos` is a Callable returning `Vector3` (world pos) or `null` (hidden).

**Integration:**
`WorldScene` instantiates one `CompassRibbon` in `_ready()`, passes `_player`, and calls `set_current_map(map_name)`. Other systems call `add_marker` / `remove_marker` on the compass node.

**Static helpers (testable):**
- `CompassRibbon.bearing_to_ribbon_x(bearing_rad, ribbon_width) → float`
- `CompassRibbon.compute_bearing(fx, fz, tx, tz) → float`

### Compass Ribbon (`scenes/ui/CompassRibbon.gd`)

Horizontal 360° bearing ribbon rendered at the top-center of the HUD.  The isometric camera is fixed, so the ribbon itself never rotates — only marker dots slide left/right as the player moves relative to targets.

**Bearing convention**

`atan2(target.z - player.z, target.x - player.x)` gives the world bearing (`0` = East/+X, `−π/2` = North/−Z).  The ribbon maps this linearly so that N/E/S/W land at equal intervals (each `ribbon_width/4` apart):

| Direction | World | ribbon_x offset from center |
|---|---|---|
| W | −X | −3 × width/8 |
| N | −Z | −1 × width/8 |
| **NE** (iso screen-right) | +X, −Z | **0 (center)** |
| E | +X | +1 × width/8 |
| S | +Z | +3 × width/8 |
| SW | −X, +Z | ±width/2 (edges, wrapping) |

Static formula: `bearing_to_ribbon_x(bearing_rad, ribbon_center, ribbon_width)`.

**Sizing** — set by `WorldScene._ready()` before calling `setup()`:
- Width = `vw × 0.40`, height = `vh × 0.04`
- Position: X = `(vw − width) / 2`, Y = `vh × 0.01` (top-center, clears the Menu button)

**Marker API**

```gdscript
compass.add_marker("waypoint", Color.YELLOW, func() -> Vector3: return waypoint_pos)
compass.add_marker("enemy",    Color.RED,    func() -> Vector3: return enemy.position, "maykalene")
compass.remove_marker("waypoint")
compass.set_current_map("madrian")  # call on every map transition
```

- `get_pos: Callable` is called every frame and must return a `Vector3` (or `null` to hide).
- If `map` is non-empty and doesn't match `_current_map`, the marker clamps to the ribbon edge (left or right, based on direction) to indicate an off-screen target.

**Integration** — `WorldScene._ready()` instantiates the ribbon after `_spawn_player()`, stores it in `_compass`, and calls `compass.set_current_map(map_name)`.  Future tasks (TID-183 waypoint, TID-184 story objective) call `add_marker()` to register their markers.

### TutorialPopup (`scenes/ui/TutorialPopup.gd`)

Reusable modal overlay for in-game tutorial guides. Any system can trigger one by emitting `GameBus.tutorial_popup_requested(popup_id)`.

**Flow:**
1. Emitter calls `GameBus.tutorial_popup_requested.emit("skill_tree")` (or any registered ID).
2. `SceneManager._on_tutorial_popup_requested()` checks `SaveManager.get_story_flag("seen_tutorial_" + popup_id)` — skips if already seen.
3. Looks up content in `TutorialRegistry.get_entry(popup_id)` — skips if ID unknown.
4. Sets the seen flag immediately, instantiates `TutorialPopup`, calls `popup.setup(title, body)`, adds to `get_tree().root`.
5. On `closed` signal: popup is freed.

**Layout:** full-screen dark backdrop (alpha 0.65) → centered `PanelContainer` (70% vw × 50% vh) → `VBoxContainer` with title label (3.5% vh), separator, autowrap body label, "Got it" button (5.5% vh tall).

**Dismiss:** "Got it" button press OR `ui_cancel` / `ui_accept` key.

**Adding a new popup:** add one entry to `game_logic/TutorialRegistry.gd`'s `_DATA` dict — no UI code changes needed.

### BattleScene — First-Battle Tutorial Overlay

On the player's first battle (flag `tutorial_battle_tip` not set), a semi-transparent `ColorRect` overlay is shown centred on screen:
- Text: `"Drag a card from your hand to the board to play it.\nTap an enemy minion to attack with your minion."`
- `"Got it"` button dismisses immediately
- Auto-dismisses after 8 seconds (`TUTORIAL_DURATION`) via `_process()`
- Also dismissed on first successful card play in `_finish_hand_drag()`
- On dismiss: `SaveManager.set_story_flag("tutorial_battle_tip")` — never shown again

### MapEditorScene (`scenes/ui/MapEditorScene.gd`)

In-game debug tool (not accessible from the main menu in release builds):
- Loads a `WorldMap` and renders it in the same isometric view
- Tile-paint tools: toggle GRASS / WALL / HILL per click
- Entity placement: select type from toolbar, click to place
- Save button writes to `user://maps/<name>.txt`
- Load button opens a file picker for `user://maps/`

### Viewport-Relative UI Sizing

All controls size themselves in `_ready()` (and re-apply in `_notification(NOTIFICATION_RESIZED)`):

```gdscript
var vh: float = get_viewport().get_visible_rect().size.y
button.custom_minimum_size = Vector2(vh * 0.15, vh * 0.055)
label.add_theme_font_size_override("font_size", int(vh * 0.022))
```

Recommended fractions: buttons 12–18% width, 5–6% height; font 2–2.5% height.

---

## Integrations with Other Features

| System | Direction | Details |
|---|---|---|
| **GameBus** | Signal source | `enemy_engaged`, `battle_won`, `battle_lost`, `map_transition_requested`, `inventory_requested` all route through SceneManager |
| **SaveManager** | State source | `map_stack`, `current_map`, `time_of_day`, `coins` read/written by SceneManager and WorldScene |
| **BattleScene** | Overlay | Instantiated on `enemy_engaged`; removed on `battle_won` / `battle_lost` |
| **SettingsScene** | Overlay | Opened from MenuScene or battle pause menu; emits `closed` signal; persists volume prefs |
| **InventoryScene** | Overlay | Instantiated on `inventory_requested`; removed on close |
| **ShopScene** | Overlay | Instantiated on `shop_requested` (player interacts with MerchantNPC); lists all cards for 15 coins; removed on close |
| **WorldMap / InfiniteWorldGen** | Data source | SceneManager chooses which path to use based on map name (`"infinite"` key) |
| **Player** | Position sync | SceneManager teleports player on map transitions and door traversal |
| **VirtualJoystick** | Mobile input | Added to HUD CanvasLayer when `DisplayServer.is_touchscreen_available()` |

---

## Asset Requirements

| Asset | Path | Notes |
|---|---|---|
| MenuScene | `scenes/ui/MenuScene.tscn` | Title screen |
| BiomeSelectionScene | `scenes/ui/BiomeSelectionScene.tscn` | New-game biome picker |
| GameOverScene | `scenes/ui/GameOverScene.tscn` | Death screen |
| MapEditorScene | `scenes/ui/MapEditorScene.tscn` | Debug/editor tool |
| SettingsScene | `scenes/ui/SettingsScene.gd` | Volume sliders overlay (GID-026) |
| ShopScene | `scenes/ui/ShopScene.tscn` | Merchant shop overlay |
| VirtualJoystick scene | `scenes/ui/VirtualJoystick.tscn` | Mobile overlay |
| TutorialPopup | `scenes/ui/TutorialPopup.gd` | Pure-code modal overlay; no .tscn needed |
| TutorialRegistry | `game_logic/TutorialRegistry.gd` | Static data store for popup content |
| `SceneManager.gd` | `autoloads/SceneManager.gd` | Autoload singleton |
| UI theme / font | `assets/` | Optional custom theme `.tres`; falls back to Godot default |
| Title art | `assets/textures/` | Background for MenuScene (optional) |
