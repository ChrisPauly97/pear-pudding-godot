## PlaytestMetrics — is the slice fun? (GID-188 / TID-799)
##
## Pure rules over one save-backed Dictionary (`SaveManager.playtest`):
##   play_s   — seconds played (ticked while a game is running, not on the menu)
##   sessions — times a save was started or continued
##   first    — event → play_s when it first happened
##   count    — event → how many times
##   last     — {event, at} of the latest event (the quit point)
## The summary answers the slice's questions: how long to the first fight and
## the first capture, how often the deck is touched, where people stop.
## No autoloads, so tests drive it directly.
extends RefCounted

const FIGHT: String = "fight"
const WIN: String = "win"
const LOSS: String = "loss"
const CAPTURE: String = "capture"
const DECK_EDIT: String = "deck_edit"
const LEVEL: String = "level"
const LEARN: String = "learn"
const QUEST: String = "quest"
const SLICE_COMPLETE: String = "slice_complete"
const SESSION: String = "session"

## Summary rows: [label, event] for "time to first …" lines, in play order.
const FIRSTS: Array = [
	["First fight", FIGHT], ["First win", WIN], ["First capture", CAPTURE], ["First deck edit", DECK_EDIT],
	["First quest done", QUEST], ["Demo complete", SLICE_COMPLETE],
]
## Summary rows: [label, event] for counters.
const COUNTS: Array = [
	["Fights", FIGHT], ["Wins", WIN], ["Defeats", LOSS], ["Captures", CAPTURE], ["Deck edits", DECK_EDIT],
	["Level-ups", LEVEL], ["Things learned", LEARN], ["Quests done", QUEST],
]

## Records `event` at the current play time.
static func note(m: Dictionary, event: String) -> void:
	var t: float = float(m.get("play_s", 0.0))
	var first: Dictionary = m.get("first", {})
	if not first.has(event):
		first[event] = t
	m["first"] = first
	var count: Dictionary = m.get("count", {})
	count[event] = int(count.get(event, 0)) + 1
	m["count"] = count
	if event != SESSION:
		m["last"] = {"event": event, "at": t}
	else:
		m["sessions"] = int(m.get("sessions", 0)) + 1

## Adds `seconds` of play.
static func tick(m: Dictionary, seconds: float) -> void:
	m["play_s"] = float(m.get("play_s", 0.0)) + maxf(0.0, seconds)

static func first_at(m: Dictionary, event: String) -> float:
	var first: Dictionary = m.get("first", {})
	return float(first.get(event, -1.0))

static func count_of(m: Dictionary, event: String) -> int:
	var count: Dictionary = m.get("count", {})
	return int(count.get(event, 0))

## "12m 05s", or "—" for a negative (never happened).
static func clock(seconds: float) -> String:
	if seconds < 0.0:
		return "—"
	var s: int = int(seconds)
	if s >= 3600:
		return "%dh %02dm" % [s / 3600, (s % 3600) / 60]
	return "%dm %02ds" % [s / 60, s % 60]

## Human-readable report, one line per row (Diagnostics + clipboard export).
static func summary(m: Dictionary) -> Array[String]:
	var out: Array[String] = []
	out.append("Played: %s over %d session(s)" % [clock(float(m.get("play_s", 0.0))), int(m.get("sessions", 0))])
	for row: Array in FIRSTS:
		out.append("%s at: %s" % [str(row[0]), clock(first_at(m, str(row[1])))])
	for row: Array in COUNTS:
		out.append("%s: %d" % [str(row[0]), count_of(m, str(row[1]))])
	var last: Dictionary = m.get("last", {})
	if not last.is_empty():
		out.append("Last thing done: %s at %s" % [str(last.get("event", "")), clock(float(last.get("at", 0.0)))])
	return out
