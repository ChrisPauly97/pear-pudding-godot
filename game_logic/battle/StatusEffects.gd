## Status-effect rules shared by minions (CardInstance) and heroes (HeroState),
## which both keep their statuses in a `status_effects` id → value Dictionary.
extends RefCounted

## Harmful statuses a cleanse removes (armor is a buff and stays).
const AILMENTS: Array[String] = ["poison", "freeze", "stun"]

## Soaks `dmg` into an "armor" status (removing it once spent) and returns the
## damage that gets through.
static func absorb_armor(status_effects: Dictionary, dmg: int) -> int:
	if not status_effects.has("armor"):
		return dmg
	var av: int = int(status_effects["armor"])
	var absorbed: int = mini(av, dmg)
	var remaining: int = av - absorbed
	if remaining <= 0:
		status_effects.erase("armor")
	else:
		status_effects["armor"] = remaining
	return dmg - absorbed


## Removes every ailment in `AILMENTS`; returns how many were cleared.
static func clear_ailments(status_effects: Dictionary) -> int:
	var n: int = 0
	for id: String in AILMENTS:
		if status_effects.erase(id):
			n += 1
	return n
