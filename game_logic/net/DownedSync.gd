## Pure helpers for the co-op downed/rescue system (GID-105 / TID-389).
##
## Callers: preload("res://game_logic/net/DownedSync.gd")
## No scene dependencies — fully unit-testable. The downed flag itself rides the
## existing AvatarSync payload (see AvatarSync.encode/decode); this helper only
## covers the parts that don't belong there: the shared timeout constant and the
## race-guard predicate used by both the host-direct and submitted-request revive
## paths in WorldScene.
extends RefCounted

## Seconds a downed player waits for rescue before auto-respawning at the
## dungeon entrance (solo fallback). Self-managed per peer — no host-driven
## countdown is needed since every downed peer times out independently.
const RESCUE_TIMEOUT: float = 60.0


## Seconds remaining until auto-respawn, clamped to zero. Used to render the
## downed banner's countdown.
static func remaining_time(elapsed: float) -> float:
	return max(0.0, RESCUE_TIMEOUT - elapsed)


## A revive only applies if the target is still recorded as downed. Centralizes
## the race-guard so a stale request (the target already respawned via timeout,
## or was already revived by someone else) is silently discarded identically on
## both the host-direct call path and the RPC-submitted path.
static func can_revive(is_target_downed: bool) -> bool:
	return is_target_downed
