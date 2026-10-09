## What gets said when the bag fills up (GID-180 / TID-743). The active
## companion grumbles in their own voice; with none, the satchel itself does.
## Pure table + picker so tests and the HUD read the same copy.
extends RefCounted

## kind -> companion id ("" = no companion) -> lines. `%s` is the card name.
const LINES: Dictionary = {
	"full": {
		"": ["Your satchel groans at the seams.", "Not one more card fits. Visit the forge or a vendor."],
		"maiteln": ["\"Your satchel's bursting, lad. Feed the forge, or sell to a merchant.\"",
			"\"I'm not carrying those for you. Lighten that bag.\""],
	},
	"mailbox": {
		"": ["%s couldn't fit in your bag — sent to the mailbox."],
		"maiteln": ["\"No room for %s — I've had it posted to the mailbox.\"",
			"\"%s, off to the mailbox. Your bag's full again.\""],
	},
}


## The line for `kind` ("full" / "mailbox"), rotating by `n` so repeats vary.
static func line(kind: String, companion: String, n: int, card_name: String = "") -> String:
	var by: Dictionary = LINES.get(kind, {})
	var pool: Array = by.get(companion, by.get("", [])) as Array
	if pool.is_empty():
		return ""
	var text: String = str(pool[posmod(n, pool.size())])
	return text % card_name if text.contains("%s") else text


## 0 = roomy, 1 = getting full (≥ 75 %), 2 = bulging (≥ 90 %), 3 = full.
static func fullness(used: int, cap: int) -> int:
	if cap <= 0 or used >= cap:
		return 3
	var f: float = float(used) / float(cap)
	if f >= 0.9:
		return 2
	return 1 if f >= 0.75 else 0
