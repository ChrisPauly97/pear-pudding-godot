## Gear inspect popup body (GID-187 / TID-792): an item's details and, for an item not yet worn, the
## equipped item and the green / red stat deltas. CharacterScene builds the tooltips (GearTooltip) and
## this lays them out in the popup's VBox. Sizes are fractions of `ref` (the viewport's short side).
extends RefCounted

const _UiUtil = preload("res://scenes/ui/UiUtil.gd")
const _GearTooltip = preload("res://game_logic/items/GearTooltip.gd")
const _WeaponData = preload("res://data/WeaponData.gd")
const _SaveManagerScript = preload("res://autoloads/SaveManager.gd")
const _WeaponRegistry = preload("res://autoloads/WeaponRegistry.gd")

static func fill(vb: VBoxContainer, ref: float, title: String, cand_tip: Dictionary, eq_tip: Dictionary,
		rows: Array[Dictionary], note: String) -> void:
	_UiUtil.make_label(title, int(ref * 0.022), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vb)
	_block(vb, ref, cand_tip, Color(0.6, 1.0, 0.7), "")
	if not eq_tip.is_empty():
		vb.add_child(HSeparator.new())
		_block(vb, ref, eq_tip, Color(0.75, 0.75, 0.75), "Equipped: ")
	if not rows.is_empty():
		_label("Compared with equipped", ref * 0.018, Color(0.7, 0.7, 0.7), vb)
		for row: Dictionary in rows:
			var gain: bool = bool(row["gain"])
			_label(str(row["text"]), ref * 0.020, Color(0.4, 1.0, 0.5) if gain else Color(1.0, 0.45, 0.4), vb)
	if note != "":
		_label(note, ref * 0.018, Color(0.7, 0.7, 0.7), vb)

## One item's block: name in its rarity colour, band and level requirement (red when unmet), then
## the stat and mechanic lines.
static func _block(vb: VBoxContainer, ref: float, tip: Dictionary, tint: Color, prefix: String) -> void:
	if tip.is_empty():
		return
	_label(prefix + str(tip["name"]), ref * 0.020, _UiUtil.rarity_color(str(tip["rarity"])), vb)
	_label(str(tip["band_line"]), ref * 0.018, Color(0.7, 0.7, 0.7), vb)
	var req_tint: Color = Color(0.7, 0.7, 0.7) if bool(tip["level_ok"]) else Color(1.0, 0.45, 0.4)
	_label(str(tip["requires_line"]), ref * 0.018, req_tint, vb)
	var stat_lines: Array[String] = tip["stat_lines"]
	for line: String in stat_lines:
		_label(line, ref * 0.020, tint, vb)
	var mech: String = str(tip["mechanic_line"])
	if mech != "":
		_label(mech, ref * 0.020, tint, vb)

static func _label(text: String, font_px: float, tint: Color, vb: VBoxContainer) -> void:
	var lbl := _UiUtil.make_label(text, int(font_px), tint, HORIZONTAL_ALIGNMENT_LEFT, vb)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

## Blacksmith upgrade level of an owned item (weapons only; other slots never upgrade).
static func upgrade_level_of(sm: _SaveManagerScript, item_id: String, slot: String) -> int:
	if slot != "weapon" or item_id == "":
		return 0
	return int(sm.get_owned_weapon_by_id(item_id).get("upgrade_level", 0))

## Character sheet (GID-187 / TID-792): replaces `vb`'s rows with every stat across the gear equipped
## in `slots`, totalled at the player's level (ratings and % of the total).
static func fill_sheet(vb: VBoxContainer, ref: float, sm: _SaveManagerScript, slots: Array[String]) -> void:
	for child in vb.get_children():
		child.queue_free()
	var entries: Array[Dictionary] = []
	for slot: String in slots:
		var eid: String = sm.get_equipped_by_slot(slot)
		var w: _WeaponData = _WeaponRegistry.get_weapon(eid) if eid != "" else null
		if w != null:
			entries.append({"weapon": w, "level": upgrade_level_of(sm, eid, slot)})
	var lines: Array[String] = _GearTooltip.sheet_lines(entries, sm.level)
	if lines.is_empty():
		_label("No gear stats equipped.", ref * 0.019, Color(0.6, 0.6, 0.6), vb)
	for line: String in lines:
		_label(line, ref * 0.019, Color(0.9, 1.0, 0.7), vb)
