## Shared party content: night hunts, need/greed loot rolls, the co-op Endless
## Spire run and its drafts, the town siege gauntlet, the PvE leaderboards and
## the shared party bounty board.
##
## A child node of WorldScene, registered with NetSync as an RPC handler target
## so the `_on_*` entry points below are reached exactly as they were when they
## lived in WorldScene itself. Everything world-side is reached via `_world`.
extends Node

## The WorldScene that owns this module. Everything the module needs from
## the world itself — the player node, the HUD, the entity tables — is
## reached through it. Sibling modules are reached as _world.<accessor>.
var _world: Node = null

const _CardDropUtil      = preload("res://game_logic/CardDropUtil.gd")
const _CardInstanceUtil  = preload("res://game_logic/CardInstanceUtil.gd")
const _CardRegistry      = preload("res://autoloads/CardRegistry.gd")
const _CoopNightHunts    = preload("res://game_logic/CoopNightHunts.gd")
const _CoopSiege         = preload("res://game_logic/CoopSiege.gd")
const _EnemyScene        = preload("res://scenes/world/entities/EnemyNPC.tscn")
const _LootRoll          = preload("res://game_logic/net/LootRoll.gd")
const _RunSummaryScene   = preload("res://scenes/ui/RunSummaryScene.tscn")
const _SessionState      = preload("res://game_logic/net/SessionState.gd")
const _SiegeDefs         = preload("res://game_logic/SiegeDefs.gd")
const _SpireDraft        = preload("res://game_logic/spire/SpireDraft.gd")
const _SpireDraftScene   = preload("res://scenes/ui/SpireDraftScene.tscn")
const _SpireDraftSync    = preload("res://game_logic/net/SpireDraftSync.gd")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")
const _WeaponData        = preload("res://data/WeaponData.gd")
const _WeaponRegistry    = preload("res://autoloads/WeaponRegistry.gd")
const _WorldObjectSync   = preload("res://game_logic/net/WorldObjectSync.gd")

var _coop_night_hunt_active: bool = false
var _coop_night_hunt_day: int = -1
var _coop_night_hunt_nodes: Dictionary = {}  # id -> Node3D
var _coop_siege_id: int = 0
var _party_bounty_panel: VBoxContainer = null   # HUD panel showing shared progress
var _pending_coop_spire_draft_floor: int = -1
var _pending_coop_spire_run_ended_payload: Dictionary = {}

func _coop_update_night_hunts(_delta: float) -> void:
	if not _world._coop_active or _world._is_infinite or not _CoopNightHunts.supports_map(_world.map_name):
		return
	var is_night: bool = _world._dnc != null and _world._dnc.is_night_now()
	var days: int = _world.coop_session._coop_current_days_elapsed()
	if is_night:
		if not _coop_night_hunt_active or _coop_night_hunt_day != days:
			_coop_spawn_night_hunt(days)
	elif _coop_night_hunt_active:
		_coop_despawn_night_hunt()

## Spawn tonight's deterministic spectral enemies. Every peer computes the exact
## same plan independently (see CoopNightHunts.generate_hunt) — nothing is
## broadcast for the spawn itself, only the later engage/defeat events.

func _coop_spawn_night_hunt(days: int) -> void:
	if _coop_night_hunt_active:
		_coop_despawn_night_hunt()
	_coop_night_hunt_active = true
	_coop_night_hunt_day = days
	var gate: Vector3 = _SiegeDefs.TOWN_GATES.get(_world.map_name, Vector3.ZERO)
	var plan: Array[Dictionary] = _CoopNightHunts.generate_hunt(_world.map_name, days)
	var spawned_any: bool = false
	for entry: Dictionary in plan:
		var eid: String = str(entry.get("id", ""))
		if eid == "" or _world._coop_removed_enemies.has(eid):
			continue  # already engaged/defeated earlier tonight (e.g. re-entering the map)
		var off: Vector2 = entry.get("offset", Vector2.ZERO)
		var wx: float = gate.x + off.x
		var wz: float = gate.z + off.y
		var wy: float = _world.get_terrain_height(wx, wz) + 0.5
		var node: Node3D = _EnemyScene.instantiate() as Node3D
		if node == null:
			continue
		node.set_meta("is_nocturnal", true)
		node.call("init_from_data", {
			"id": eid,
			"enemy_type": str(entry.get("enemy_type", "spectre_wisp")),
			"tracking": true,
		})
		node.position = Vector3(wx, wy, wz)
		node.modulate = Color(0.7, 0.85, 1.0, 0.85)
		_world._entity_root.add_child(node)
		_world._enemy_nodes[eid] = node
		_coop_night_hunt_nodes[eid] = node
		spawned_any = true
	if spawned_any:
		GameBus.hud_message_requested.emit("The party hears spectral howls on the wind…")

## Dawn (or map exit): clear tonight's surviving hunt nodes and reset the tally.

func _coop_despawn_night_hunt() -> void:
	for eid: String in _coop_night_hunt_nodes.keys():
		var n: Node3D = _world._valid_node3d(_coop_night_hunt_nodes[eid])
		if is_instance_valid(n):
			n.queue_free()
		_world._enemy_nodes.erase(eid)
	_coop_night_hunt_nodes.clear()
	_coop_night_hunt_active = false
	_world._coop_night_hunt_kills = 0

# ── Party loot rolls (GID-102 / TID-381) ──────────────────────────────────────
# Opt-in need/greed alternative to the GID-096 first-opener-takes chest rule.
# Guarded by _coop_active + the session's loot_mode; completely inert (and this whole
# section unreached) when the mode is left at the default "first_opener".

## True when a co-op session has need/greed loot mode enabled. Reads the live
## SessionState on the host; a client mirrors the flag locally when it receives
## a roll-start broadcast (there's nothing to read before the first roll on a client,
## which is fine — a client never decides to start a roll, only the authority does).

func _coop_loot_mode_is_need_greed() -> bool:
	if not SessionStore.is_open():
		return false
	return SessionStore.get_loot_mode() == _SessionState.LOOT_MODE_NEED_GREED

## Opener (host or client) triggers a roll for a just-opened chest's drop. The chest's
## position/card ids/tier are re-derived from _active_chest_data[cid] rather than sent
## over the wire — chests are deterministically spawned from the same map data on every
## peer (the GID-096 invariant), so the authority already knows the exact same values the
## opener does without needing a payload for the item shape.

func _start_loot_roll(cid: String, chest_tier: int) -> void:
	if _world.coop_session._coop_world_authority():
		_authority_open_loot_roll(cid, chest_tier)
	elif _world._net_sync != null:
		_world._net_sync.rpc_id(1, "submit_loot_roll_request", cid, chest_tier)

## Client → authority: "a chest I opened should start a need/greed roll." The chest-open
## itself is already synced via the existing EV_CHEST_OPENED path; this only carries the
## tier (the id is enough for the host to re-derive position/card ids locally).

func _on_loot_roll_request_submitted(_sender: int, cid: String, chest_tier: int) -> void:
	if not _world.coop_session._coop_world_authority():
		return
	_authority_open_loot_roll(cid, chest_tier)


## Authority: build the roll session for a chest's resolved drop and broadcast the prompt
## to every connected session member (present = connected to the session; a same-map/
## proximity filter was judged out of scope for v1 — documented in the task).

