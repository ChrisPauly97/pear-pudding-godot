## Pure rules for Maiteln's real-time coaching barks (GID-135 / TID-558).
##
## No Node, no timers, no UI — `MentorBarks.gd` (scenes/battle/modules) drives a
## clock and calls these statics every frame. Kept pure so the rate-limit and
## line-selection logic is unit-testable without a live battle.
extends RefCounted

## Seconds a fight must run before barks start — the very first swing shouldn't
## already be narrated.
const START_DELAY_S: float = 1.5
## Minimum seconds between any two barks.
const MIN_INTERVAL_S: float = 8.0
## A single line fires at most this many times per fight.
const MAX_PER_LINE: int = 2

## Bark ids, in the priority order `candidates_for` (in `MentorBarks`) emits
## them (most urgent first). Text lives here so tests and the module read the
## exact same copy. Each maps to a real moment: `interrupt` fires only on a
## successful `Kick` card (`RealtimeTechniques.resolve_reactive`); `ally_ready`
## on `RealtimeCombat`'s own "ally_ready" event; `cooldown_ready` when a technique
## card comes back into the hand (GID-175).
const LINES: Dictionary = {
	"low_hp": "Your health is dropping — Mend, or a potion, before it's too late!",
	"mana_empty": "Out of mana — lean on your weapon until it regens.",
	"cast_bar": "Watch its cast bar — Kick it!",
	"interrupt": "Nicely done!",
	"cooldown_ready": "A technique's back in your hand — put it to work.",
	"ally_ready": "Your ally is ready — send it in!",
}

## Levels up to which Maiteln still coaches (GID-141: he joins as a companion
## at level 6, after the combat unlocks, so the coaching window is by level).
const COACH_MAX_LEVEL: int = 12

## Only Maiteln as Mentor (learned as companion), and only while the player is
## still new (level ≤ COACH_MAX_LEVEL).
static func is_eligible(active_companion: String, player_level: int) -> bool:
	return active_companion == "maiteln" and player_level <= COACH_MAX_LEVEL

## True once `elapsed` has cleared the startup grace period and the last bark
## (if any, `last_bark_at` < 0 means none yet) is far enough behind.
static func can_bark_now(elapsed: float, last_bark_at: float) -> bool:
	if elapsed < START_DELAY_S:
		return false
	if last_bark_at < 0.0:
		return true
	return elapsed - last_bark_at >= MIN_INTERVAL_S

## Picks the first candidate (in caller-given priority order) that hasn't hit
## its per-fight cap yet, or "" if every candidate is spent or the list is
## empty. `seen_counts` maps bark id -> times already shown this fight.
static func pick_line(candidates: Array[String], seen_counts: Dictionary) -> String:
	for id: String in candidates:
		if int(seen_counts.get(id, 0)) < MAX_PER_LINE:
			return id
	return ""

## Full decision for one frame: "" when rate-limited, exhausted, or nothing
## qualifies; otherwise the bark id to show. `candidates` is already ordered
## by priority (most urgent moment first).
static func next_bark(candidates: Array[String], elapsed: float, last_bark_at: float,
		seen_counts: Dictionary) -> String:
	if candidates.is_empty() or not can_bark_now(elapsed, last_bark_at):
		return ""
	return pick_line(candidates, seen_counts)

## Text for a bark id, or "" if unknown (caller should skip rather than show a blank bubble).
static func text_for(id: String) -> String:
	return str(LINES.get(id, ""))
