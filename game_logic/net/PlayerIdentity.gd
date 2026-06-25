## Pure helpers for the multiplayer player-identity handshake.
##
## Callers: preload("res://game_logic/net/PlayerIdentity.gd")
## No scene dependencies — fully unit-testable without a live connection.
## Mirrors AvatarSync.gd / BattleNetProtocol.gd: JSON-primitive payloads only.
extends RefCounted


## Pack a player's identity into a small array for RPC transmission.
## Payload layout: [token: String, name: String, color_hex: String]
## color is serialised as a 6-char RGB hex string (no alpha).
static func encode(token: String, display_name: String, color: Color) -> Array:
	return [token, display_name, color.to_html(false)]


## Unpack a received payload back into named fields. Always returns a fully
## defaulted dict; missing/garbage entries fall back to safe values so a malformed
## packet can never crash the receiver. Returns {token, name, color}.
static func decode(payload: Array) -> Dictionary:
	var token: String = str(payload[0]) if payload.size() > 0 else ""
	var display_name: String = str(payload[1]) if payload.size() > 1 else "Player"
	var color_hex: String = str(payload[2]) if payload.size() > 2 else "ffffff"
	if display_name.strip_edges() == "":
		display_name = "Player"
	var color: Color = Color.WHITE
	if Color.html_is_valid(color_hex):
		color = Color.html(color_hex)
	return {"token": token, "name": display_name, "color": color}