func _authority_open_loot_roll(cid: String, chest_tier: int) -> void:
	if _loot_roll_by_chest(cid) != "":
		return  # a roll for this chest is already in flight — never double-grant
	var chest_data: Dictionary = _world._active_chest_data.get(cid, {}) as Dictionary
	var chest_card_ids: Array[String] = []
	chest_card_ids.assign(chest_data.get("card_ids", []))
	var roll_id: String = "roll_%s_%d" % [cid, Time.get_ticks_msec()]
	var participants: Array = []
	participants.append(MpProfile.get_token())
	for token in _world._session_token_by_peer.values():
		if not participants.has(token):
			participants.append(str(token))
	_world._loot_rolls_active[roll_id] = {
		"chest_id": cid,
		"card_ids": chest_card_ids,
		"tier": chest_tier,
		"participants": participants,
		"choices": {},
		"timer": 0.0,
	}
	var item: Dictionary = {"card_ids": chest_card_ids, "tier": chest_tier}
	var payload: Dictionary = _LootRoll.encode_start(roll_id, item, participants)
	if _world._net_sync != null:
		_world._net_sync.rpc("recv_loot_roll_start", payload)
	_on_loot_roll_start_received(payload)  # authority also sees its own prompt


## Find the in-flight roll_id for a chest id, or "" if none (authority only; empty dict
## on clients so this is always "").

func _loot_roll_by_chest(cid: String) -> String:
	for rid in _world._loot_rolls_active.keys():
		if str((_world._loot_rolls_active[rid] as Dictionary).get("chest_id", "")) == cid:
			return str(rid)
	return ""


## Any peer (including the authority itself): show the Need/Greed/Pass prompt.

func _on_loot_roll_start_received(payload: Dictionary) -> void:
	var start: Dictionary = _LootRoll.decode_start(payload)
	if str(start.get("roll_id", "")) == "":
		return
	_world._pending_loot_roll = start
	_show_loot_roll_panel(start)


## Local player picked Need/Greed/Pass. Sends the choice to the authority (or applies
## it directly if this peer IS the authority).

func _submit_loot_roll_choice(roll_id: String, choice: String) -> void:
	if _world._loot_roll_panel != null and is_instance_valid(_world._loot_roll_panel):
		_world._loot_roll_panel.queue_free()
		_world._loot_roll_panel = null
	_world._pending_loot_roll = {}
	if NetworkManager.is_host():
		_on_loot_roll_choice_submitted(multiplayer.get_unique_id(), roll_id, choice)
	elif _world._net_sync != null:
		var payload: Array = _LootRoll.encode_choice(roll_id, choice)
		_world._net_sync.rpc_id(1, "submit_loot_roll_choice", payload[0], payload[1])


## Authority: record a participant's choice. Resolves early once every expected
## participant has responded (rather than always waiting out the full timeout).

func _on_loot_roll_choice_submitted(sender: int, roll_id: String, choice: String) -> void:
	if not _world.coop_session._coop_world_authority():
		return
	if not _world._loot_rolls_active.has(roll_id):
		return
	var roll: Dictionary = _world._loot_rolls_active[roll_id]
	var token: String = str(_world._session_token_by_peer.get(sender,
		MpProfile.get_token() if sender == multiplayer.get_unique_id() else ""))
	if token == "":
		return
	var choices: Dictionary = roll.get("choices", {})
	choices[token] = _LootRoll.normalize_choice(choice)
	roll["choices"] = choices
	_world._loot_rolls_active[roll_id] = roll
	var participants: Array = roll.get("participants", [])
	if choices.size() >= participants.size():
		_settle_loot_roll(roll_id)


## Ticked from _process while any roll is in flight (authority only). Missing
## responses auto-pass once the timeout elapses.

func _tick_loot_rolls(delta: float) -> void:
	if not _world.coop_session._coop_world_authority() or _world._loot_rolls_active.is_empty():
		return
	for roll_id in _world._loot_rolls_active.keys().duplicate():
		var roll: Dictionary = _world._loot_rolls_active[roll_id]
		var t: float = float(roll.get("timer", 0.0)) + delta
		roll["timer"] = t
		_world._loot_rolls_active[roll_id] = roll
		if t >= _world._LOOT_ROLL_TIMEOUT:
			_settle_loot_roll(str(roll_id))


## Authority: resolve the winner (missing participants auto-pass), grant the loot to
## the winner's session character, persist, and broadcast the result. No item is ever
## granted twice — the roll is removed from _loot_rolls_active before any grant happens.

func _settle_loot_roll(roll_id: String) -> void:
	if not _world._loot_rolls_active.has(roll_id):
		return
	var roll: Dictionary = _world._loot_rolls_active[roll_id]
	_world._loot_rolls_active.erase(roll_id)
	var participants: Array = roll.get("participants", [])
	var choices: Dictionary = (roll.get("choices", {}) as Dictionary).duplicate()
	for token in participants:
		if not choices.has(str(token)):
			choices[str(token)] = _LootRoll.CHOICE_PASS
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var outcome: Dictionary = _LootRoll.resolve_winner(choices, rng)
	var winner_token: String = str(outcome.get("winner_token", ""))
	var rolls: Dictionary = outcome.get("rolls", {})
	if winner_token != "":
		var chest_card_ids: Array[String] = []
		chest_card_ids.assign(roll.get("card_ids", []))
		_grant_chest_loot_to_token(winner_token, chest_card_ids, int(roll.get("tier", 1)))
	var payload: Dictionary = _LootRoll.encode_result(roll_id, winner_token, rolls)
	if _world._net_sync != null:
		_world._net_sync.rpc("recv_loot_roll_result", payload)
	_on_loot_roll_result_received(payload)


## Authority: grant a resolved chest's cards + a flat coin reward, and (BID-033) roll a
## chance at one equipment piece, directly into the winner's GID-095 session character
## record (they may not be the local player, so this reuses the direct-SessionStore-write
## pattern from _transfer_card_in_session / party-bounty rewards rather than the physical
## WorldItem pickup path, which only ever grants to the local opener).

func _grant_chest_loot_to_token(token: String, card_ids: Array[String], tier: int) -> void:
	var st = SessionStore.get_state()
	if st == null or token == "":
		return
	var rec: Dictionary = st.get_member(token)
	if rec.is_empty():
		return
	var owned: Array = rec.get("owned_cards", []) as Array
	var counter: int = owned.size()
	for cid_tpl: String in card_ids:
		var rarity: String = _CardDropUtil.effective_rarity(cid_tpl, _CardDropUtil.roll_rarity(tier))
		var stats: Dictionary = _CardDropUtil.roll_stats(cid_tpl, rarity)
		var uid: String = "%s_%s_roll_%d" % [cid_tpl, token, counter]
		counter += 1
		owned.append(_CardInstanceUtil.make(
			uid, cid_tpl, rarity,
			int(stats.get("attack", 0)), int(stats.get("health", 0)), int(stats.get("cost", 1))))
	rec["owned_cards"] = owned
	rec["coins"] = int(rec.get("coins", 0)) + randi_range(5, 20) * 3
	_roll_equipment_into_loot_grant(rec, tier)
	st.update_member(token, rec)
	SessionStore.mark_dirty()


## Authority: rolls LootRoll.roll_equipment_drop against the winner's OWN session-scoped
## ownership (rec's owned_weapons/owned_armor — BID-033) and, on a hit, appends the
## picked id into whichever of those two arrays matches its WeaponData.slot. Mutates
## `rec` in place; a no-op (nothing appended) on a chance-miss or an already-fully-owned
## pool, exactly mirroring WorldScene._maybe_drop_equipment_from_chest's own silent-miss
## behavior for the single-player/first-opener path.

