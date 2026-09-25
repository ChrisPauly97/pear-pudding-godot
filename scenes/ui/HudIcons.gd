extends RefCounted
## HUD action icons (GID-132 / TID-510), keyed by `WorldHUD.register_action`
## id. Art: game-icons.net (Lorc, Delapouite & contributors), CC BY 3.0 —
## see assets/icons/hud/LICENSE-game-icons.txt and CREDITS.md. White SVGs
## imported at 128 px with mipmaps; the theme's font colours tint them.

const _ICONS: Dictionary = {
	"interact": preload("res://assets/icons/hud/interact.svg"),
	"party": preload("res://assets/icons/hud/party.svg"),
	"emote": preload("res://assets/icons/hud/emote.svg"),
	"chat": preload("res://assets/icons/hud/chat.svg"),
	"trade": preload("res://assets/icons/hud/trade.svg"),
	"spectate": preload("res://assets/icons/hud/spectate.svg"),
	"challenge": preload("res://assets/icons/hud/challenge.svg"),
	"wager_challenge": preload("res://assets/icons/hud/wager_challenge.svg"),
	"draft_duel": preload("res://assets/icons/hud/draft_duel.svg"),
	"pause": preload("res://assets/icons/hud/pause.svg"),
	"menu_hub": preload("res://assets/icons/hud/menu_hub.svg"),
	"mount": preload("res://assets/icons/hud/mount.svg"),
	"cantrip_ghost_phase": preload("res://assets/icons/hud/cantrip_ghost_phase.svg"),
	"cantrip_skeleton_dig": preload("res://assets/icons/hud/cantrip_skeleton_dig.svg"),
}
## Actions whose label was a stand-in glyph ("II", ":)") show the icon alone.
const ICON_ONLY: Array[String] = ["pause", "emote"]


static func icon_for(id: String) -> Texture2D:
	return _ICONS.get(id) as Texture2D


static func has_icon(id: String) -> bool:
	return _ICONS.has(id)


static func ids() -> Array:
	return _ICONS.keys()


## Puts the icon for `id` on `btn`, sized to `icon_px` (0 = leave as is).
static func apply(btn: Button, id: String, icon_px: int) -> void:
	var tex: Texture2D = icon_for(id)
	if tex == null:
		return
	btn.icon = tex
	btn.expand_icon = false
	if icon_px > 0:
		btn.add_theme_constant_override("icon_max_width", icon_px)
	if id in ICON_ONLY:
		btn.text = ""
		btn.tooltip_text = id.capitalize()
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
