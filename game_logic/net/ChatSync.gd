## Pure encode/decode helpers for co-op party chat (TID-374).
## Scene-free, unit-testable — mirrors SocialSync.gd.
## Payload arrays are JSON-primitive so they route through Godot's RPC serializer.
extends RefCounted

## Fixed quick-chat preset list. Order fixed for wire compatibility (mirrors
## SocialSync.EMOTE_IDS — six entries, one-tap mobile-friendly).
const QUICK_PRESETS: Array[String] = [
	"On my way", "Need help", "Nice!", "Wait", "Let's battle", "Trade?"
]

## Message kinds.
const KIND_QUICK: String = "quick"
const KIND_TEXT: String = "text"

## Free-text length cap (characters). Enforced in the pure helper so the
## authority and every client compute the identical sanitized result.
const MAX_TEXT_LEN: int = 120

## Chat log retention cap used by the HUD panel (lines kept/visible).
const LOG_MAX_LINES: int = 40


## Strip ASCII control characters (0x00-0x1F, 0x7F) and cap to MAX_TEXT_LEN.
## Applied to both quick-chat presets and free text so a forged/garbled
## payload can never bypass the cap on the receiving end either.
static func _sanitize(raw: String) -> String:
	var out: String = ""
	for i: int in range(raw.length()):
		var code: int = raw.unicode_at(i)
		if code < 0x20 or code == 0x7F:
			continue
		out += raw[i]
		if out.length() >= MAX_TEXT_LEN:
			break
	return out


# ---------------------------------------------------------------------------
# Chat wire format: [text: String, kind: String, map: String]
# ---------------------------------------------------------------------------

## Encode a quick-chat preset. Falls back to the first preset if preset_text
## isn't a recognized preset (still sanitized either way).
static func encode_quick(preset_text: String, map_name: String = "") -> Array:
	var text: String = preset_text
	if not QUICK_PRESETS.has(text):
		text = QUICK_PRESETS[0] if QUICK_PRESETS.size() > 0 else text
	return [_sanitize(text), KIND_QUICK, map_name]


## Encode a free-text chat message. Sanitizes internally (length cap + control
## char stripping) so callers never need to pre-sanitize.
static func encode_text(raw_text: String, map_name: String = "") -> Array:
	return [_sanitize(raw_text), KIND_TEXT, map_name]


## Decode a chat payload. Always returns a fully-defaulted dict and never
## throws, even on garbage input. Re-sanitizes the text defensively so a
## malicious/garbled payload can't smuggle control chars or exceed the cap.
static func decode(payload: Variant) -> Dictionary:
	if not payload is Array:
		return {"text": "", "kind": KIND_TEXT, "map": ""}
	var arr: Array = payload as Array
	var text: String = _sanitize(str(arr[0])) if arr.size() > 0 else ""
	var kind: String = str(arr[1]) if arr.size() > 1 else KIND_TEXT
	if kind != KIND_QUICK and kind != KIND_TEXT:
		kind = KIND_TEXT
	var map_name: String = str(arr[2]) if arr.size() > 2 else ""
	return {
		"text": text,
		"kind": kind,
		"map":  map_name,
	}
