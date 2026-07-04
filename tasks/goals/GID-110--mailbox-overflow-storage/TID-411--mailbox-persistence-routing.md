# TID-411: Mailbox Persistence & Reward Routing in SaveManager

**Goal:** GID-110
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

`SaveManager.add_card_instance()` (`autoloads/SaveManager.gd:1087`) returns `""` and silently drops the card whenever `is_bag_full()` is true. This is the root of the "battle reward vanished" problem. This task adds a persisted overflow queue (`mailbox_cards`) and a new routing entrypoint (`grant_card_reward`) that automatic-reward call sites should use instead, so a full bag no longer means a lost card. TID-412/413 (world entity + UI) depend on the API this task defines — get the shape right, since both later tasks call into it directly.

## Research Notes

**Current `add_card_instance`** (`autoloads/SaveManager.gd:1084-1104`):
```gdscript
func add_card_instance(template_id: String, rarity: String, attack: int = -1, health: int = -1, cost: int = -1) -> String:
	if is_bag_full():
		GameBus.bag_full.emit()
		return ""
	var tmpl: Dictionary = CardRegistry.get_template(template_id)
	var atk: int = attack if attack >= 0 else int(tmpl.get("attack", 0))
	var hp: int  = health if health >= 0 else int(tmpl.get("health", 0))
	var c: int   = cost   if cost   >= 0 else int(tmpl.get("cost", 1))
	var uid: String = _gen_uid(template_id)
	var inst_dict: Dictionary = _CardInstanceUtil.make(uid, template_id, rarity, atk, hp, c)
	owned_cards.append(inst_dict)
	_uid_index[uid] = inst_dict
	if rarity != "common":
		GameBus.tutorial_popup_requested.emit("card_rarity")
	_dirty = true
	return uid
```
Do not change this function's behavior — `ShopScene`, `InventoryScene` crafting, and `SaveManager.combine_cards` (`autoloads/SaveManager.gd:1177`) call it directly and should keep blocking on a full bag (combine nets −2 slots per call so its full-bag path is already effectively unreachable — leave it alone).

**New function to add**, same call signature as `add_card_instance` so callers are a mechanical rename:
```gdscript
func grant_card_reward(template_id: String, rarity: String, attack: int = -1, health: int = -1, cost: int = -1) -> String:
	# Build the instance dict the same way add_card_instance does (reuse _CardInstanceUtil.make + _gen_uid).
	# If is_bag_full(): append to mailbox_cards instead of owned_cards/_uid_index, emit a new
	#   GameBus signal (e.g. card_routed_to_mailbox(template_id: String)) so callers/UI can toast,
	#   and still return the generated uid (the card exists, just not in the bag yet).
	# Else: identical to add_card_instance's success path.
```
`_uid_index` should NOT include mailbox cards (it's used for deck/loadout lookups against `owned_cards`) — keep mailbox cards out of it until claimed.

**New state + persistence** (mirror how `owned_cards` is wired):
- Field: `var mailbox_cards: Array[Dictionary] = []` near `owned_cards` at `autoloads/SaveManager.gd:31`.
- Save: add `"mailbox_cards": mailbox_cards.duplicate(true)` alongside `owned_cards` at `autoloads/SaveManager.gd:501` (and the other to-dict spot at line ~910 if the codebase has two write paths — check both; `owned_cards` appears in both places in current code).
- Load: `mailbox_cards.assign(data.get("mailbox_cards", []))` alongside the `owned_cards.assign(...)` at `autoloads/SaveManager.gd:777`.
- Migration: bump `CURRENT_SAVE_VERSION` (`autoloads/SaveManager.gd:514`, currently `40`) to `41`, and add `[41, {"mailbox_cards": []}]` to the migration table (`autoloads/SaveManager.gd:596-631`) — follow the exact `[29, {"bag_size": IsoConst.BAG_SIZE_DEFAULT}]` pattern already in that table.
- `new_game()` (`autoloads/SaveManager.gd:446` area) should reset `mailbox_cards.clear()` alongside `owned_cards.clear()`.

**Claim API:**
```gdscript
func get_mailbox_instances() -> Array[Dictionary]:
	return mailbox_cards

func claim_mailbox_card(uid: String) -> bool:
	# false if uid not found in mailbox_cards, or if is_bag_full() is true.
	# Otherwise: remove from mailbox_cards, append to owned_cards, add to _uid_index, mark _dirty, return true.

func claim_all_mailbox_cards() -> int:
	# Repeatedly claim_mailbox_card() for entries until the bag is full or mailbox_cards is empty.
	# Returns how many were claimed.
```
Sell/Scrap from the mailbox (needed by TID-413) can reuse the *existing* `sell_card_instance`/`scrap_card_instance` (`autoloads/SaveManager.gd:1134-1156`) as long as they're taught to look in `mailbox_cards` too, OR (simpler, recommended) add `sell_mailbox_card(uid)` / `scrap_mailbox_card(uid)` thin wrappers that operate on `mailbox_cards` directly (same gold/essence award via `IsoConst.RARITY_CONFIG`, just removing from `mailbox_cards` instead of `owned_cards`/`player_deck`/`loadouts`). Prefer the wrapper approach — it avoids threading an "which array" branch through the existing sell/scrap functions that are also used by hot deck-builder code paths.

**Call sites to migrate from `add_card_instance` to `grant_card_reward`** (verified 2026-07-04; re-check line numbers, this file/others may have shifted):
- `scenes/battle/BattleScene.gd:3351` (`_apply_coop_pve_rewards`)
- `scenes/world/WorldScene.gd:3465` (`_discover_landmark`)
- `scenes/ui/PackOpenScene.gd:185`
- `scenes/world/entities/DigSpot.gd:59`
- `scenes/world/entities/BurialMound.gd:69`
- `scenes/world/entities/WorldItem.gd:285`
- `autoloads/SaveManager.gd:1050` (`add_cards_to_deck`), `:1059` (`grant_achievement_card`), `:1734` (`_check_bestiary_complete`)
- `autoloads/SceneManager.gd:808, 872, 968, 975, 1031, 1040, 1058, 1074, 1396` (story/quest/duel rewards — read each call site's surrounding context before renaming; a couple may be battle-signature-card grants worth double-checking are genuinely "automatic")

**Explicitly do NOT migrate:** `scenes/ui/ShopScene.gd:371`, `scenes/ui/InventoryScene.gd:899` (craft), `autoloads/SaveManager.gd:1177` (`combine_cards`), and the `new_game()`/`adopt_session_character()`/starter-deck seeding call sites at `autoloads/SaveManager.gd:336, 339, 450` (deterministic startup, never realistically blocked).

**GameBus signal** — add near `signal bag_full` (`autoloads/GameBus.gd`, search for it): `signal card_routed_to_mailbox(template_id: String)`.

**Tests** — add `tests/unit/test_mailbox.gd` (or extend `tests/unit/test_bag_slots.gd`) following the pattern already established this session in `tests/unit/test_bag_slots.gd`: instantiate `SaveManagerScript.new()` directly (do not rely on the `SceneManager` autoload singleton in headless tests — it's not reliably `_ready()` in the test harness; see `tests/unit/test_garden_plot.gd:1-20` for why). Cover: reward routes to mailbox when bag is full, mailbox card can be claimed when space frees up, claim fails when bag is still full, `claim_all_mailbox_cards` stops at capacity, sell/scrap-from-mailbox awards currency and removes the entry, and a save/load round-trip preserves `mailbox_cards`.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
