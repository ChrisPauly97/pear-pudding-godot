## Layered "paper doll" renderer for the player hero (GID-137).
##
## The hero is drawn in code, one body part at a time, so equipped gear can
## replace or cover any part: armour recolours the torso and sleeves, a cloak
## hangs behind the body, weapons sit in the right hand and off-hands in the
## left. Every frame is a 16 × 28 image (the size of the pack art it replaced,
## so mount offsets, PLAYER_HEIGHT and the battle token keep their tuning).
##
## Layout (feet on the bottom row, facing right; flip_h mirrors it):
##   rows 1–4   hair          rows 3–9   head
##   row  10    neck          rows 11–17 torso + arms, hands on row 18
##   rows 18–24 legs          rows 25–27 boots
##
## Frames: pose 0 is idle, poses 1–4 are the walk cycle (left stride, pass,
## right stride, pass). `build_frames()` caches SpriteFrames by look, so every
## co-op avatar in the same gear shares one set of textures.
##
## Adding gear: one `GEAR_VISUALS` entry keyed by the item id. `test_paper_doll`
## fails if an armour, weapon, off-hand or trinket in WeaponRegistry has none.
extends RefCounted

const _SpriteRegistry = preload("res://game_logic/SpriteRegistry.gd")

const FRAME_W: int = 16
const FRAME_H: int = 28
const WALK_POSES: int = 4

## Slots that change the hero's look. Rings are too small to read at 16 px.
const VISIBLE_SLOTS: Array[String] = ["armor", "weapon", "offhand", "trinket"]

const DEFAULT_APPEARANCE: Dictionary = {
	"skin": Color(0.93, 0.76, 0.62),
	"hair": Color(0.42, 0.26, 0.14),
	"eyes": Color(0.14, 0.12, 0.2),
	"shirt": Color(0.74, 0.67, 0.52),
	"trousers": Color(0.36, 0.29, 0.21),
	"boots": Color(0.3, 0.2, 0.12),
	"belt": Color(0.24, 0.16, 0.1),
}

## Item id → how it draws. `style` picks the draw routine; colours are the
## item's palette (`main`, optional `trim`/`accent`).
const GEAR_VISUALS: Dictionary = {
	# Armour — replaces the shirt on the torso (and sleeves where noted).
	"leather_vest": {"style": "vest", "main": Color(0.55, 0.35, 0.18), "trim": Color(0.38, 0.23, 0.11)},
	"chainmail": {"style": "mail", "main": Color(0.64, 0.67, 0.72), "trim": Color(0.44, 0.47, 0.53)},
	"warded_cloak": {"style": "cloak", "main": Color(0.22, 0.26, 0.52), "trim": Color(0.86, 0.72, 0.3)},
	# Main hand.
	"rusty_dagger": {"style": "dagger", "main": Color(0.62, 0.5, 0.4), "trim": Color(0.35, 0.24, 0.14)},
	"dusk_blade": {"style": "sword", "main": Color(0.62, 0.56, 0.84), "trim": Color(0.3, 0.22, 0.42)},
	"berserker_axe": {"style": "axe", "main": Color(0.72, 0.3, 0.26), "trim": Color(0.4, 0.27, 0.15)},
	"dawn_staff": {"style": "staff", "main": Color(0.55, 0.4, 0.22), "trim": Color(1.0, 0.86, 0.4)},
	"ember_wand": {"style": "wand", "main": Color(0.35, 0.22, 0.14), "trim": Color(1.0, 0.55, 0.2)},
	"mana_crystal": {"style": "crystal", "main": Color(0.45, 0.85, 1.0), "trim": Color(0.8, 0.97, 1.0)},
	"iron_shield": {"style": "shield", "main": Color(0.55, 0.58, 0.62), "trim": Color(0.35, 0.37, 0.41)},
	# Off hand.
	"buckler": {"style": "buckler", "main": Color(0.55, 0.38, 0.2), "trim": Color(0.72, 0.72, 0.76)},
	"parrying_dagger": {"style": "dagger", "main": Color(0.78, 0.8, 0.86), "trim": Color(0.3, 0.22, 0.14)},
	"arcane_focus": {"style": "orb", "main": Color(0.68, 0.45, 0.95), "trim": Color(0.92, 0.82, 1.0)},
	# Trinkets — small accents on the belt or neck.
	"bone_charm": {"style": "necklace", "main": Color(0.92, 0.9, 0.8)},
	"ember_flask": {"style": "flask", "main": Color(1.0, 0.5, 0.18), "trim": Color(0.6, 0.62, 0.66)},
	"lucky_coin": {"style": "coin", "main": Color(1.0, 0.84, 0.3)},
}

static var _frames_cache: Dictionary = {}  # look key → SpriteFrames


