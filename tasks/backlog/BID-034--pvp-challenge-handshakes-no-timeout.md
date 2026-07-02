# BID-034: PvP challenge handshakes have no timeout

**Category:** code-smell
**Discovered During:** GID-104 / TID-385

If a challenge target never answers (normal duel, wagered duel, or the new
draft duel), the challenger's pending state (`_draft_peer`, `_pending_challenge_*`)
stays set until the peer disconnects — buttons stay hidden and no new challenge
can be issued. A small timeout (e.g. 30 s) that resets the pending state and
toasts "No response" would fix all challenge flows at once.