func _roll_equipment_into_loot_grant(rec: Dictionary, tier: int) -> void:
	var owned_w: Array = rec.get("owned_weapons", []) as Array
	var owned_a: Array = rec.get("owned_armor", []) as Array
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var picked: String = _LootRoll.roll_equipment_drop(
		tier, _WeaponRegistry.get_by_slot("weapon"), _WeaponRegistry.get_by_slot("armor"),
		owned_w, owned_a, rng)
	if picked == "":
		return
	var weapon: _WeaponData = _WeaponRegistry.get_weapon(picked)
	if weapon == null:
		return
	if weapon.slot == "weapon":
		owned_w.append(picked)
		rec["owned_weapons"] = owned_w
	else:
		owned_a.append(picked)
		rec["owned_armor"] = owned_a


## Any peer: announce the winner (toast) and close the prompt if one was open.

func _on_loot_roll_result_received(payload: Dictionary) -> void:
	if _world._loot_roll_panel != null and is_instance_valid(_world._loot_roll_panel):
		_world._loot_roll_panel.queue_free()
		_world._loot_roll_panel = null
	_world._pending_loot_roll = {}
	var result: Dictionary = _LootRoll.decode_result(payload)
	var winner_token: String = str(result.get("winner_token", ""))
	if winner_token == "":
		GameBus.hud_message_requested.emit("Loot roll: everyone passed — nothing claimed.")
		return
	var winner_name: String = _world._display_name_for_token(winner_token)
	GameBus.hud_message_requested.emit("%s won the loot roll!" % winner_name)


## Public accessor for SceneManager.session_token_for_peer (GID-104 / TID-387),
## called from BattleScene while this scene is detached from the tree during a PvP
## battle/spectate session (spectator-wager escrow needs to resolve a spectator's
## peer_id to their GID-095 session token). Returns "" for an unresolved peer (e.g.
## the identity handshake hasn't completed) — callers must treat that as ineligible.

func _show_loot_roll_panel(start: Dictionary) -> void:
	if _world._loot_roll_panel != null and is_instance_valid(_world._loot_roll_panel):
		_world._loot_roll_panel.queue_free()
		_world._loot_roll_panel = null
	var roll_id: String = str(start.get("roll_id", ""))
	var item: Dictionary = start.get("item", {})
	var card_ids: Array = item.get("card_ids", [])
	var tier: int = int(item.get("tier", 1))
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var vh: float = vp.y
	var prompt: Dictionary = _world._build_prompt(183, 0.02)
	var layer: CanvasLayer = prompt["layer"]
	_world._loot_roll_panel = layer
	var vbox: VBoxContainer = prompt["vbox"]
	var lbl := _UiUtil.make_label("Loot roll! Tier %d chest — %d card(s).\nNeed, Greed, or Pass?" % [tier, card_ids.size()], int(vh * 0.026), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vbox)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var row := _UiUtil.make_hbox(int(vh * 0.025), vbox)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var need_btn := _UiUtil.make_button("Need", Vector2(vh * 0.16, vh * 0.06), int(vh * 0.024), _submit_loot_roll_choice.bind(roll_id, _LootRoll.CHOICE_NEED), row)
	var greed_btn := _UiUtil.make_button("Greed", Vector2(vh * 0.16, vh * 0.06), int(vh * 0.024), _submit_loot_roll_choice.bind(roll_id, _LootRoll.CHOICE_GREED), row)
	var pass_btn := _UiUtil.make_button("Pass", Vector2(vh * 0.16, vh * 0.06), int(vh * 0.024), _submit_loot_roll_choice.bind(roll_id, _LootRoll.CHOICE_PASS), row)

# ── Co-op story mode — shared story flags (GID-098 / TID-356) ────────────────

## Host: send current session story flags to a just-joined peer.

func _start_coop_spire() -> void:
	if not NetworkManager.is_host():
		return  # defensive: don't trust client-side button visibility alone
	if not _world._coop_active or _world._net_sync == null or _world._coop_map_transitioning:
		return
	var picker_order: Array[String] = []
	if not SceneManager.is_coop_spire_active():
		picker_order.append(MpProfile.get_token())
		for token in _world._session_token_by_peer.values():
			if not picker_order.has(str(token)):
				picker_order.append(str(token))
	var target_map: String = SceneManager.enter_spire_coop(picker_order)
	_world._coop_map_transitioning = true
	_world._net_sync.rpc("recv_map_transition", target_map, "")
	SceneManager.enter_coop_map_no_stack(target_map, "")


## Authority-only entry point (the TID-391 hook): opens one draft round for
## `floor`, seeding the RNG identically to single-player's SpireDraftScene.setup
## (run seed + floor) so the 3 options are deterministic and reproducible.

func _start_coop_spire_draft(floor_num: int) -> void:
	if not _world.coop_session._coop_world_authority():
		return
	if not _world._coop_spire_draft_active.is_empty():
		return  # a round is already in flight — never open a second one
	var run: Dictionary = SceneManager.get_coop_spire_run()
	if not bool(run.get("active", false)):
		return
	var picker_order: Array = run.get("picker_order", [])
	if picker_order.is_empty():
		return
	var picker_idx: int = int(run.get("picker_idx", 0))
	var active_picker_token: String = str(picker_order[picker_idx % picker_order.size()])
	var active_picker_name: String = _world._display_name_for_token(active_picker_token)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(run.get("seed", 0)) + floor_num
	var pool_templates: Dictionary = {}
	for id: String in _CardRegistry.get_all_ids():
		pool_templates[id] = _CardRegistry.get_template(id)
	var options: Array[String] = _SpireDraft.new().generate_picks(floor_num, rng, pool_templates)
	_world._coop_spire_draft_active = {
		"floor": floor_num,
		"options": options,
		"active_picker_token": active_picker_token,
		"active_picker_name": active_picker_name,
		"timer": 0.0,
	}
	var payload: Dictionary = _SpireDraftSync.encode_draft_start(
		floor_num, options, active_picker_token, active_picker_name)
	if _world._net_sync != null:
		_world._net_sync.rpc("recv_spire_draft_start", payload)
	_on_spire_draft_start_received(payload)  # authority also sees its own prompt


## Any peer (including the authority itself): show the draft overlay — interactive
## if it's this peer's turn, a disabled "waiting" banner otherwise. Reuses
## SpireDraftScene (setup_coop), not a new scene.

func _on_spire_draft_start_received(payload: Dictionary) -> void:
	var start: Dictionary = _SpireDraftSync.decode_draft_start(payload)
	var options: Array[String] = []
	options.assign(start.get("options", []))
	if options.is_empty():
		return
	if _world._coop_spire_draft_overlay != null and is_instance_valid(_world._coop_spire_draft_overlay):
		_world._coop_spire_draft_overlay.queue_free()
	_world._pending_coop_spire_draft = start
	var active_picker_token: String = str(start.get("active_picker_token", ""))
	var is_my_turn: bool = active_picker_token == MpProfile.get_token()
	var overlay := _SpireDraftScene.instantiate()
	get_tree().current_scene.add_child(overlay)
	overlay.setup_coop(
		int(start.get("floor", 1)), options, is_my_turn, str(start.get("active_picker_name", "Player")))
	if is_my_turn:
		overlay.picked.connect(_submit_coop_spire_draft_choice)
	_world._coop_spire_draft_overlay = overlay