## The visible gear of a save-like object (SaveManager or a session record
## wrapper): slot → item id. Read through `get()` so headless `-s` scripts,
## which run before autoloads exist, can call it too.
static func gear_of(save: Object) -> Dictionary:
	var gear: Dictionary = {}
	if save == null:
		return gear
	for slot: String in VISIBLE_SLOTS:
		gear[slot] = str(save.get("equipped_" + slot))
	return gear


## Gear from a synced session record (Dictionary with `equipped_<slot>` keys).
static func gear_of_record(record: Dictionary) -> Dictionary:
	var gear: Dictionary = {}
	for slot: String in VISIBLE_SLOTS:
		gear[slot] = str(record.get("equipped_" + slot, ""))
	return gear


## Idle + 4-frame walk SpriteFrames for this look (cached).
static func build_frames(gear: Dictionary = {}, appearance: Dictionary = {}, fps: float = 6.0) -> SpriteFrames:
	var key: String = _look_key(gear, appearance) + "@" + str(fps)
	if _frames_cache.has(key):
		return _frames_cache[key] as SpriteFrames
	var walk: Array[Texture2D] = []
	for pose: int in range(1, WALK_POSES + 1):
		walk.append(ImageTexture.create_from_image(render_frame(gear, appearance, pose)))
	var idle: Texture2D = ImageTexture.create_from_image(render_frame(gear, appearance, 0))
	var sf: SpriteFrames = _SpriteRegistry.make_idle_walk_frames(idle, walk, fps)
	_frames_cache[key] = sf
	return sf


## The idle frame as a texture (battle token, portraits).
static func idle_texture(gear: Dictionary = {}, appearance: Dictionary = {}) -> Texture2D:
	return build_frames(gear, appearance).get_frame_texture("idle", 0)


static func _look_key(gear: Dictionary, appearance: Dictionary) -> String:
	var parts: PackedStringArray = []
	for slot: String in VISIBLE_SLOTS:
		parts.append(str(gear.get(slot, "")))
	for k: String in DEFAULT_APPEARANCE:
		if appearance.has(k):
			parts.append(k + "=" + str(appearance[k]))
	return "|".join(parts)


# ── Rendering ────────────────────────────────────────────────────────────────

