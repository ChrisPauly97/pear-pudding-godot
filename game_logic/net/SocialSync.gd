## Pure encode/decode helpers for co-op emotes and map pings (TID-365).
## Scene-free, unit-testable — mirrors AvatarSync.gd.
## Payload arrays are JSON-primitive so they route through Godot's RPC serializer.
extends RefCounted

## Preset emote identifiers. Order fixed for wire compatibility.
const EMOTE_IDS: Array[String] = [
	"greet", "thanks", "help", "attack", "retreat", "laugh"
]

## Display text for each emote shown in the bubble above the avatar.
const EMOTE_LABELS: Dictionary = {
	"greet":   "Hi!",
	"thanks":  "Thanks!",
	"help":    "Help!",
	"attack":  "Attack!",
	"retreat": "Retreat!",
	"laugh":   "Haha!",
}

## Ping kinds.
const PING_PLACE: String = "place"
const PING_ENEMY: String = "enemy"

## Bubble display duration in seconds before auto-hide.
const EMOTE_DURATION: float = 3.0

## Ping marker display duration in seconds.
const PING_DURATION: float = 5.0


# ---------------------------------------------------------------------------
# Emote wire format: [emote_id: String, map: String]
# ---------------------------------------------------------------------------

## Encode an emote for RPC transmission. map_name is the sender's current map so
## receivers can apply the same-map filter used by avatar packets.
static func encode_emote(emote_id: String, map_name: String = "") -> Array:
	return [emote_id, map_name]


## Decode an emote payload. Always returns a fully-defaulted dict.
static func decode_emote(payload: Variant) -> Dictionary:
	if not payload is Array:
		return {"emote_id": "", "map": ""}
	var arr: Array = payload as Array
	return {
		"emote_id": str(arr[0]) if arr.size() > 0 else "",
		"map":      str(arr[1]) if arr.size() > 1 else "",
	}


# ---------------------------------------------------------------------------
# Ping wire format: [x: float, z: float, kind: String, color_hex: String, map: String]
# ---------------------------------------------------------------------------

## Encode a world-space ping.
static func encode_ping(x: float, z: float, kind: String, color_hex: String, map_name: String = "") -> Array:
	return [x, z, kind, color_hex, map_name]


## Decode a ping payload. Always returns a fully-defaulted dict.
static func decode_ping(payload: Variant) -> Dictionary:
	if not payload is Array:
		return {"x": 0.0, "z": 0.0, "kind": PING_PLACE, "color_hex": "ffffff", "map": ""}
	var arr: Array = payload as Array
	return {
		"x":         float(arr[0]) if arr.size() > 0 else 0.0,
		"z":         float(arr[1]) if arr.size() > 1 else 0.0,
		"kind":      str(arr[2])   if arr.size() > 2 else PING_PLACE,
		"color_hex": str(arr[3])   if arr.size() > 3 else "ffffff",
		"map":       str(arr[4])   if arr.size() > 4 else "",
	}