## Local player (the active picker) chose a card. Resolves card_id -> card_idx from
## what was actually broadcast to THIS peer (never from _coop_spire_draft_active,
## which only exists on the authority), then sends the index to the authority, or
## applies it directly if this peer IS the authority.

func _submit_coop_spire_draft_choice(card_id: String) -> void:
	if _world._coop_spire_draft_overlay != null and is_instance_valid(_world._coop_spire_draft_overlay):
		_world._coop_spire_draft_overlay.queue_free()
	_world._coop_spire_draft_overlay = null
	var options: Array[String] = []
	options.assign(_world._pending_coop_spire_draft.get("options", []))
	_world._pending_coop_spire_draft = {}
	var card_idx: int = options.find(card_id)
	if card_idx < 0:
		return
	if NetworkManager.is_host():
		_on_spire_draft_choice_submitted(multiplayer.get_unique_id(), card_idx)
	elif _world._net_sync != null:
		_world._net_sync.rpc_id(1, "submit_spire_draft_choice", card_idx)


## Authority: record the active picker's choice (a sender mismatch is silently
## ignored — mirrors the loot-roll "unexpected sender" tolerance), resolve the
## pick, advance the rotation, and broadcast the result.

func _on_spire_draft_choice_submitted(sender: int, card_idx: int) -> void:
	if not _world.coop_session._coop_world_authority():
		return
	if _world._coop_spire_draft_active.is_empty():
		return
	var expected_token: String = str(_world._coop_spire_draft_active.get("active_picker_token", ""))
	var sender_token: String = str(_world._session_token_by_peer.get(sender,
		MpProfile.get_token() if sender == multiplayer.get_unique_id() else ""))
	if sender_token == "" or sender_token != expected_token:
		return
	_resolve_coop_spire_draft(card_idx)


## Ticked from _process while a draft round is in flight (authority only). An
## unresponsive active picker auto-picks the first option once the timeout elapses.

func _tick_coop_spire_draft(delta: float) -> void:
	if not _world.coop_session._coop_world_authority() or _world._coop_spire_draft_active.is_empty():
		return
	var t: float = float(_world._coop_spire_draft_active.get("timer", 0.0)) + delta
	_world._coop_spire_draft_active["timer"] = t
	if t >= _world._COOP_SPIRE_DRAFT_TIMEOUT:
		_resolve_coop_spire_draft(0)


## Authority: commit the picked card to the shared run deck, advance the picker
## rotation, and broadcast the resolved choice + next picker's turn. Then (TID-391)
## advances the run to the next floor and broadcasts the map transition there —
## co-op floor advancement is fully automatic, unlike solo Spire's authored exit
## door (see SceneManager.exit_map()'s co-op-spire no-op branch).

func _resolve_coop_spire_draft(card_idx: int) -> void:
	var options: Array[String] = []
	options.assign(_world._coop_spire_draft_active.get("options", []))
	_world._coop_spire_draft_active = {}
	if options.is_empty():
		return
	var idx: int = clampi(card_idx, 0, options.size() - 1)
	var card_id: String = options[idx]
	SceneManager.add_coop_drafted_card(card_id)
	SceneManager.advance_coop_spire_picker()
	var run: Dictionary = SceneManager.get_coop_spire_run()
	var picker_order: Array = run.get("picker_order", [])
	var next_token: String = ""
	var next_name: String = "Player"
	if not picker_order.is_empty():
		next_token = str(picker_order[int(run.get("picker_idx", 0)) % picker_order.size()])
		next_name = _world._display_name_for_token(next_token)
	var payload: Array = _SpireDraftSync.encode_draft_choice(card_id, next_token, next_name)
	if _world._net_sync != null:
		_world._net_sync.rpc("recv_spire_draft_choice", payload)
	_on_spire_draft_choice_received(payload)
	if not _world.coop_session._coop_world_authority():
		return
	SceneManager.advance_coop_spire_floor()
	var next_run: Dictionary = SceneManager.get_coop_spire_run()
	var next_floor: int = int(next_run.get("floor", 1))
	var next_seed: int = int(next_run.get("seed", 0))
	var target_map: String = "spire_floor_%d_%d" % [next_floor, next_seed]
	_world._coop_map_transitioning = true
	if _world._net_sync != null:
		_world._net_sync.rpc("recv_map_transition", target_map, "")
	SceneManager.enter_coop_map_no_stack(target_map, "")


## Any peer: close the draft overlay if open and show a toast naming the card +
## next picker.

func _on_spire_draft_choice_received(payload: Array) -> void:
	if _world._coop_spire_draft_overlay != null and is_instance_valid(_world._coop_spire_draft_overlay):
		_world._coop_spire_draft_overlay.queue_free()
	_world._coop_spire_draft_overlay = null
	_world._pending_coop_spire_draft = {}
	var result: Dictionary = _SpireDraftSync.decode_draft_choice(payload)
	var card_id: String = str(result.get("card_id", ""))
	if card_id == "":
		return
	var tmpl: Dictionary = _CardRegistry.get_template(card_id)
	var card_name: String = str(tmpl.get("name", card_id))
	var next_name: String = str(result.get("next_active_picker_name", "Player"))
	GameBus.hud_message_requested.emit("Drafted %s! Next up: %s" % [card_name, next_name])


## Local player engaged the co-op Spire floor boss (TID-391). A client relays the
## intent to the host; the host starts the joint battle directly. Mirrors
## _coop_engage_siege_boss exactly.

func _coop_engage_spire_boss(edata: Dictionary) -> void:
	if not NetworkManager.is_host():
		if _world._net_sync != null:
			_world._net_sync.rpc_id(1, "submit_spire_boss_engaged", edata)
		return
	_coop_start_spire_boss_battle(edata)


## Host: a client engaged the Spire boss — start the joint battle for everyone.

func _on_spire_boss_engaged_submitted(_sender: int, edata: Dictionary) -> void:
	if not NetworkManager.is_host():
		return
	_coop_start_spire_boss_battle(edata)


## Host-only: every ally fights with the same shared, collaboratively-drafted
## deck (PlayerState.build_deck shuffles independently per call, so allies still
## get different draw orders). Boss HP/tier scaling by party size happens inside
## BattleScene._build_coop_pve_state, exactly like siege — edata is passed through
## unscaled.

func _coop_start_spire_boss_battle(edata: Dictionary) -> void:
	if not NetworkManager.is_host() or _world._net_sync == null:
		return
	var boss_eid: String = str(edata.get("id", ""))
	if boss_eid != "":
		_world.coop_session._coop_remove_enemy_node(boss_eid)
		_world._net_sync.rpc("recv_world_event", _WorldObjectSync.encode_event(
			_WorldObjectSync.EV_ENEMY_REMOVED, boss_eid))
	var shared_deck: Array = SceneManager.get_coop_spire_run().get("shared_deck", [])
	var abs_peer_ids: Array[int] = [multiplayer.get_unique_id()]
	var clients: Array = multiplayer.get_peers()
	clients.sort()
	for pid in clients:
		abs_peer_ids.append(int(pid))
	var all_decks: Array = []
	for _pid in abs_peer_ids:
		all_decks.append(shared_deck.duplicate())
	for i in range(abs_peer_ids.size()):
		var pid: int = abs_peer_ids[i]
		if pid != multiplayer.get_unique_id():
			_world._net_sync.rpc_id(pid, "notify_coop_pve_start", i, all_decks, edata)
	SceneManager.enter_coop_pve_battle(0, all_decks, edata)


