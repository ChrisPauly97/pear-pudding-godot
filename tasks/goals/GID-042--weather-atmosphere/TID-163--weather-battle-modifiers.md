# TID-163: Weather Battle Modifiers + Battle HUD Banner

**Goal:** GID-042  
**Type:** agent  
**Status:** done  
**Depends On:** TID-161

## Lock

**Session:** none  
**Acquired:** —  
**Expires:** —

## Context

Makes weather mechanical: battles started during rain, sandstorms, or snow have gameplay effects, displayed to the player in a banner. Modifiers are simple and integrate with existing card/status effect systems (see **docs/agent/battle-system.md** lines 156–169 for status_effects infrastructure and **docs/agent/battle-system.md** lines 58–72 for keyword/spell mechanics).

## Research Notes

- **Weather modifier design (simple, implementable v1):**
  - **Clear/dust_devil/volcanic:** No modifier (clear and volcanic are rare/v2, dust_devil skipped for v1).
  - **Rain:** Friendly Ghost minions gain `+1 max_health` when summoned (apply as a one-time buff during emergence or `play_card`). Rationale: Ghosts thrive in wet conditions. **Implementation:** In **scenes/battle/BattleScene.gd** `_on_card_played()` or `PlayerState.play_card()`, check `if WeatherManager.current_weather == "rain" and card.id == "ghost": apply_status(card, "bonus_health", 1)` or directly `card.max_health += 1` before the card is placed.
  - **Heavy rain:** Friendly Ghost minions gain `+2 max_health` (stronger version of rain).
  - **Sandstorm:** All minions (both players) gain `-1 attack` for the first turn of the battle (simulates disorientation). **Implementation:** At turn start in `GameState.start_turn()`, if weather is sandstorm and this is turn 1, iterate both players' boards and apply `status_effects["attack_debuff"] = 1` (handled by existing `apply_status()` code; the status decrements at next turn start).
  - **Ash fall:** Enemy hero gains `+2 poison` at battle start (atmospheric hazard). **Implementation:** After battle init, in `BattleScene._ready()` after `_state = GameState.new()` or `_state = GameState.from_dict()`, call `_state.players[1].hero.apply_status("poison", 2)`.
  - **Snow:** Both heroes' first card each turn costs `1` less mana (cold slows actions but conserves energy). **Implementation:** Modify `PlayerState.play_card(card)` to check `if WeatherManager.current_weather == "snow"` and this is the first card of the turn — reduce cost by 1 (floor 0).
  - **Blizzard:** Snow modifier + all minions have `freeze` applied at turn start (second, cumulative freeze lasts 1 turn). **Implementation:** Extend the snow logic; add `apply_status("freeze", 1)` to all minions on turn 1.
- **Modifier application timing:**
  - **Hero poison (ash):** During `BattleScene._ready()` or `GameState.__init()`, after both players are initialized. Early, before any game loop.
  - **Card-on-summon bonuses (rain/heavy_rain):** In the card-play path: either `PlayerState.play_card()` post-placement or `BattleScene._resolve_emergence()` if using emergence effects (simpler: check weather in `PlayerState.play_card()` after `board.add_card(card)`).
  - **First-turn debuffs (sandstorm, blizzard):** In `GameState.start_turn()` after clearing summoning sickness, if `turn_number == 1`, apply the modifier.
  - **Per-turn cost reduction (snow):** Track a `_first_card_this_turn: bool` flag in `PlayerState`; set `true` at turn start, set `false` after first card play. Apply cost reduction only on first card.
