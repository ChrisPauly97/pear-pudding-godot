# TID-440: First-Session Hook Audit — Trace New-Game → First-Reward Code Path

**Goal:** GID-117
**Type:** agent
**Status:** done
**Depends On:** TID-439

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The appeal analysis (TID-439) claims the game's signature hooks don't surface in a new
player's first session. This task proves or disproves that claim with file/line evidence,
producing a ranked gap list that scopes TID-441. Audit only — no gameplay code changes.

## Research Notes

**Path to trace (in code, headless-verifiable where possible):**
new game (`scenes/ui/MenuScene.gd` / `MenuHubScene.gd`) → biome selection → world entry
(`autoloads/SceneManager.gd`, `scenes/world/WorldScene.gd`) → tutorial
(`game_logic/TutorialRegistry.gd` popup guides from GID-031; scripted tutorial battles from
GID-108 via `autoloads/ScriptedBattleRegistry.gd` / `game_logic/battle/ScriptedBattleData.gd`)
→ first battle (`scenes/battle/BattleScene.gd`) → first victory
(`scenes/battle/BattleResultUI.gd`, rewards in `SceneManager._on_battle_won()`).

**For each signature hook, answer: when does a brand-new player first SEE it?**
- Soulbinding — `BattleResultUI.show_soulbind()` only fires when a capture condition was
  set AND met; check which enemies carry capture conditions (`EnemyRegistry`) and whether
  any tier-1/first-session enemy does. Is soulbinding ever *explained* before it happens?
- Cantrips — Skeleton Dig needs ≥4 Skeleton-family cards; check starter deck composition
  (`scenes/ui/InventoryScene.gd` / starter deck source) to see if a fresh deck qualifies.
  Check when cantrip HUD buttons become visible (GID-081 fixed always-visible buttons —
  they're now gated, meaning a new player may never learn cantrips exist).
- Battlefield Resonance — is the resonance buff shown/labelled in the first battle?
- Veterancy — when does a card first display battle history?
- Co-op/PvP — is multiplayer discoverable from the menu without docs?
- Tutorial coverage — does `TutorialRegistry` have entries for ANY of the above, or only
  core loop mechanics? (`get_entry(popup_id)` — enumerate the registered guides.)

**Deliverables:**
1. A "First-Session Hook Visibility" section appended to `docs/agent/game-appeal.md` —
   table: hook | first visible moment | file:line | verdict (visible / late / invisible).
2. One `BID-XXX` backlog item per confirmed gap (scan `tasks/index.md` + `tasks/backlog/`
   for next free BID — note BID-018 is duplicated, so verify carefully; index them in
   `tasks/index.md` per workflow).
3. A ranked recommendation (1–3 items max) of what TID-441 should implement.

**Constraints:** read-only for game code. Backlog + doc writes only.

## Plan

1. Trace starter state (`SaveManager.new_game()`), tutorial coverage
   (`TutorialRegistry._DATA`), enemy signature assignments (`EnemyRegistry`), cantrip
   button gating (`WorldHUD._create_cantrip_buttons`), resonance banner gating
   (`BattleScene._ready`), veterancy thresholds (`VeterancyUtil`), and menu co-op entry.
2. Fill `docs/agent/game-appeal.md` §7 with the hook-visibility table + ranked
   recommendations for TID-441.
3. Log gaps as backlog items; update index. Read-only for game code.

## Changes Made

- Filled `docs/agent/game-appeal.md` §7: per-hook visibility table (soulbinding,
  Skeleton Dig, Ghost Phase, resonance, veterancy, co-op, tutorial coverage) with
  file:line evidence and verdicts, plus ranked TID-441 recommendations:
  (1) soulbinding teaser popup, (2) cantrip discovery popup; resonance and co-op need
  no action; veterancy teaching deferred.
- Key facts established: tier-1 `undead_basic` carries `sig_wanderer` (`win_by_turn` 9),
  so the soulbind status line renders on the very first free-roam victory but is never
  explained; starter deck (9 Skeleton-family / 3 Ghost-family cards) makes `[D] Dig`
  visible from world entry while Ghost Phase is hidden entirely; the scripted first
  battle suppresses the resonance banner; `TutorialRegistry` covers none of the four
  differentiator systems.
- Logged **BID-049** — `new_game()` seeds `xp = 11250`, `level = 15`, `skill_points = 14`,
  `coins = 3000` (suspected debug leak via PR #290 / GID-092 merge, progression-breaking).
- Logged **BID-050** — locked cantrips render no button, making the mechanic
  undiscoverable.
- No `.gd` changes.

## Documentation Updates

- `docs/agent/game-appeal.md` §7 (audit table + recommendations + incidental finding).
- `tasks/index.md` backlog table: added BID-049, BID-050.