## Renders one frame. Pose 0 = idle, 1..4 = walk cycle.
static func render_frame(gear: Dictionary, appearance: Dictionary, pose: int) -> Image:
	var img := Image.create(FRAME_W, FRAME_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var look: Dictionary = DEFAULT_APPEARANCE.duplicate()
	look.merge(appearance, true)
	var p: Dictionary = _pose(pose)
	var armor: Dictionary = _visual(gear, "armor")
	var weapon: Dictionary = _visual(gear, "weapon")
	var offhand: Dictionary = _visual(gear, "offhand")
	var trinket: Dictionary = _visual(gear, "trinket")
	var bob: int = int(p["bob"])

	if str(armor.get("style", "")) == "cloak":
		_draw_cloak_back(img, armor, bob)
	_draw_legs(img, look, p)
	_draw_torso(img, look, armor, bob)
	_draw_trinket(img, trinket, bob)
	var back_hand := Vector2i(3, 18 + bob + int(p["arm_l"]))
	var front_hand := Vector2i(12, 18 + bob + int(p["arm_r"]))
	_draw_arm(img, look, armor, back_hand, bob, true)
	_draw_arm(img, look, armor, front_hand, bob, false)
	_draw_head(img, look, bob)
	if str(armor.get("style", "")) == "cloak":
		_draw_cloak_front(img, armor, bob)
	_draw_held(img, offhand, back_hand, look, true)
	_draw_held(img, weapon, front_hand, look, false)
	return img


## Limb offsets for a pose: `leg_l/leg_r` lift (px up), `arm_l/arm_r` swing
## (px down = forward), `step` the lifted foot's forward shift, `bob` body drop.
static func _pose(pose: int) -> Dictionary:
	match pose:
		1:
			return {"leg_l": 1, "leg_r": 0, "arm_l": -1, "arm_r": 1, "step_l": 1, "step_r": 0, "bob": 0}
		2:
			return {"leg_l": 0, "leg_r": 0, "arm_l": 0, "arm_r": 0, "step_l": 0, "step_r": 0, "bob": 1}
		3:
			return {"leg_l": 0, "leg_r": 1, "arm_l": 1, "arm_r": -1, "step_l": 0, "step_r": 1, "bob": 0}
		4:
			return {"leg_l": 0, "leg_r": 0, "arm_l": 0, "arm_r": 0, "step_l": 0, "step_r": 0, "bob": 1}
	return {"leg_l": 0, "leg_r": 0, "arm_l": 0, "arm_r": 0, "step_l": 0, "step_r": 0, "bob": 0}


static func _visual(gear: Dictionary, slot: String) -> Dictionary:
	var id: String = str(gear.get(slot, ""))
	if id == "" or not GEAR_VISUALS.has(id):
		return {}
	var v: Dictionary = GEAR_VISUALS[id]
	return v


static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < FRAME_W and y < FRAME_H:
		img.set_pixel(x, y, c)


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy: int in range(y, y + h):
		for xx: int in range(x, x + w):
			_px(img, xx, yy, c)


static func _col(d: Dictionary, key: String) -> Color:
	var c: Color = d.get(key, Color.MAGENTA)
	return c


# ── Body parts ───────────────────────────────────────────────────────────────

static func _draw_legs(img: Image, look: Dictionary, p: Dictionary) -> void:
	var trousers: Color = _col(look, "trousers")
	var boots: Color = _col(look, "boots")
	# Hips span both legs so a stride never opens a gap under the belt.
	_rect(img, 5, 18 + int(p["bob"]), 6, 1, trousers)
	for side: int in [0, 1]:
		var lift: int = int(p["leg_l"] if side == 0 else p["leg_r"])
		var step: int = int(p["step_l"] if side == 0 else p["step_r"])
		var x: int = (5 if side == 0 else 8) + step
		var top: int = 19 + int(p["bob"])
		var boot_y: int = 25 - lift
		_rect(img, x, top, 3, boot_y - top, trousers)
		_rect(img, x, top, 1, boot_y - top, trousers.darkened(0.25))  # inner shade
		_rect(img, x, boot_y, 3, 3, boots)
		_px(img, x + 3, boot_y + 2, boots)                            # toe, facing right
		_rect(img, x, boot_y, 3, 1, boots.lightened(0.15))           # cuff


static func _draw_torso(img: Image, look: Dictionary, armor: Dictionary, bob: int) -> void:
	var y: int = 11 + bob
	var shirt: Color = _col(look, "shirt")
	_rect(img, 5, y, 6, 7, shirt)
	_rect(img, 5, y, 1, 7, shirt.darkened(0.1))
	match str(armor.get("style", "")):
		"vest":
			var main: Color = _col(armor, "main")
			_rect(img, 5, y, 6, 6, main)
			_rect(img, 5, y, 1, 6, main.darkened(0.2))
			_rect(img, 7, y, 2, 3, shirt)                       # open collar
			_rect(img, 7, y + 3, 2, 3, _col(armor, "trim"))     # lacing
		"mail":
			var main: Color = _col(armor, "main")
			var dark: Color = _col(armor, "trim")
			for yy: int in range(y, y + 7):
				for xx: int in range(5, 11):
					_px(img, xx, yy, dark if (xx + yy) % 2 == 0 else main)
	_rect(img, 5, y + 6, 6, 1, _col(look, "belt"))
	_px(img, 8, y + 6, Color(0.85, 0.72, 0.35))                 # buckle
	_rect(img, 7, 10 + bob, 2, 1, _col(look, "skin").darkened(0.12))  # neck


static func _draw_arm(img: Image, look: Dictionary, armor: Dictionary, hand: Vector2i, bob: int,
		back: bool) -> void:
	var sleeve: Color = _col(look, "shirt")
	var style: String = str(armor.get("style", ""))
	if style == "mail":
		sleeve = _col(armor, "main")
	elif style == "cloak":
		sleeve = _col(armor, "main").lightened(0.1)
	if back:
		sleeve = sleeve.darkened(0.3)
	var x: int = 3 if back else 11
	# The shoulder stays on the torso; the swing only moves the hand.
	var top: int = 11 + bob
	_rect(img, x, top, 2, hand.y - top, sleeve)
	# A darker seam on the side touching the torso keeps the arm readable.
	_rect(img, 4 if back else 11, top + 1, 1, hand.y - top - 1, sleeve.darkened(0.25))
	_rect(img, x, top, 2, 1, sleeve.lightened(0.1))
	_draw_hand(img, look, hand, back)


static func _draw_hand(img: Image, look: Dictionary, hand: Vector2i, back: bool) -> void:
	var skin: Color = _col(look, "skin")
	_rect(img, hand.x if back else hand.x - 1, hand.y, 2, 1, skin.darkened(0.15) if back else skin)


static func _draw_head(img: Image, look: Dictionary, bob: int) -> void:
	var skin: Color = _col(look, "skin")
	var hair: Color = _col(look, "hair")
	var y: int = 3 + bob
	_rect(img, 5, y, 6, 7, skin)
	_rect(img, 5, y, 1, 7, skin.darkened(0.15))
	_px(img, 11, y + 4, skin)                                   # nose, facing right
	_px(img, 7, y + 3, _col(look, "eyes"))
	_px(img, 9, y + 3, _col(look, "eyes"))
	_px(img, 8, y + 5, skin.darkened(0.25))                     # mouth
	# Hair: crown, fringe and a fall down the back of the head.
	_rect(img, 5, y - 2, 6, 2, hair)
	_rect(img, 4, y - 1, 1, 5, hair)
	_rect(img, 5, y, 6, 1, hair)
	_rect(img, 5, y + 1, 2, 1, hair)
	_px(img, 10, y + 1, hair)
	_rect(img, 6, y - 2, 3, 1, hair.lightened(0.2))             # shine


# ── Gear ─────────────────────────────────────────────────────────────────────

static func _draw_cloak_back(img: Image, armor: Dictionary, bob: int) -> void:
	var main: Color = _col(armor, "main").darkened(0.25)
	_rect(img, 3, 11 + bob, 10, 11, main)
	_rect(img, 2, 15 + bob, 1, 8, main)                          # flare at the hem
	_rect(img, 3, 22 + bob, 9, 1, _col(armor, "trim").darkened(0.2))


static func _draw_cloak_front(img: Image, armor: Dictionary, bob: int) -> void:
	var main: Color = _col(armor, "main")
	_rect(img, 3, 10 + bob, 10, 2, main)                         # mantle over the shoulders
	_rect(img, 3, 11 + bob, 2, 1, main.darkened(0.15))
	_rect(img, 7, 10 + bob, 2, 1, _col(armor, "trim"))            # clasp


static func _draw_trinket(img: Image, trinket: Dictionary, bob: int) -> void:
	match str(trinket.get("style", "")):
		"necklace":
			_rect(img, 6, 11 + bob, 4, 1, _col(trinket, "main").darkened(0.3))
			_px(img, 8, 12 + bob, _col(trinket, "main"))
		"flask":
			_px(img, 10, 16 + bob, _col(trinket, "trim"))
			_rect(img, 9, 17 + bob, 2, 2, _col(trinket, "main"))
		"coin":
			_px(img, 6, 17 + bob, _col(trinket, "main"))


## A held item anchored at `hand`. Main-hand items point up and forward;
## off-hand shields cover the back arm.
static func _draw_held(img: Image, item: Dictionary, hand: Vector2i, look: Dictionary, back: bool) -> void:
	if item.is_empty():
		return
	var main: Color = _col(item, "main")
	var trim: Color = item.get("trim", main.darkened(0.3))
	# Items are held just outside the hand: forward of the front hand, behind the back one.
	var hx: int = hand.x - 1 if back else hand.x + 1
	var hy: int = hand.y
	match str(item.get("style", "")):
		"dagger":
			_rect(img, hx, hy - 4, 1, 4, main)
			_rect(img, hx - 1, hy - 1, 3, 1, trim)
		"sword":
			_rect(img, hx, hy - 8, 1, 7, main)
			_px(img, hx, hy - 9, main.lightened(0.3))
			_rect(img, hx - 1, hy - 1, 3, 1, trim)
			_px(img, hx, hy + 1, trim)
		"axe":
			_rect(img, hx, hy - 8, 1, 10, trim)
			_rect(img, hx + 1, hy - 9, 2, 5, main)
			_rect(img, hx + 1, hy - 9, 2, 1, main.lightened(0.25))  # edge
			_px(img, hx - 1, hy - 7, main.darkened(0.2))
		"staff":
			_rect(img, hx, hy - 14, 1, 23, main)
			_rect(img, hx - 1, hy - 17, 3, 3, trim)
			_px(img, hx, hy - 16, Color(1, 1, 1))
		"wand":
			_rect(img, hx, hy - 4, 1, 4, main)
			_px(img, hx, hy - 5, trim)
			_px(img, hx + 1, hy - 6, trim.lightened(0.3))
		"crystal":
			_rect(img, hx - 1, hy - 5, 3, 3, main)
			_px(img, hx, hy - 6, trim)
			_px(img, hx, hy - 4, trim)
		"orb":
			_rect(img, hx - 1, hy - 3, 2, 2, main)
			_px(img, hx - 1, hy - 3, trim)
		"buckler", "shield":
			var sx: int = hand.x - 1
			var size: int = 4 if str(item.get("style", "")) == "buckler" else 5
			_rect(img, sx, hy - size + 1, size, size, main)
			_rect(img, sx, hy - size + 1, size, 1, trim)
			_rect(img, sx, hy, size, 1, main.darkened(0.3))
			_px(img, sx + size / 2, hy - size / 2, trim.lightened(0.2))  # boss
			return  # the shield covers the hand
	_draw_hand(img, look, hand, back)                          # grip over the handle