## Any peer: the joint Spire floor battle ended. No-op unless a co-op Spire run is
## actually active (coop_pve_battle_ended fires for any joint PvE battle — siege,
## Spire, future modes). This handler fires while WorldScene is still detached
## from the tree (the joint battle removed it, same as PvP) — the pure/host-only
## data-layer work (ending the run, submitting the leaderboard score) is safe to
## do immediately, but everything that touches the tree or sends an RPC is
## captured into a pending field and deferred to _enter_tree() via
## _flush_pending_coop_spire_post_battle, once reattachment makes that safe.

func _on_coop_spire_battle_ended(did_win: bool) -> void:
	if not _world.coop_session._in_coop_spire_floor():
		return
	if did_win:
		if _world.coop_session._coop_world_authority():
			var run: Dictionary = SceneManager.get_coop_spire_run()
			_pending_coop_spire_draft_floor = int(run.get("floor", 1))
	elif _world.coop_session._coop_world_authority():
		var stats: Dictionary = SceneManager.end_coop_spire_run()
		var floors_cleared: int = int(stats.get("floors_cleared", 0))
		var party_size: int = multiplayer.get_peers().size() + 1
		var roster: Array = [MpProfile.get_display_name()]
		for identity in _world._remote_identities.values():
			roster.append(str((identity as Dictionary).get("name", "Player")))
		_submit_pve_score("coop_spire", floors_cleared)  # host-only, pure SessionStore write
		_pending_coop_spire_run_ended_payload = {
			"floors_cleared": floors_cleared,
			"party_size": party_size,
			"roster": roster,
		}
	if is_inside_tree():
		_flush_pending_coop_spire_post_battle()


## Runs any deferred co-op-Spire post-battle work that needed the tree (opening
## the next floor's draft, or the run-ended summary + its RPC broadcast). Called
## from _enter_tree() once this WorldScene is confirmed reattached, and also
## inline if the peer already happens to be in the tree (defensive; in practice
## the joint-battle end always fires while detached, same as PvP).

func _flush_pending_coop_spire_post_battle() -> void:
	if _pending_coop_spire_draft_floor >= 0:
		var floor_num: int = _pending_coop_spire_draft_floor
		_pending_coop_spire_draft_floor = -1
		_start_coop_spire_draft(floor_num)
	if not _pending_coop_spire_run_ended_payload.is_empty():
		var payload: Dictionary = _pending_coop_spire_run_ended_payload
		_pending_coop_spire_run_ended_payload = {}
		if _world._net_sync != null:
			_world._net_sync.rpc("recv_coop_spire_run_ended", payload)
		_on_coop_spire_run_ended_received(payload)


## Any peer: show the co-op Spire run summary as a WorldScene overlay (the shared
## world/session stays alive underneath — unlike solo Spire's change_scene_to_node,
## which would kick the whole co-op session to the main menu). "Continue" routes
## everyone back to madrian via the standard shared map transition. Also reached
## directly via the recv_coop_spire_run_ended RPC on non-authority peers —
## NetSync's dispatch requires this WorldScene's fixed node path to resolve, which
## in practice means it's attached, matching the same "connected permanently, RPC
## arrives once reattached" assumption every other cross-battle broadcast in this
## file already relies on (leaderboard/party-bounty/siege-reward RPCs, etc.) —
## not a new risk introduced here.

func _on_coop_spire_run_ended_received(payload: Dictionary) -> void:
	SceneManager.set_coop_spire_run_mirror({"active": false})
	if _world._coop_spire_summary_overlay != null and is_instance_valid(_world._coop_spire_summary_overlay):
		_world._coop_spire_summary_overlay.queue_free()
	var overlay := _RunSummaryScene.instantiate()
	overlay.coop_stats = {
		"floors_cleared": int(payload.get("floors_cleared", 0)),
		"party_size": int(payload.get("party_size", 1)),
		"roster": payload.get("roster", []),
	}
	get_tree().current_scene.add_child(overlay)
	overlay.continue_pressed.connect(_on_coop_spire_summary_continue)
	_world._coop_spire_summary_overlay = overlay


## "Continue" pressed on the co-op Spire run summary — broadcast + perform the
## shared transition back to madrian (same TID-355 mechanism as every other
## shared-map exit) and free the overlay.

func _on_coop_spire_summary_continue() -> void:
	if _world._coop_spire_summary_overlay != null and is_instance_valid(_world._coop_spire_summary_overlay):
		_world._coop_spire_summary_overlay.queue_free()
	_world._coop_spire_summary_overlay = null
	if _world._coop_active and _world._net_sync != null and not _world._coop_map_transitioning:
		_world._coop_map_transitioning = true
		_world._net_sync.rpc("recv_map_transition", "madrian", "")
	SceneManager.enter_coop_map_no_stack("madrian", "")

# ── Co-op Town Siege (GID-103 / TID-384) ──────────────────────────────────────
#
# Host-only trigger (same precedent as the Dungeon Crawl button above): a
# deterministic siege id seeds WAVE_COUNT escalating raider waves, each spawned
# identically on every peer (CoopSiege.generate_wave) and synced purely through
# the existing GID-096 engage-lock events — no new spawn RPC needed, only "advance
# to wave N" / "start the boss phase" broadcasts. The finale boss hands off to the
# GID-099 joint PvE battle engine (this is that engine's first caller) so the
# whole party fights it together; victory splits gold + a card among every
# session member.

## Host-only: derive a shared siege id and broadcast the start so every peer
## begins the identical wave sequence.

func _start_coop_siege() -> void:
	if not NetworkManager.is_host() or _world._net_sync == null:
		return
	if not _world._coop_active or _world._coop_siege_active or not _CoopSiege.supports_map(_world.map_name):
		return
	var siege_id: int = randi()
	if SessionStore.is_open():
		var st = SessionStore.get_state()
		# world_seed + days_elapsed: retriggering later the same day reproduces the
		# same waves; a new day yields a fresh sequence (mirrors _start_dungeon_crawl).
		siege_id = hash(str(st.world_seed) + "_siege_" + str(st.days_elapsed))
	_world._net_sync.rpc("recv_siege_started", siege_id)
	_on_siege_started_received(siege_id)

## Any peer: a siege has begun — reset local state and spawn wave 0.

func _on_siege_started_received(siege_id: int) -> void:
	if not _world._coop_active:
		return
	_world._coop_siege_active = true
	_coop_siege_id = siege_id
	_world._coop_siege_wave = 0
	GameBus.hud_message_requested.emit("The town is under siege!")
	_coop_spawn_siege_wave()

## Spawn the current wave's deterministic raiders (identical on every peer).

