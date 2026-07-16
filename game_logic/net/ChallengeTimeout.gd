## Pure timeout-expiry check for PvP challenge handshakes — duel, wagered duel,
## draft duel, and the dedicated-server relay (GID-115 / TID-431, fixes BID-034).
## Scene-free, unit-testable — mirrors RatingMath/CardInstanceUtil in style.
##
## An unanswered challenge previously left the holder's pending-state variable
## (e.g. WorldScene._pending_challenge_from, _draft_peer) set forever: buttons
## stayed hidden and no new challenge could be issued until the peer
## disconnected (or, for the dedicated-server relay, never — a stuck relay
## blocks every future challenge on the whole server). Callers arm a `*_at`
## timestamp (Time.get_ticks_msec()) when the pending state is set, clear it
## back to -1 wherever the pending state is otherwise cleared, and poll
## has_expired() once per frame to reset+notify on expiry.
extends RefCounted

## How long a challenge/wager/draft-duel handshake can sit unanswered before it
## expires and resets the pending state on whichever side is still holding it.
const TIMEOUT_MSEC: int = 30000

## True once `now_msec` is at least TIMEOUT_MSEC past `armed_at_msec`.
## armed_at_msec == -1 means "nothing pending" — never expires.
static func has_expired(armed_at_msec: int, now_msec: int) -> bool:
	return armed_at_msec != -1 and now_msec - armed_at_msec >= TIMEOUT_MSEC
