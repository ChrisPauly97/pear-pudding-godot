## Rideable mounts (GID-048, docs/agent/rideable-mounts.md): the Madrian stable
## purchase panel, the mount toggle (T key / HUD Mount button) and the
## auto-dismount when a battle starts. Price and stats come from MountRegistry.
extends Node

const _WorldScene = preload("res://scenes/world/WorldScene.gd")
const MountRegistry = preload("res://game_logic/MountRegistry.gd")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")

const STABLE_MOUNT_ID: String = "stable_horse"
const LEVEL_REQ: int = 10
const _PANEL_BG := Color(0.06, 0.04, 0.14, 0.96)
const _WARN := Color(0.9, 0.3, 0.3)

var _world: _WorldScene = null

## Mounts / dismounts. Riding is open-world only.
func toggle() -> void:
	var sm := SceneManager.save_manager
	if sm.current_map != "main" or sm.owned_mounts.is_empty():
		return
	if sm.is_mounted:
		sm.dismiss_mount()
	else:
		sm.summon_mount(str(sm.owned_mounts[0]))

## GameBus.enemy_engaged: battles are fought on foot. `active_mount` survives
## so the player remounts after the win (WorldScene._on_battle_won).
func on_enemy_engaged(_enemy_data: Dictionary) -> void:
	if SceneManager.save_manager.is_mounted:
		SceneManager.save_manager.auto_dismiss_mount()

static func price(mount_id: String = STABLE_MOUNT_ID) -> int:
	return int(MountRegistry.get_mount(mount_id).get("price", 0))

func show_stable_panel() -> void:
	var sm := SceneManager.save_manager
	if sm.owned_mounts.has(STABLE_MOUNT_ID):
		_world._show_dialogue("You already own a Stable Horse!")
		return
	var mount: Dictionary = MountRegistry.get_mount(STABLE_MOUNT_ID)
	var cost: int = price()
	var level_ok: bool = sm.level >= LEVEL_REQ
	var coins_ok: bool = sm.coins >= cost

	var modal: Dictionary = _world._build_modal(0.60, 0.36, _PANEL_BG, 0.015, 0.02)
	var layer: CanvasLayer = modal["layer"]
	var vbox: VBoxContainer = modal["vbox"]
	var vh: float = _world.get_viewport().get_visible_rect().size.y
	var body_font: int = int(vh * 0.027)
	_UiUtil.make_label("Madrian Stables", int(vh * 0.035), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vbox)
	_UiUtil.make_label("%s\n  Speed: ×%.1f   Price: %d coins" % [
			str(mount.get("display_name", "Stable Horse")), float(mount.get("speed_multiplier", 2.0)), cost],
		body_font, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vbox)
	var status: String = "Balance: %d coins" % sm.coins
	if not level_ok:
		status = "Requires level %d (you are level %d)" % [LEVEL_REQ, sm.level]
	elif not coins_ok:
		status = "Insufficient coins (need %d, have %d)" % [cost, sm.coins]
	_UiUtil.make_label(status, int(vh * 0.025), Color.WHITE if level_ok and coins_ok else _WARN,
		HORIZONTAL_ALIGNMENT_CENTER, vbox)

	var hbox := _UiUtil.make_hbox(int(vh * 0.02), vbox)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var buy := func() -> void:
		sm.add_coins(-cost)
		sm.owned_mounts.append(STABLE_MOUNT_ID)
		sm.summon_mount(STABLE_MOUNT_ID)
		layer.queue_free()
		_world._world_hud.update_mount_btn()
		_world._show_dialogue("You purchased a Stable Horse! Press T or tap Mount to ride.")
	var buy_btn := _UiUtil.make_button("Buy (%d coins)" % cost, Vector2(vh * 0.28, vh * 0.065), body_font, buy, hbox)
	buy_btn.disabled = not level_ok or not coins_ok
	_UiUtil.make_button("Cancel", Vector2(vh * 0.16, vh * 0.065), body_font, layer.queue_free, hbox)
