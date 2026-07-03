# GID-107: Unified HUD Actions & Party Panel — One Home for Every Feature Button

## Objective

Replace WorldScene's growing pile of individually-positioned HUD buttons with a zone-based action registry and a consolidated Party panel, so new features stay discoverable without re-cluttering the overworld screen.

## Context

GID-081 unified the four player-facing screens (Deck/Bag, Character, Skills, Journal) into a single tabbed Menu Hub and decluttered the top-level HUD down to one Pause control and one Menu/Bag entry. That consolidation held. Since then, every multiplayer/social goal (GID-090 through GID-102) added its own `Button.new()` directly to `WorldScene.gd`'s HUD CanvasLayer with a hand-picked `position = Vector2(...)`, because that was the path of least resistance for a single-task agent with no shared layout system to plug into.

The result, confirmed by direct code inspection of `scenes/world/WorldScene.gd` (39 `Button.new()` call sites) and `scenes/world/WorldHUD.gd`:

- **Overlapping buttons when co-op is active:** Leaderboard `(vw*0.012, vh*0.012)` sits on top of Pause `(vh*0.01, vh*0.01)`; Stash `(vp.x*0.012, vh*0.078)` collides with the bounty tracker `(vh*0.01, vh*0.07)`; Ghost Duels is squeezed beside Stash at the same row; Team Duel `(y=vh*0.72)` and Dungeon Crawl `(y=vh*0.72)` share the same center row; Challenge-to-Battle `(y=vh*0.80)` collides with the Android USE button `(y=vh*0.80)`; Ranked toggle `(y=vh*0.875)` collides with the Trade button `(y=vh*0.88)`.
- **No shared placement primitive:** each button computes its own `vh`/`vw`-relative position inline, so nothing prevents two features from picking the same coordinates.
- **~13 always-visible or near-always-visible buttons in co-op** (Roster panel, Loot-mode toggle, Dungeon Crawl, Challenge, Ranked toggle, Team Duel, Emote, Ping, Trade, Spectate, Leaderboard, Stash, Ghost Duels) plus Chat (toggle + input + send) — none grouped, all competing for the same few corners.

This goal introduces a HUD zone/action-registry framework (extending the pattern already proven by the GID-081 Menu Hub) so buttons are requested by zone and priority rather than pixel-positioned, consolidates the always-on co-op buttons into one discoverable Party panel, and adds a guardrail so the clutter cannot silently return.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-394 | HUD zone framework + action registry in WorldHUD | agent | done | — |
| TID-395 | Party panel: consolidate always-on co-op buttons into one entry point | agent | done | TID-394 |
| TID-396 | Contextual action bar: single slot for proximity-gated actions | agent | done | TID-394 |
| TID-397 | Social strip: consolidate Chat/Emote/Ping into one compact cluster | agent | done | TID-394 |
| TID-398 | Discoverability pass, docs/CLAUDE.md rule, and anti-clutter regression test | agent | done | TID-394, TID-395, TID-396, TID-397 |

## Acceptance Criteria

- [x] `WorldHUD.gd` exposes a zone/action-registry API (e.g. `register_action(id, label, zone, callback, visible_when)`) that owns placement; no feature computes its own raw `Vector2` HUD button position outside this API (except the pre-existing, allow-listed Siege/Draft Duel/Tournament/Auction buttons — logged as BID-042/BID-043, out of this goal's original scope)
- [x] All always-on co-op buttons (Roster, Stash, Leaderboard, Ghost Duels, Team Duel, Dungeon Crawl, Loot-mode toggle) are reachable from a single "Party" entry point instead of being individually placed on the HUD
- [x] Proximity-gated actions (Challenge/Ranked, Trade, Spectate, USE/Interact) share one contextual bar with no simultaneous overlap regardless of which combination is active
- [x] Chat, Emote, and Ping are reachable from one compact social cluster with no position collisions
- [ ] No two HUD elements occupy overlapping screen regions in any reachable combination of single-player / co-op / dungeon-crawl / PvP-pending states — **not manually verified**: this environment cannot run the Godot editor (network policy blocks the release download). Verified by code-tracing instead (every migrated button lives in an auto-stacking, overlap-proof zone Container); the one remaining known gap (Siege vs. Tournament, pre-existing/unmigrated) is logged as BID-043. Needs a real visual pass before merge.
- [x] Every consolidated action retains mobile tap parity per CLAUDE.md's Mobile/Desktop Feature Parity rule
- [x] `docs/agent/ui-and-scene-management.md` documents the zone/action-registry system, the Party panel, and the contextual action bar
- [x] A regression test (`tests/unit/test_hud_registry_guardrail.gd`) fails if a raw `Button.new()`/`_hud.add_child(...)` is added to WorldScene's HUD CanvasLayer outside the registry API or the reviewed allow-list
- [ ] All tests pass headless with zero regressions — **not run**: `godot --headless --path . -s tests/runner.gd` requires the Godot binary, which this environment could not download. Needs a CI/local run before merge.
