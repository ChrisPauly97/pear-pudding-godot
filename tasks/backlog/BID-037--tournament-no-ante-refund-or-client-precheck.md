# BID-037: Tournament abort refunds nothing; client antes are not pre-checked

**Category:** design-gap
**Discovered During:** GID-104 / TID-386

A participant disconnecting mid-bracket aborts the tournament without refunding
any antes (v1 documented gap, consistent with the no-refund wager precedent but
harsh for a 6-match bracket). Separately, the host never pre-checks a client's
ante affordability — the client deducts locally in `notify_tournament_start`
and can go briefly negative. A pre-start affordability handshake plus
abort-refund via SessionState member-record writes would close both.