func _coop_spawn_siege_wave() -> void:
	var gate: Vector3 = _SiegeDefs.TOWN_GATES.get(_world.map_name, Vector3.ZERO)
	var plan: Array[Dictionary] = _CoopSiege.generate_wave(_world.map_name, _coop_siege_id, _world._coop_siege_wave)
	_world._coop_siege_wave_nodes.clear()
	for entry: Dictionary in plan:
		var eid: String = str(entry.get("id", ""))
		if eid == "" or _world._coop_removed_enemies.has(eid):
			continue
		var off: Vector2 = entry.get("offset", Vector2.ZERO)
		var wx: float = gate.x + off.x
		var wz: float = gate.z + off.y
		var wy: float = _world.get_terrain_height(wx, wz) + 0.5
		var node: Node3D = _EnemyScene.instantiate() as Node3D
		if node == null:
			continue
		node.call("init_from_data", {"id": eid, "enemy_type": str(entry.get("enemy_type", "martarquas_raider_1"))})
		node.position = Vector3(wx, wy, wz)
		_world._entity_root.add_child(node)
		_world._enemy_nodes[eid] = node
		_world._coop_siege_wave_nodes[eid] = node
	GameBus.hud_message_requested.emit(
		"Wave %d of %d: Siege intensifies…" % [_world._coop_siege_wave + 1, _CoopSiege.WAVE_COUNT])

## Any peer: the host advanced to a new raider wave.

func _on_siege_wave_received(siege_id: int, wave: int) -> void:
	if not _world._coop_active or siege_id != _coop_siege_id:
		return
	_world._coop_siege_wave = wave
	_coop_spawn_siege_wave()

## Any peer: every raider wave is cleared — spawn the finale boss.

func _on_siege_boss_phase_received(siege_id: int) -> void:
	if not _world._coop_active or siege_id != _coop_siege_id:
		return
	_world._coop_siege_wave = _CoopSiege.WAVE_COUNT
	_world._coop_siege_wave_nodes.clear()
	GameBus.hud_message_requested.emit("The Siege Commander arrives!")
	var boss_id: String = _CoopSiege.boss_id(siege_id)
	if _world._coop_removed_enemies.has(boss_id):
		return  # already resolved (e.g. a re-delivered broadcast on late reconciliation)
	var gate: Vector3 = _SiegeDefs.TOWN_GATES.get(_world.map_name, Vector3.ZERO)
	var node: Node3D = _EnemyScene.instantiate() as Node3D
	if node == null:
		return
	var wy: float = _world.get_terrain_height(gate.x, gate.z) + 0.5
	node.position = Vector3(gate.x, wy, gate.z)
	node.call("init_from_data", {"id": boss_id, "enemy_type": _CoopSiege.boss_enemy_type(), "tracking": false})
	_world._entity_root.add_child(node)
	_world._enemy_nodes[boss_id] = node

## Host-only: watches the current wave's engage-lock state; called every frame
## from _process while a siege is active.

func _coop_tick_siege(_delta: float) -> void:
	if not _world.coop_session._coop_world_authority() or not _world._coop_siege_active:
		return
	if _world._coop_siege_wave < 0 or _world._coop_siege_wave >= _CoopSiege.WAVE_COUNT:
		return  # boss phase already reached, or not started
	if _world._coop_siege_wave_nodes.is_empty():
		return
	for eid in _world._coop_siege_wave_nodes.keys():
		if not _world._coop_removed_enemies.has(eid):
			return  # a raider from this wave is still standing somewhere
	_world._coop_siege_wave_nodes.clear()
	_world._coop_siege_wave += 1
	if _world._coop_siege_wave >= _CoopSiege.WAVE_COUNT:
		_world._net_sync.rpc("recv_siege_boss_phase", _coop_siege_id)
		_on_siege_boss_phase_received(_coop_siege_id)
	else:
		_world._net_sync.rpc("recv_siege_wave", _coop_siege_id, _world._coop_siege_wave)
		_on_siege_wave_received(_coop_siege_id, _world._coop_siege_wave)

## Local player engaged the siege boss. A client relays the intent to the host;
## the host starts the joint battle directly.

func _coop_engage_siege_boss(edata: Dictionary) -> void:
	if not NetworkManager.is_host():
		if _world._net_sync != null:
			_world._net_sync.rpc_id(1, "submit_siege_boss_engaged", edata)
		return
	_coop_start_siege_boss_battle(edata)

## Host: a client engaged the siege boss — start the joint battle for everyone.

func _on_siege_boss_engaged_submitted(_sender: int, edata: Dictionary) -> void:
	if not NetworkManager.is_host():
		return
	_coop_start_siege_boss_battle(edata)

## Host-only: gathers every connected member's deck and starts the joint PvE
## battle (GID-099). Boss HP/tier scaling by party size happens inside
## BattleScene._build_coop_pve_state — edata is passed through unscaled, exactly
## like a normal EnemyNPC.engage() payload.

func _coop_start_siege_boss_battle(edata: Dictionary) -> void:
	if not NetworkManager.is_host() or _world._net_sync == null:
		return
	var boss_eid: String = str(edata.get("id", ""))
	if boss_eid != "":
		# Remove the boss node locally too: if a CLIENT engaged it, the host's own
		# copy is still standing (only the engager's local node freed itself via
		# EnemyNPC.engage()). RPCs in this codebase are declared "call_remote" (never
		# self-invoking), so the broadcast below reaches every *other* peer but not
		# this one — _coop_remove_enemy_node covers the host's own copy and is a
		# harmless no-op if it's already gone (the host-engaged case).
		_world.coop_session._coop_remove_enemy_node(boss_eid)
		_world._net_sync.rpc("recv_world_event", _WorldObjectSync.encode_event(
			_WorldObjectSync.EV_ENEMY_REMOVED, boss_eid))
	var abs_peer_ids: Array[int] = [multiplayer.get_unique_id()]
	var clients: Array = multiplayer.get_peers()
	clients.sort()
	for pid in clients:
		abs_peer_ids.append(int(pid))
	var all_decks: Array = []
	for pid in abs_peer_ids:
		all_decks.append(_world.coop_pvp._team_deck_for_peer(pid))
	for i in range(abs_peer_ids.size()):
		var pid: int = abs_peer_ids[i]
		if pid != multiplayer.get_unique_id():
			_world._net_sync.rpc_id(pid, "notify_coop_pve_start", i, all_decks, edata)
	SceneManager.enter_coop_pve_battle(0, all_decks, edata)

## Client: the host started the joint siege-boss battle — enter with our index.

func _on_notify_coop_pve_start(my_idx: int, all_ally_decks: Array, enemy_data: Dictionary) -> void:
	SceneManager.enter_coop_pve_battle(my_idx, all_ally_decks, enemy_data)

## Any peer: the joint siege-boss battle ended — reset siege UI/state; the host
## additionally distributes victory rewards to the whole party. A no-op unless a
## siege was actually active (coop_pve_battle_ended may fire for future non-siege
## joint battles too, once something else calls enter_coop_pve_battle).

func _on_coop_siege_battle_ended(did_win: bool) -> void:
	if not _world._coop_siege_active:
		return
	_world._coop_siege_active = false
	_world._coop_siege_wave = -1
	_world._coop_siege_wave_nodes.clear()
	if _world._siege_banner != null and is_instance_valid(_world._siege_banner):
		_world._siege_banner.queue_free()
		_world._siege_banner = null
	if did_win:
		if NetworkManager.is_host():
			_finish_coop_siege_victory()
	else:
		GameBus.hud_message_requested.emit("The siege defense failed…")

## Host-only: split gold + a random rare-or-better card across every session
## member, record the clear to the co-op leaderboard, and push refreshed
## character records so connected peers see their reward immediately.

