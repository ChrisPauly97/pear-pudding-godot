# TID-217: UI: rank chevrons + title on card face, rename dialog in Inventory

**Goal:** GID-060
**Type:** agent
**Status:** done
**Depends On:** TID-216

## Lock

**Session:** none

## Context

Makes veterancy visible and personal: rank chevrons and the earned title (e.g. "Ghost the Relentless") on card rows in the Inventory and on the card face in battle, plus a rename dialog so the player can name their veterans. This is the payoff of GID-060 — the deck reads as a roster of individuals with history.

## Research Notes

**Inventory per-card UI (`/home/user/pear-pudding-godot/scenes/ui/InventoryScene.gd`):**
- Collection rows: `_make_collection_row(inst: Dictionary) -> VBoxContainer` (line 329). Reads `uid`, `template_id`, `rarity` from the instance dict; top row is colour swatch + name + rarity badge + Add button; second row shows stats via `_stat_range_text(rolled, base, rarity)` (line 316); an action row holds Sell/Scrap (with `_show_confirm` flow for epic/legendary, line 587) and Combine. **Rename button + rank chevrons go here**, following the existing `btn.pressed.connect(_do_x.bind(uid))` pattern (e.g. line 367 `add_btn.pressed.connect(_on_add.bind(uid))`).
- Deck rows: `_make_deck_row(uid, inst, index)` (line 454) — mirror the chevron/title display there.
- Badge/colour helpers to imitate: `_rarity_color(rarity)` (line 300), `_rarity_badge(rarity)` (line 308) — a `_rank_chevrons(rank) -> String` (e.g. "^", "^^", "^^^" or "▲" repeats) plus colour fits this pattern.
- Refresh cycle: `_refresh()` (246) → `_refresh_cards()` (251) rebuilds rows from `SceneManager.save_manager.get_owned_instances()`; sorting at lines 268–275 uses `IsoConst.RARITY_ORDER`. After a rename, call `_refresh()`.
- Rename dialog: build with plain Controls (project style — no AcceptDialog usage found in InventoryScene; inline confirm rows are the precedent, `_show_confirm` line 587). Needs a `LineEdit` + Save/Cancel. Persist via a TID-215 SaveManager API (e.g. `set_card_custom_name(uid, name)`); remember `_dirty = true`. Input validation (length cap, empty string = revert to title) decided in Plan.
- **Mobile parity (CLAUDE.md):** rename must be a visible tap target (Button on the row), not a keyboard shortcut. UI sizing must be viewport-relative (`_vh`-style fractions; InventoryScene already follows this).

**Battle card face (`/home/user/pear-pudding-godot/scenes/battle/BattleScene.gd`):**
- `_build_card_vbox(card: CardInstance, with_status_row: bool = false)` (line 830) creates `NameLabel` with `name_lbl.text = card.name` (line 834), font `int(_vh * 0.018)`.
- `_update_card_view(panel, card, zone_id)` (line 776) refreshes it: `name_lbl.text = card.name` (line 785).
- Simplest approach: have TID-216's instance-aware deck build set `CardInstance.name` to the resolved display name (custom_name or "Base the Title") at build time — then **zero changes** to the name plumbing in BattleScene; chevron display on the battle card face (small "^^^" prefix/suffix in NameLabel, or a tiny Label like the KeywordRow pattern at `_update_keyword_badges`) decided in Plan. Note `CardInstance.name` already round-trips `to_dict()`/`from_dict()` (CardInstance.gd lines 119/146), so resume keeps the title.
- `CardInspectOverlay.gd` (`scenes/battle/CardInspectOverlay.gd`) shows card name/details — title shows automatically if `card.name` carries it; rank line addition optional (Plan).

**Data dependencies (from TID-215/216):**
- Instance fields: `kills`, `battles_survived`, `custom_name` on each `owned_cards` dict; rank/title math in the TID-215 helper (`game_logic/VeterancyUtil.gd` expected) with thresholds in `IsoConst` (alongside `RARITY_CONFIG` line 48 / `RARITY_ORDER` line 54 of `/home/user/pear-pudding-godot/autoloads/IsoConst.gd`).
- `SaveManager.get_instance_by_uid(uid)` (SaveManager.gd line 606) returns the live dict for reading counters in rows.
- Preload the helper (`const VeterancyUtil = preload("res://game_logic/VeterancyUtil.gd")`) — do not rely on class_name (CLAUDE.md).

**Where renamed/titled names must NOT leak:** shop, crafting (`_make_craft_row` line 531), and reward overlays deal in templates, not instances — they keep template names. Battle **enemy** cards have no collection instance (`collection_uid == ""`) and keep template names.

**Tests:** UI itself is untested in `tests/unit/` (no scene tests exist); cover the display-name resolution and chevron-string logic in the VeterancyUtil tests instead. Runner: `godot --headless --path . -s tests/runner.gd`.

**Docs to update after Build:** `docs/agent/inventory-and-deck.md` (rows, rename), `docs/agent/battle-system.md` (card face name source), per the docs/agent table in CLAUDE.md.

## Plan

1. **`VeterancyUtil.gd`** — Add `rank_chevrons(rank) -> String` ("", "▲", "▲▲", "▲▲▲").
2. **`SaveManager.gd`** — Add `set_card_custom_name(uid, name)`: strips whitespace, caps at 24 chars, marks dirty.
3. **`PlayerState.gd`** (`build_deck_from_instances`) — Set `ci.name = VeterancyUtil.display_name(inst, tmpl_name)` so titled/custom names appear in battle without touching BattleScene.
4. **`InventoryScene.gd`** — Preload VeterancyUtil; in `_make_collection_row_instance` show display_name, rank chevrons, and add inline rename panel (LineEdit + Save/Cancel); in `_make_deck_row_instance` show display_name and rank chevrons.
5. **Tests** — Add `rank_chevrons` tests to `test_veterancy_util.gd`; add `display_name`-in-battle and `set_card_custom_name` tests to `test_veterancy_attribution.gd`.

## Changes Made

- **`game_logic/VeterancyUtil.gd`** — Added `rank_chevrons(rank: int) -> String`.
- **`autoloads/SaveManager.gd`** — Added `set_card_custom_name(uid, name)`.
- **`game_logic/battle/PlayerState.gd`** — `build_deck_from_instances` now sets `ci.name` to the resolved display name.
- **`scenes/ui/InventoryScene.gd`** — Preloaded `VeterancyUtil`; `_make_collection_row_instance` shows display name, golden rank chevrons, and inline rename panel (✏ Rename button + LineEdit + Save + ✕); `_make_deck_row_instance` shows display name and chevrons.
- **`tests/unit/test_veterancy_util.gd`** — 5 new `rank_chevrons` tests.
- **`tests/unit/test_veterancy_attribution.gd`** — 8 new tests: display_name-in-battle, `set_card_custom_name` (stores, trims, truncates, clears, noop, dirty).

## Documentation Updates

- **`docs/agent/inventory-and-deck.md`** — Extended Veterancy System section with `rank_chevrons`, `set_card_custom_name`, Inventory UI description, and battle card name note.
