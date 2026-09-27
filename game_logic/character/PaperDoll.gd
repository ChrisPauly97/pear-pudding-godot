## Layered "paper doll" renderer for the player hero (GID-137).
##
## The hero is drawn in code, one body part at a time, so equipped gear can
## replace or cover any part: armour recolours the torso and sleeves, pauldrons
## cap the shoulders, a cloak hangs behind the body, weapons sit in the front
## hand and off-hands in the back one. Frames are 32 × 28: the body is drawn in a
## centred 16-px column (`_ox` shifts every draw), the same height as the pack
## art it replaced, so mount offsets, PLAYER_HEIGHT and the battle token keep
## their tuning; the spare width gives a forward weapon swing room.
##
## Look: grounded rather than cartoon — a small head on a long body, a muted
## palette, three-tone shading (cool shadow, base, warm highlight) and a
## deterministic grime dither over cloth, leather and metal (`_fill`).
##
## Layout (feet on the bottom row, facing right; flip_h mirrors it):
##   rows 1–3   hair          rows 3–8   head (5 wide)
##   row  9     neck          rows 10–17 torso + arms, hands on row 18
##   rows 18–24 legs          rows 25–27 boots
##
## Animations (`ANIMS`): idle, an 8-frame walk (contact, down, pass, reach per
## leg), a 4-frame weapon swing (wind-up, strike, follow-through, recover),
## jump (crouch, rise), fall, and land. A pose moves hands by offset, lifts and
## steps legs, drops the body (`bob`) and angles the main-hand item (`wpn`,
## degrees clockwise from straight up; drawn upright then rotated about the
## grip). `build_frames()` caches SpriteFrames by look, so every co-op avatar
## in the same gear shares one set of textures.
##
## Split for size: pixel helpers live in `PaperDollPixels.gd`, gear drawing in
## `PaperDollGear.gd`; this file extends both (inherited statics, no qualifier).
##
## Adding gear: one `GEAR_VISUALS` entry keyed by the item id. `test_paper_doll`
## fails if an item in a `VISIBLE_SLOTS` slot of WeaponRegistry has none.
extends "res://game_logic/character/PaperDollGear.gd"

const FRAME_W: int = 32
const FRAME_H: int = 28
## Left edge of the 16-px body column inside the frame.
const OX: int = 8
const WALK_POSES: int = 8

## Neutral pose; each `ANIMS` pose overrides some of these keys.
const _REST: Dictionary = {
	"bob": 0, "leg_l": 0, "leg_r": 0, "step_l": 0, "step_r": 0,
	"hand_l": Vector2i.ZERO, "hand_r": Vector2i.ZERO, "wpn": 0.0,
	# Draw the main-hand item behind the body (a wind-up held over the shoulder).
	"wpn_behind": false,
}

## name → {fps, loop, poses}. `l` = far (back) side, `r` = near (front) side.
const ANIMS: Dictionary = {
	"idle": {"fps": 1.0, "loop": true, "poses": [{}]},
	"walk": {"fps": 12.0, "loop": true, "poses": [
		{"step_l": 1, "step_r": -1, "hand_r": Vector2i(1, 0), "hand_l": Vector2i(-1, 0)},             # L contact
		{"step_l": 1, "step_r": -1, "hand_r": Vector2i(1, 0), "hand_l": Vector2i(-1, 0), "bob": 1},   # down
		{"leg_r": 1},                                                                                # pass
		{"leg_r": 1, "step_r": 1},                                                                   # reach
		{"step_r": 1, "step_l": -1, "hand_r": Vector2i(-1, 0), "hand_l": Vector2i(1, 0)},             # R contact
		{"step_r": 1, "step_l": -1, "hand_r": Vector2i(-1, 0), "hand_l": Vector2i(1, 0), "bob": 1},   # down
		{"leg_l": 1},                                                                                # pass
		{"leg_l": 1, "step_l": 1},                                                                   # reach
	]},
	"swing": {"fps": 12.0, "loop": false, "poses": [
		{"hand_r": Vector2i(-3, -4), "hand_l": Vector2i(1, -1), "wpn": -105.0, "wpn_behind": true}, # wind-up
		{"hand_r": Vector2i(2, -5), "hand_l": Vector2i(-1, 0), "wpn": 80.0, "step_r": 1},            # strike
		{"hand_r": Vector2i(2, -2), "hand_l": Vector2i(-1, 0), "wpn": 135.0, "step_r": 1, "bob": 1}, # follow
		{"hand_r": Vector2i(1, -1), "wpn": 30.0},                                                    # recover
	]},
	"jump": {"fps": 12.0, "loop": false, "poses": [
		{"bob": 2, "hand_r": Vector2i(1, -1), "hand_l": Vector2i(1, -1)},                            # crouch
		{"bob": -1, "leg_l": 2, "leg_r": 1, "step_l": 1, "hand_r": Vector2i(1, -4),
			"hand_l": Vector2i(-1, -4), "wpn": 20.0},                                                # rise
	]},
	"fall": {"fps": 1.0, "loop": true, "poses": [
		{"leg_l": 1, "step_r": 1, "hand_r": Vector2i(2, -5), "hand_l": Vector2i(-2, -5), "wpn": 45.0},
	]},
	"land": {"fps": 12.0, "loop": false, "poses": [
		{"bob": 2, "hand_r": Vector2i(1, 0), "hand_l": Vector2i(1, 0)},
		{"bob": 1},
	]},
}