- **Battle entry context:** WeatherManager.current_weather only applies if battle starts in the infinite world. Named maps and dungeons are always clear (check confirmed in **docs/agent/world-generation.md** — only infinite world uses weather). Confirm at battle start: if `SaveManager.current_map != "main"`, set weather to clear for this battle.
- **Banner UI in battle HUD:**
  - Small panel at the top-center of the BattleScene viewport, above the enemy intent banner. Style: semi-transparent dark background with centered label showing weather name + modifier description (e.g. "RAIN: Ghosts gain +1 HP").
  - Viewport-relative sizing per **CLAUDE.md UI Sizing** section: width `18% vw`, height `4% vh`, font size `2% vh`.
  - Spawn at battle start if weather is active; fade in/out with a 0.3s tween.
  - **Mobile visibility:** Button-sized (no interaction needed; it's informational). Tap the banner to inspect weather details? (v2 feature; skip for v1).
  - **Implementation:** Add a new script `scenes/battle/WeatherBanner.gd` (extends Control or Panel); instantiate in `BattleScene._ready()` as a child of the root Control. Position fixed via `anchors_preset = PRESET_CENTER_TOP` + custom margin offset. Hide by default; show on `weather_changed` signal.
- **Modifier text (hardcoded for v1; no external config):**
  - `static func _MODIFIER_TEXTS() -> Dictionary:` mapping weather_id → human-readable string (e.g. `"rain": "Ghosts gain +1 HP"`, `"sandstorm": "All minions -1 ATK first turn"`, etc.). Called in WeatherBanner to display.
  - Keep in sync with actual modifier logic in battle code (if text says +1, verify the code applies +1).
- **Headless tests** (`tests/unit/test_weather_battle.gd`):
  - Create a GameState, set WeatherManager.current_weather to "rain", play a Ghost card, verify `ghost.max_health == (original + 1)`.
  - Test sandstorm: start turn 1 with sandstorm active, verify all minions have `status_effects["attack_debuff"]`.
  - Test ash: init battle with ash_fall, verify enemy hero has `status_effects["poison"] == 2`.
  - Test snow: play first card, verify cost is reduced by 1; play second card, verify cost is normal.
  - Test non-infinite map: set `SaveManager.current_map = "dungeon"`, start battle, verify `WeatherManager.current_weather == ""` (no weather applied).
  - Test banner spawn: verify WeatherBanner control is instantiated and positioned correctly.

## Plan

1. Create `scenes/battle/WeatherBanner.gd` — a Control that shows weather name + modifier text; shown at battle start if weather is active; sized relative to viewport
2. Update `BattleScene.gd`:
   - Determine `_battle_weather` at init (only non-empty when `SaveManager.current_map == "main"`)
   - Instantiate WeatherBanner in `_ready()` if weather is active
   - Apply ash_fall: enemy hero +2 poison at battle init
   - Apply rain/heavy_rain: ghost cards get +1/+2 health when summoned (in `_finish_hand_drag` and AI path)
   - Apply sandstorm: all summoned minions take -1 attack during turn 1 and 2
   - Apply snow/blizzard: first card each turn costs 1 less mana via `_snow_discount_used` array
3. Create `tests/unit/test_weather_battle.gd`
4. Add to `tests/runner.gd`

## Changes Made

- `scenes/battle/WeatherBanner.gd` (new): `Control` that builds a viewport-relative panel+label showing weather name and modifier description; `setup(weather_id)` hides for empty/unknown weather; static `modifier_text()` for headless tests
- `scenes/battle/BattleScene.gd`: Added `WeatherBanner` preload, `_battle_weather` and `_snow_discount_used` fields; `_apply_weather_battle_init()` applies ash_fall/volcanic poison and resets snow discount; `_apply_weather_to_summoned()` applies rain ghost health bonus and sandstorm attack debuff on summon; `_do_play_card()` wraps `play_card()` with snow first-card cost discount; `_on_turn_ended()` resets snow discount and applies blizzard freeze on turns 1–2; WeatherBanner instantiated in `_ready()` when weather is active
- `tests/unit/test_weather_battle.gd` (new): Tests for `WeatherBanner.modifier_text()`, rain/heavy-rain ghost health bonus, sandstorm attack floor, ash_fall hero poison, snow cost discount, blizzard freeze application, and map-guard logic
- `tests/runner.gd`: Added `test_weather_battle.gd` suite

## Documentation Updates

- No new agent docs file required; the weather system is self-contained and documented in task files.