func _finish_coop_siege_victory() -> void:
	if not NetworkManager.is_host() or not SessionStore.is_open():
		return
	var st = SessionStore.get_state()
	if st == null:
		return
	const SIEGE_COINS: int = 150
	var tokens: Array[String] = [MpProfile.get_token()]
	for pid in multiplayer.get_peers():
		var tok: String = str(_world._session_token_by_peer.get(int(pid), ""))
		if tok != "" and not tokens.has(tok):
			tokens.append(tok)
	var all_ids: Array[String] = _CardRegistry.get_all_ids()
	for token: String in tokens:
		var rec: Dictionary = st.get_member(token)
		if rec.is_empty():
			continue
		rec["coins"] = int(rec.get("coins", 0)) + SIEGE_COINS
		if not all_ids.is_empty():
			var reward_id: String = all_ids[randi() % all_ids.size()]
			var rarity: String = _CardDropUtil.roll_rarity(3)  # tier 3 = rare-or-better weighted
			var stats: Dictionary = _CardDropUtil.roll_stats(reward_id, rarity)
			var owned: Array = rec.get("owned_cards", [])
			var uid: String = "%s_%s_siege_%d" % [reward_id, token, Time.get_ticks_msec()]
			owned.append(_CardInstanceUtil.make(uid, reward_id, rarity,
				int(stats.get("attack", -1)), int(stats.get("health", -1)), int(stats.get("cost", -1))))
			rec["owned_cards"] = owned
		st.update_member(token, rec)
	# Note: the co-op boss-clear leaderboard entry itself is recorded generically by
	# _on_coop_pve_battle_ended_leaderboard (permanently connected to the same
	# GameBus.coop_pve_battle_ended signal for every joint PvE battle) — recording it
	# again here would double-submit to the "coop_clears" board.
	SessionStore.mark_dirty()
	# Push refreshed character records so connected peers see their new coins/card
	# without waiting for their next unrelated sync (mirrors _send_character_to_peer).
	for pid in multiplayer.get_peers():
		var tok: String = str(_world._session_token_by_peer.get(int(pid), ""))
		if tok == "":
			continue
		var rec2: Dictionary = st.get_member(tok)
		if not rec2.is_empty() and _world._net_sync != null:
			_world._net_sync.rpc_id(int(pid), "recv_character", rec2, true)
	var host_rec: Dictionary = st.get_member(MpProfile.get_token())
	if not host_rec.is_empty():
		SceneManager.save_manager.adopt_session_character(host_rec)
	GameBus.hud_message_requested.emit("Party earned %d gold and defeated the Siege!" % SIEGE_COINS)

# ── PvP challenge handshake (GID-091) ─────────────────────────────────────────

## Creates the hidden "Challenge to Battle" contextual-bar action (GID-107 / TID-396:
## registered into WorldHUD.ZONE_CONTEXT so it can never pixel-overlap the Android
## USE/Interact button or the other proximity-gated social actions, which share the
## same zone). Mobile + desktop parity.

func _on_spire_run_ended_leaderboard(stats: Dictionary) -> void:
	if not NetworkManager.is_active():
		return
	var floors_cleared: int = int(stats.get("floors_cleared", 0))
	if floors_cleared <= 0:
		return
	_submit_pve_score("spire", floors_cleared)

## Co-op boss clear: submit on a party win while a co-op session is active. The
## "value" recorded is the party size at the moment the battle ended (peers + self) —
## a v1 simplification. Neither fastest-clear timing nor the scaled boss tier are
## threaded from BattleScene back to WorldScene today (see BID-027), so party size is
## the only robust, always-available proxy of "how tough a clear this was" without
## inventing new cross-battle plumbing for this task.

func _on_coop_pve_battle_ended_leaderboard(did_win: bool) -> void:
	if not did_win or not NetworkManager.is_active():
		return
	var party_size: int = multiplayer.get_peers().size() + 1
	_submit_pve_score("coop_clears", party_size)

## Route a PvE score to the authority: host records directly via SessionStore; a
## client sends the new submit RPC. board is "spire" or "coop_clears".

func _submit_pve_score(board: String, value: int) -> void:
	if NetworkManager.is_host():
		if not SessionStore.is_open():
			return
		var st = SessionStore.get_state()
		if st == null:
			return
		var token: String = MpProfile.get_token()
		st.record_pve_score(board, token, MpProfile.get_display_name(), value,
			SceneManager.save_manager.days_elapsed)
		SessionStore.mark_dirty()
		_broadcast_pve_leaderboards()
	elif _world._net_sync != null:
		_world._net_sync.rpc_id(1, "submit_pve_leaderboard_score", board, value)

## Host: a client submitted a PvE score — record it (using the sender's already-known
## session token) and broadcast the refreshed snapshot to everyone.

func _on_pve_leaderboard_score_submitted(sender: int, board: String, value: int) -> void:
	if not NetworkManager.is_host() or not SessionStore.is_open():
		return
	var token: String = str(_world._session_token_by_peer.get(sender, ""))
	if token == "":
		return
	var st = SessionStore.get_state()
	if st == null:
		return
	var rec: Dictionary = st.get_member(token)
	var member_name: String = str(rec.get("display_name", "Player"))
	st.record_pve_score(board, token, member_name, value, SceneManager.save_manager.days_elapsed)
	SessionStore.mark_dirty()
	_broadcast_pve_leaderboards()

## Host: push the current {spire, coop_clears} PvE snapshot to one peer (0 = all).

func _broadcast_pve_leaderboards(target_peer: int = 0) -> void:
	if not NetworkManager.is_host() or _world._net_sync == null or not SessionStore.is_open():
		return
	var st = SessionStore.get_state()
	if st == null:
		return
	var snapshot: Dictionary = st.get_pve_leaderboards_snapshot()
	_world._pve_leaderboards = snapshot
	if target_peer == 0:
		_world._net_sync.rpc("recv_pve_leaderboards", snapshot)
	else:
		_world._net_sync.rpc_id(target_peer, "recv_pve_leaderboards", snapshot)
	if _world._leaderboard_overlay != null and is_instance_valid(_world._leaderboard_overlay) \
			and _world._leaderboard_overlay.has_method("refresh_pve_rows"):
		_world._leaderboard_overlay.refresh_pve_rows(_world._pve_leaderboards)

## Any peer: receive a PvE leaderboard snapshot (late-join, post-update, or an
## on-demand refresh reply) and refresh the overlay if open.

func _on_pve_leaderboards_received(snapshot: Dictionary) -> void:
	_world._pve_leaderboards = snapshot
	if _world._leaderboard_overlay != null and is_instance_valid(_world._leaderboard_overlay) \
			and _world._leaderboard_overlay.has_method("refresh_pve_rows"):
		_world._leaderboard_overlay.refresh_pve_rows(_world._pve_leaderboards)

## Host: a client asked for a fresh PvE leaderboard snapshot (e.g. switching tabs).

func _on_pve_leaderboard_request_submitted(sender: int) -> void:
	_broadcast_pve_leaderboards(sender)


# ── TID-369: Shared party bounties ────────────────────────────────────────────

func _setup_party_bounties() -> void:
	if not NetworkManager.is_host():
		return
	if not SessionStore.is_open():
		return
	var st = SessionStore.get_state()
	if st == null:
		return
	const _BountyGen = preload("res://game_logic/BountyGen.gd")
	if (st.party_bounties as Array).is_empty():
		var day_idx: int = SceneManager.save_manager.days_elapsed
		var raw: Array[Dictionary] = _BountyGen.generate_daily(_world.WORLD_SEED, day_idx)
		var bounties: Array = []
		for b: Dictionary in raw:
			var pb: Dictionary = b.duplicate(true)
			pb["progress"] = 0
			pb["contributors"] = []
			pb["completed"] = false
			bounties.append(pb)
		st.party_bounties = bounties
		SessionStore.mark_dirty()

