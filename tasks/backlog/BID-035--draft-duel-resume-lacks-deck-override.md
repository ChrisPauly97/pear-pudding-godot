# BID-035: PvP reconnect resume rebuilds the host deck from the collection, breaking draft-duel resume

**Category:** logic-gap
**Discovered During:** GID-104 / TID-385

`SceneManager.resume_pvp_battle` (TID-372 grace-window reconnect) does not carry
the new `local_deck_override` used by draft duels, so a resumed **host** rebuilds
players[0] from its persistent collection instead of the transient drafted deck
(client-side resume is unaffected — clients never build decks). Threading the
override through `NetworkManager.set_pvp_resume` would close the gap.