## Slots that change the hero's look. Rings are too small to read at 16 px.
const VISIBLE_SLOTS: Array[String] = ["armor", "shoulders", "weapon", "offhand", "trinket"]

const DEFAULT_APPEARANCE: Dictionary = {
	"skin": Color(0.76, 0.58, 0.46),
	"hair": Color(0.23, 0.16, 0.11),
	"eyes": Color(0.1, 0.09, 0.1),
	"shirt": Color(0.5, 0.45, 0.36),
	"trousers": Color(0.27, 0.24, 0.2),
	"boots": Color(0.21, 0.15, 0.11),
	"belt": Color(0.17, 0.12, 0.09),
}

## Item id → how it draws. `style` picks the draw routine; colours are the
## item's palette (`main`, optional `trim`).
const GEAR_VISUALS: Dictionary = {
	# Armour — replaces the shirt on the torso (and sleeves where noted).
	"leather_vest": {"style": "vest", "main": Color(0.4, 0.28, 0.17), "trim": Color(0.25, 0.17, 0.1)},
	"chainmail": {"style": "mail", "main": Color(0.52, 0.53, 0.55), "trim": Color(0.33, 0.34, 0.37)},
	"warded_cloak": {"style": "cloak", "main": Color(0.2, 0.22, 0.28), "trim": Color(0.55, 0.45, 0.26)},
	# Shoulders.
	"leather_pauldrons": {"style": "pauldron", "main": Color(0.38, 0.26, 0.16), "trim": Color(0.22, 0.15, 0.09)},
	"iron_pauldrons": {"style": "plate", "main": Color(0.5, 0.51, 0.53), "trim": Color(0.3, 0.3, 0.32)},
	"spiked_spaulders": {"style": "spiked", "main": Color(0.24, 0.23, 0.24), "trim": Color(0.62, 0.62, 0.6)},
	# Main hand.
	"rusty_dagger": {"style": "dagger", "main": Color(0.5, 0.4, 0.32), "trim": Color(0.26, 0.18, 0.11)},
	"dusk_blade": {"style": "sword", "main": Color(0.68, 0.64, 0.82), "trim": Color(0.24, 0.19, 0.28)},
	"berserker_axe": {"style": "axe", "main": Color(0.55, 0.54, 0.54), "trim": Color(0.3, 0.2, 0.12)},
	"dawn_staff": {"style": "staff", "main": Color(0.34, 0.25, 0.16), "trim": Color(0.85, 0.66, 0.3)},
	"ember_wand": {"style": "wand", "main": Color(0.26, 0.17, 0.11), "trim": Color(0.95, 0.45, 0.15)},
	"mana_crystal": {"style": "crystal", "main": Color(0.38, 0.62, 0.72), "trim": Color(0.75, 0.9, 0.95)},
	"iron_shield": {"style": "shield", "main": Color(0.45, 0.46, 0.48), "trim": Color(0.28, 0.2, 0.13)},
	# Off hand.
	"buckler": {"style": "buckler", "main": Color(0.36, 0.25, 0.15), "trim": Color(0.52, 0.52, 0.54)},
	"parrying_dagger": {"style": "dagger", "main": Color(0.62, 0.63, 0.66), "trim": Color(0.24, 0.17, 0.11)},
	"arcane_focus": {"style": "orb", "main": Color(0.5, 0.36, 0.68), "trim": Color(0.82, 0.72, 0.95)},
	# Trinkets — small accents on the belt or neck.
	"bone_charm": {"style": "necklace", "main": Color(0.8, 0.77, 0.66)},
	"ember_flask": {"style": "flask", "main": Color(0.85, 0.4, 0.15), "trim": Color(0.45, 0.46, 0.48)},
	"lucky_coin": {"style": "coin", "main": Color(0.8, 0.66, 0.28)},
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
		var v: Variant = save.get("equipped_" + slot)
		gear[slot] = "" if v == null else str(v)
	return gear


## Gear from a synced session record (Dictionary with `equipped_<slot>` keys).
static func gear_of_record(record: Dictionary) -> Dictionary:
	var gear: Dictionary = {}
	for slot: String in VISIBLE_SLOTS:
		gear[slot] = str(record.get("equipped_" + slot, ""))
	return gear


## Gear → RPC payload: one item id per `VISIBLE_SLOTS` entry, in order.
static func encode_gear(gear: Dictionary) -> Array:
	var out: Array = []
	for slot: String in VISIBLE_SLOTS:
		out.append(str(gear.get(slot, "")))
	return out


## RPC payload → gear. Untrusted input: anything that isn't a known item id
## becomes "" (nothing drawn), and extra entries are ignored.
static func decode_gear(payload: Variant) -> Dictionary:
	var gear: Dictionary = {}
	var arr: Array = payload if payload is Array else []
	for i: int in VISIBLE_SLOTS.size():
		var id: String = str(arr[i]) if i < arr.size() else ""
		gear[VISIBLE_SLOTS[i]] = id if GEAR_VISUALS.has(id) else ""
	return gear


## Every `ANIMS` animation for this look (cached).
static func build_frames(gear: Dictionary = {}, appearance: Dictionary = {}) -> SpriteFrames:
	var key: String = _look_key(gear, appearance)
	if _frames_cache.has(key):
		return _frames_cache[key] as SpriteFrames
	var sf := SpriteFrames.new()
	for anim: String in ANIMS:
		var def: Dictionary = ANIMS[anim]
		sf.add_animation(anim)
		sf.set_animation_speed(anim, float(def["fps"]))
		sf.set_animation_loop(anim, bool(def["loop"]))
		var poses: Array = def["poses"]
		for i: int in poses.size():
			sf.add_frame(anim, ImageTexture.create_from_image(render_frame(gear, appearance, anim, i)))
	if sf.has_animation("default"):
		sf.remove_animation("default")
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

## Renders frame `index` of animation `anim` (see `ANIMS`).
static func render_frame(gear: Dictionary, appearance: Dictionary, anim: String = "idle",
		index: int = 0) -> Image:
	var def: Dictionary = ANIMS.get(anim, ANIMS["idle"])
	var poses: Array = def["poses"]
	var over: Dictionary = poses[clampi(index, 0, poses.size() - 1)]
	var p: Dictionary = _REST.duplicate()
	p.merge(over, true)
	return render_pose(gear, appearance, p)


## Renders one pose (a full `_REST`-shaped Dictionary).
static func render_pose(gear: Dictionary, appearance: Dictionary, p: Dictionary) -> Image:
	var img := Image.create(FRAME_W, FRAME_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_ox = OX
	var look: Dictionary = DEFAULT_APPEARANCE.duplicate()
	look.merge(appearance, true)
	var armor: Dictionary = _visual(gear, "armor")
	var cloak: bool = str(armor.get("style", "")) == "cloak"
	var bob: int = int(p["bob"])

	var hand_l: Vector2i = p["hand_l"]
	var hand_r: Vector2i = p["hand_r"]
	var back_hand := Vector2i(3, 18 + bob) + hand_l
	var front_hand := Vector2i(11, 18 + bob) + hand_r
	if cloak:
		_draw_cloak_back(img, armor, bob)
	_draw_legs(img, look, p)
	var behind: bool = bool(p["wpn_behind"])
	if behind:
		_draw_held(img, _visual(gear, "weapon"), front_hand, look, false, float(p["wpn"]))
	_draw_torso(img, look, armor, bob)
	_draw_trinket(img, _visual(gear, "trinket"), bob)
	_draw_arm(img, look, armor, back_hand, bob, true)
	_draw_arm(img, look, armor, front_hand, bob, false)
	_draw_head(img, look, bob)
	if cloak:
		_draw_cloak_front(img, armor, bob)
	_draw_shoulders(img, _visual(gear, "shoulders"), bob)
	_draw_held(img, _visual(gear, "offhand"), back_hand, look, true, 0.0)
	if not behind:
		_draw_held(img, _visual(gear, "weapon"), front_hand, look, false, float(p["wpn"]))
	return img


static func _visual(gear: Dictionary, slot: String) -> Dictionary:
	var id: String = str(gear.get(slot, ""))
	if id == "" or not GEAR_VISUALS.has(id):
		return {}
	var v: Dictionary = GEAR_VISUALS[id]
	return v


# ── Body parts ───────────────────────────────────────────────────────────────

static func _draw_legs(img: Image, look: Dictionary, p: Dictionary) -> void:
	var trousers: Color = _col(look, "trousers")
	var boots: Color = _col(look, "boots")
	var bob: int = int(p["bob"])
	# Hips span both legs so a stride never opens a gap under the belt.
	_fill(img, 5, 18 + bob, 6, 1, trousers)
	for side: int in [0, 1]:
		var lift: int = int(p["leg_l"] if side == 0 else p["leg_r"])
		var step: int = int(p["step_l"] if side == 0 else p["step_r"])
		var x: int = (5 if side == 0 else 8) + step
		var top: int = 19 + bob
		var boot_y: int = 25 - lift
		var tone: Color = trousers if side == 1 else _shadow(trousers, 0.15)  # far leg sits in shade
		_fill(img, x, top, 3, boot_y - top, tone, 0.7)
		_rect(img, x, top, 1, boot_y - top, _shadow(tone, 0.3))       # inner shadow
		_px(img, x + 1, top + 3, _shadow(tone, 0.2))                   # knee crease
		_fill(img, x, boot_y, 3, 3, boots, 0.8)
		_px(img, x + 3, boot_y + 2, boots)                             # toe, facing right
		_rect(img, x, boot_y, 3, 1, _light(boots, 0.12))              # folded cuff
		_rect(img, x, boot_y + 2, 4, 1, _shadow(boots, 0.35))          # worn sole


static func _draw_torso(img: Image, look: Dictionary, armor: Dictionary, bob: int) -> void:
	var y: int = 10 + bob
	var shirt: Color = _col(look, "shirt")
	_fill(img, 5, y, 6, 8, shirt, 0.7)
	_rect(img, 5, y, 1, 8, _shadow(shirt))
	_rect(img, 10, y + 1, 1, 6, _light(shirt, 0.08))
	_px(img, 8, y + 1, _shadow(shirt, 0.25))                      # collar slit
	match str(armor.get("style", "")):
		"vest":
			var main: Color = _col(armor, "main")
			_fill(img, 5, y, 6, 7, main, 0.8)
			_rect(img, 5, y, 1, 7, _shadow(main))
			_rect(img, 10, y + 1, 1, 5, _light(main, 0.1))
			_rect(img, 7, y, 2, 3, _shadow(shirt, 0.1))           # open collar
			_rect(img, 7, y + 3, 1, 4, _col(armor, "trim"))       # front seam
			_px(img, 8, y + 4, _col(armor, "trim"))               # lacing
		"mail":
			var main: Color = _col(armor, "main")
			var dark: Color = _col(armor, "trim")
			for yy: int in range(y, y + 8):
				for xx: int in range(5, 11):
					var c: Color = dark if (xx + yy) % 2 == 0 else main
					if _grain(xx, yy) == 0:
						c = _shadow(c, 0.25)                      # rust / grime
					_px(img, xx, yy, c)
			_rect(img, 5, y, 1, 8, _shadow(dark))
			_rect(img, 5, y + 7, 6, 1, _shadow(dark, 0.15))       # hem
	_rect(img, 5, y + 7, 6, 1, _col(look, "belt"))
	_px(img, 8, y + 7, Color(0.55, 0.48, 0.3))                    # dull buckle
	_rect(img, 7, 9 + bob, 2, 1, _shadow(_col(look, "skin"), 0.2))  # neck


static func _draw_arm(img: Image, look: Dictionary, armor: Dictionary, hand: Vector2i, bob: int,
		back: bool) -> void:
	var sleeve: Color = _col(look, "shirt")
	var style: String = str(armor.get("style", ""))
	if style == "mail":
		sleeve = _col(armor, "main").darkened(0.05)
	elif style == "cloak":
		sleeve = _col(armor, "main")
	if back:
		sleeve = _shadow(sleeve, 0.3)
	# A 2-px-thick limb from the shoulder to just above the hand, so raised,
	# swinging and punching arms stay attached.
	var shoulder := Vector2i(3 if back else 11, 10 + bob)
	var pts: Array[Vector2i] = _line(shoulder, Vector2i(hand.x, hand.y - 1))
	for pt: Vector2i in pts:
		_fill(img, pt.x, pt.y, 2, 2, sleeve, 0.6)
	# A darker seam on the side facing the torso keeps the arm readable.
	for pt: Vector2i in pts.slice(1):
		_px(img, pt.x + (1 if back else 0), pt.y, _shadow(sleeve, 0.3))
	_rect(img, shoulder.x, shoulder.y, 2, 1, _light(sleeve, 0.08))
	if pts.size() > 2:
		_rect(img, hand.x, hand.y - 1, 2, 1, _shadow(sleeve, 0.15))  # rolled cuff
	_draw_hand(img, look, hand, back)


static func _draw_head(img: Image, look: Dictionary, bob: int) -> void:
	var skin: Color = _col(look, "skin")
	var hair: Color = _col(look, "hair")
	var y: int = 3 + bob
	var shade: Color = _shadow(skin, 0.25)
	# Face: 5 wide, 6 tall — smaller than a chibi head, so the body reads adult.
	_rect(img, 6, y, 5, 6, skin)
	_rect(img, 6, y, 1, 6, shade)                                 # cheek in shadow
	_rect(img, 7, y + 5, 4, 1, shade)                             # jaw line
	_px(img, 11, y + 3, skin)                                     # nose, facing right
	_px(img, 11, y + 4, shade)
	# Brow shadows the eye; one dark pixel reads as a squint, not a cartoon dot.
	_rect(img, 8, y + 1, 3, 1, _shadow(skin, 0.3))
	_px(img, 9, y + 2, _col(look, "eyes"))
	_px(img, 8, y + 2, _shadow(skin, 0.15))
	# Stubble: sparse dark dither along the jaw and chin.
	for xx: int in range(8, 11):
		if (xx + y) % 2 == 0:
			_px(img, xx, y + 4, skin.lerp(hair, 0.35))
	_px(img, 10, y + 5, skin.lerp(hair, 0.45))
	_px(img, 9, y + 4, _shadow(skin, 0.35))                       # set mouth
	# Hair: short, unkempt crop with a fall down the back of the head.
	_fill(img, 6, y - 2, 5, 2, hair, 0.5)
	_fill(img, 5, y - 1, 2, 5, hair, 0.5)
	_rect(img, 7, y, 3, 1, hair)
	_px(img, 10, y - 1, _shadow(hair))
	_px(img, 7, y - 2, _light(hair, 0.18))                        # dull shine
	_px(img, 5, y + 4, _shadow(hair))                             # nape
	_px(img, 7, y + 2, _shadow(skin, 0.3))                        # ear