func _build_party_bounty_panel() -> void:
	if _party_bounty_panel != null and is_instance_valid(_party_bounty_panel):
		_refresh_party_bounty_panel()
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var vh: float = vp.y
	var outer := PanelContainer.new()
	outer.name = "PartyBountyPanel"
	outer.position = Vector2(vp.x * 0.012, vp.y * 0.50)
	var style := _UiUtil.make_style(Color(0.04, 0.04, 0.08, 0.88), 6)
	outer.add_theme_stylebox_override("panel", style)
	_world._hud.add_child(outer)
	var vbox := _UiUtil.make_vbox(int(vh * 0.006), outer)
	_party_bounty_panel = vbox
	_refresh_party_bounty_panel()

func _refresh_party_bounty_panel() -> void:
	if _party_bounty_panel == null or not is_instance_valid(_party_bounty_panel):
		return
	for c in _party_bounty_panel.get_children():
		c.queue_free()
	var vh: float = get_viewport().get_visible_rect().size.y
	var title := _UiUtil.make_label("Party Bounties", int(vh * 0.020))
	title.add_theme_color_override("font_color", Color(0.85, 0.75, 0.35))
	_party_bounty_panel.add_child(title)
	if NetworkManager.is_host() and SessionStore.is_open():
		var st = SessionStore.get_state()
		if st != null:
			for b: Variant in (st.party_bounties as Array):
				if b is Dictionary:
					_add_bounty_row(b as Dictionary)

func _add_bounty_row(bd: Dictionary) -> void:
	var vh: float = get_viewport().get_visible_rect().size.y
	var lbl := Label.new()
	var cnt: int = int(bd.get("count", 1))
	var prog: int = int(bd.get("progress", 0))
	var done: bool = bool(bd.get("completed", false))
	lbl.text = "%s: %d/%d%s" % [
		str(bd.get("type", "?")), prog, cnt,
		" [done]" if done else ""]
	lbl.add_theme_font_size_override("font_size", int(vh * 0.016))
	if done:
		lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	_party_bounty_panel.add_child(lbl)


## Public: called by other WorldScene subsystems (battle won, chest opened) to
## contribute party bounty progress in co-op. Works like
## SaveManager.increment_bounty_progress but for the shared party list.

func submit_party_bounty_progress(bounty_type: String, match_data: Dictionary) -> void:
	if not _world._coop_active or _world._net_sync == null:
		return
	if NetworkManager.is_host():
		_on_party_bounty_progress_submitted(multiplayer.get_unique_id(), bounty_type, match_data)
	else:
		_world._net_sync.rpc_id(1, "submit_party_bounty_progress", bounty_type, match_data)

func _on_party_bounty_progress_submitted(sender: int, bounty_type: String, match_data: Dictionary) -> void:
	if not NetworkManager.is_host() or not SessionStore.is_open():
		return
	var st = SessionStore.get_state()
	if st == null:
		return
	var token: String = str(_world._session_token_by_peer.get(sender,
		MpProfile.get_token() if sender == multiplayer.get_unique_id() else ""))
	for i: int in range((st.party_bounties as Array).size()):
		var b: Variant = (st.party_bounties as Array)[i]
		if not (b is Dictionary):
			continue
		var bd: Dictionary = b as Dictionary
		if bool(bd.get("completed", false)):
			continue
		if str(bd.get("type", "")) != bounty_type:
			continue
		var target: String = str(bd.get("target", ""))
		var matches: bool = false
		match bounty_type:
			"defeat_enemy_type":
				matches = str(match_data.get("enemy_type", "")) == target
			"defeat_in_biome":
				matches = str(match_data.get("biome", "")) == target
			"open_chests":
				matches = true
		if not matches:
			continue
		var progress: int = int(bd.get("progress", 0))
		progress += 1
		bd["progress"] = progress
		var contributors: Array = bd.get("contributors", []) as Array
		if not contributors.has(token):
			contributors.append(token)
		bd["contributors"] = contributors
		var count: int = int(bd.get("count", 1))
		if progress >= count:
			bd["completed"] = true
			SceneManager.save_manager.add_coins(int(bd.get("reward", 0)))
		(st.party_bounties as Array)[i] = bd
		SessionStore.mark_dirty()
		var update_payload: Dictionary = {
			"bounty_id": str(bd.get("id", "")),
			"progress": progress,
			"count": count,
			"completed": bool(bd.get("completed", false)),
		}
		if _world._net_sync != null:
			_world._net_sync.rpc("recv_party_bounty_update", update_payload)
		_refresh_party_bounty_panel()
		break

func _on_party_bounty_update_received(_payload: Dictionary) -> void:
	# Clients update their local HUD row. The snapshot drives initial state;
	# incremental updates patch one row at a time.
	_refresh_party_bounty_panel()

func _on_party_bounties_snapshot_received(bounties: Array) -> void:
	# Client: received full party bounty list from host on join.
	if _party_bounty_panel == null or not is_instance_valid(_party_bounty_panel):
		# Build panel first time
		var vp: Vector2 = get_viewport().get_visible_rect().size
		var vh: float = vp.y
		var outer := PanelContainer.new()
		outer.name = "PartyBountyPanel"
		outer.position = Vector2(vp.x * 0.012, vp.y * 0.50)
		var style := _UiUtil.make_style(Color(0.04, 0.04, 0.08, 0.88), 6)
		outer.add_theme_stylebox_override("panel", style)
		_world._hud.add_child(outer)
		var vbox := _UiUtil.make_vbox(int(vh * 0.006), outer)
		_party_bounty_panel = vbox
	# Populate from snapshot
	for c in _party_bounty_panel.get_children():
		c.queue_free()
	var vh: float = get_viewport().get_visible_rect().size.y
	var title := _UiUtil.make_label("Party Bounties", int(vh * 0.020))
	title.add_theme_color_override("font_color", Color(0.85, 0.75, 0.35))
	_party_bounty_panel.add_child(title)
	for b: Variant in bounties:
		if b is Dictionary:
			_add_bounty_row(b as Dictionary)


# ── Draft duels — sealed-deck PvP (GID-104 / TID-385) ─────────────────────────
# Deterministic shared-seed model: the challenger generates one seed; both peers
# derive the IDENTICAL 1-of-3 pick rounds locally (DraftDuelGen.generate_rounds),
# so no per-pick relay is needed — each side picks independently and only the two
# finished TRANSIENT decks cross the wire (submit_draft_duel_deck), once each.
# Drafted decks live only in the resulting duel's GameState; they are never
# written to owned_cards, SaveManager, or SessionState. Always casual: never
# ranked (fair-format ratings would need their own ladder), never wagered.
# Everything here is guarded by the co-op HUD entry points (_setup_coop), so
# single-player never reaches any of it.

## Creates the hidden "Draft Duel" HUD button (mobile + desktop parity — a
## Button.pressed tap/click target, no keybind). Registered into the shared
## ZONE_CONTEXT zone (GID-115 / TID-433) — sits below the Challenge/Ranked-toggle
## pair, same zone the world-interact prompt takes priority over.
