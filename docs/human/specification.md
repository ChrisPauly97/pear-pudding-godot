# Project Specification — Pear Pudding TCG

> **This file is human-owned.** Write freely. No format is enforced.
> Claude will read this to derive designs, tasks, and architecture — but will never edit it.

---

## Overview

Pear Pudding TCG is a 3D isometric open-world RPG built in Godot 4 where the player explores a procedurally generated world, encounters enemies, and resolves combat through a collectible card game (TCG) battle system. The game features a hand-crafted story mode (The Tale of Saimtar) layered on top of the infinite sandbox world.

---

## Positioning

*(Drafted by GID-117 / TID-442; inserted with explicit user permission, 2026-07-13.)*

**Elevator pitch:** Pear Pudding TCG is an open-world isometric RPG where every fight is a card battle, every enemy can be soulbound into your deck, and the deck you build changes how you explore the world — solo or with up to three friends.

**Positioning:** For mobile players who love collecting and deck-building but find pure card games worldless and pure RPGs deckless, Pear Pudding TCG fuses the two layers in both directions: enemies are skill-gated captures, biomes and time of day rewrite battle rules, cards earn ranks and titles from their own history, and deck composition unlocks exploration abilities. Unlike Hearthstone-likes, it has a living world. Unlike monster-collectors, a capture is a trophy of skill, not luck. And unlike nearly anything at this scope, it ships 4-player shared-world co-op with joint battles, PvP, drafts, and tournaments.

---

## Identity

*(Added 2026-10-08 with explicit user permission, GID-175 / TID-711.)*

**The card is the atomic unit of the game.** Pear Pudding borrows WoW's world, pacing and real-time feel, but everything the player owns, learns or grows is a card in the deck — not a fixed ability, not a stat bar.

- **Abilities are cards.** Combat techniques live in the deck and are drawn into the hand; there is no fixed action bar.
- **Progression grants cards.** Trainers, loot, quests and level-ups give cards or upgrade cards; unlocks expand what a deck can do (size, draw, mulligan), never bypass it.
- **Captures are the hook.** Every enemy is designed partly as the card it becomes when soulbound.
- **The deck shapes exploration.** Deck composition unlocks world abilities (Dig, Phase, …) — the role gear plays in WoW.
- **Cards are always visible.** Rewards, loot and combat show card faces, not ability icons.

**Feature filter:** before adding a system, ask *"Does this make the deck matter more, or less?"* If less, reframe it as a card mechanic or cut it.

---

## Goals

- A complete, shippable game on Android (primary platform) and desktop
- Seamless world exploration with streaming infinite terrain across 5 distinct biomes
- A satisfying TCG battle loop: collect cards, build a deck, fight increasingly tough enemies
- A narrative story mode (Chapters 1+) woven through named hand-crafted maps
- Clean pixel-art isometric aesthetic with procedural grass, hills, and ruins

---

## Key Features

### World & Exploration
- Infinite procedural world divided into 16×16 tile chunks, streamed around the player
- Five biomes: Grasslands, Forest, Desert, Scorched, Mountains — each with distinct terrain shape, enemy pool, and visual tint
- Simplex noise tile generation (GRASS / HILL / WALL) with per-biome frequency and thresholds
- Procedural ruins (~33% of chunks) with crumbled walls and door openings leading to dungeons
- Day/night cycle with time-of-day shader tinting
- Isometric camera fixed at classic 1:1:1 axonometric ratio (−35.264° elevation, −45° azimuth)
- WASD movement mapped to isometric world directions; virtual joystick on mobile

### Card Battle System
*(Rewritten 2026-10-10 with explicit user permission; detail in `docs/agent/combat-model.md`.)*
- **Real-time by default** (WoW-style): each side acts on its own clock. Player GCD 1.5 s, spells have cast
  bars, enemies cast on their own GCD with an interruptible cast bar. Settings > Battle Mode offers Turn-based,
  Real-time and Real-time (slow). Puzzles, scripted story battles, PvP, co-op, team duels and resumed saves stay turn-based
- **Hero & Allies:** the player is the hero; creature cards are **Allies** (max 5 per deck, 3 on the board) that
  auto-attack the focused target. Enemies field up to 2 **Minions**. A **Mentor** (e.g. Maiteln) is an equipped passive helper
- **Hero HP persists** between fights: slow out-of-combat regen, food and potions, full heal in towns and beds
- **Mana:** fixed pool per fight that grows with level (400 + 35/level, cap 1000 points; a 1-cost card = 100), regen 20/s
- **Hand & draw:** draw 1 card every 6 s while the hand is under 7; heroes auto-attack with their weapon (main + off hand)
- **Technique cards** replace the old skill bar: Strike, Mend, Kick, Guard, Ember Lance, Mana Tap, Sweep, Daze.
  Max 3 per deck, start in the opening hand and return after a per-card cooldown. Learned from trainers
- **Momentum:** hits build combo pips that empower the next card
- **Card roster:** ~160 cards — minions/Allies, spells, legendaries and techniques across four magic types
  (light, dark, verdant, rift) with eight branches. The skill tree modifies cards rather than granting flat stats
- **Captures:** defeated enemies can be soulbound into the deck as cards
- **Deck:** 5–30 cards, built at the Deck Table; cards earn ranks and titles from their history
- Enemy strength comes from the zone's level (hero HP, card tier), never from the player's level

### Damage Schools & Horizontal Progression
*(Added 2026-10-10 with explicit user permission, GID-181 / TID-758.)*
- Every hit has a school: physical, light, dark, verdant or rift (a card's magic type; cards without one are physical)
- Enemies resist (×0.5) or are weak (×1.5) to schools, themed by biome and lore (e.g. bog creatures resist verdant, undead are weak to light); immunities only on boss phases; no enemy resists every school
- Enemy attacks carry a school; the player gains school power and resistance from the skill tree and from gear school affixes, which sit on top of item-level stat rolls
- Weather, battlefield and time of day boost schools; the bestiary reveals an enemy's school profile once encountered/defeated
- Progression is horizontal: breadth of schools, cards and matchup loadouts matters more than raw stats. No scaling of the player or enemies to each other's level

### Levels & XP
*(Added 2026-10-10 with explicit user permission.)*
- XP from kills and quests; **level cap 60** (`XpCurve.MAX_LEVEL`), zone levels 1–60 (`ZoneLevels`)
- Each level is paced in minutes of play (10 min at L1, +5 min per level); enemies well below your level give no XP
- Levels raise max mana, grant skill points, and gate trainer unlocks (`UnlockLadder`)

### Named Maps & Story Mode
- Text-file map format (`.txt`) with tile grid and entity directives (SPAWN, NPC, ENEMY, CHEST, DOOR)
- Hand-crafted maps: madrian, maykalene, farsyth_mansion, blancogov, blancogov_temple
- Story: The Tale of Saimtar — an 11-year-old orphan on an adventure with old wizard Maiteln to warn King Eldar of the rising Martarquas tribe
- Story flags in SaveManager gate NPC dialogue and progression
- Procedural dungeons generated from a seed when entering dungeon doors

### Save System
- Single JSON save at `user://save.json`
- Dirty-flag batched writes (max 2s delay)
- Field migration so old saves always load correctly
- Tracks: deck, owned cards, position, map stack, defeated enemies, opened chests, time of day, world seed, biome

### UI & Menus
- Scene stack managed by SceneManager (world → battle overlay → inventory → menus)
- Main menu, biome selection (new game), inventory/deck builder, game over screen
- Map editor for authoring named maps in-engine

### Multiplayer (Co-op & PvP)
- Shared-world **co-op for up to 4 players** on a named map (madrian) — each player
  has a display name, avatar color, and a stable identity token
- **PvP card duels** between co-op players, reusing the battle engine (host-authoritative)
- **LAN discovery** (find nearby games) plus **join by IP** as a fallback
- Planned: a **dedicated server** option and **session-scoped persistent characters**
  (deck/inventory/level follow a player across reconnects, keyed by identity token)
- **Connectivity constraints:** LAN/loopback by default; over-the-internet play needs
  port-forwarding / a public-IP host / a home dedicated server / VPN overlay (no
  built-in NAT traversal). Android can join and be discovered as a client; Android
  *hosting* discovery is limited (multicast lock not yet implemented) — use join-by-IP.

---

## Architecture & Technical Constraints

- **Engine:** Godot 4.6 (GDScript, strict mode)
- **Primary export:** Android (APK via GitHub Actions CI)
- **Rendering:** 3D isometric with pixel-art sprites; no geometry shaders (Godot 4 does not support them)
- **Terrain:** CPU-built `ArrayMesh` via `TerrainMath.gd`; grass via fragment FBM shader on flat planes
- **Signals:** All cross-system communication via `GameBus` autoload (no direct node references between systems)
- **Constants:** All tile types, sizes, and ranges in `IsoConst` autoload — no duplicates elsewhere
- **Resources:** All `.gdshader`, `.tres`, `.material` files need `.uid` sidecars for Android export
- **Tests:** GUT-based tests run headless via `godot --headless --path . -s tests/runner.gd`

### Autoloads (singletons)
| Autoload | Role |
|---|---|
| `IsoConst` | Tile sizes, camera angles, gameplay ranges |
| `GameBus` | Signal hub decoupling all systems |
| `SceneManager` | Scene routing and map stack |
| `SaveManager` | JSON persistence |
| `CardRegistry` | Card template database |
| `EnemyRegistry` | Enemy deck database |

### Directory Layout
```
autoloads/          — singleton scripts
game_logic/         — pure GDScript (no rendering): battle/, world/, TerrainMath.gd
scenes/             — rendering + interaction: world/, battle/, ui/
assets/             — shaders/, textures/, maps/
data/               — cards/*.tres, enemies/*.tres
tests/              — GUT test scripts
docs/human/         — human-owned specs and workflow (never edited by agent)
docs/agent/         — agent-owned design docs (kept current after each feature)
tasks/              — goal and task tracking (agent-managed)
```

---

## Out of Scope (for now)

- Ranked matchmaking, global server browser, and NAT-punch relay/matchmaking service
- Voice acting (voiced character dialogue — lip-sync, real-time conversation VO)
- Complex branching dialogue trees (single NPC line per state for now)
- Mac / iOS export (Android + desktop only)

---

## Open Questions

- What are the rewards for winning battles beyond card drops? (XP, coins, story flags?)
- Should defeated enemies respawn after a real-time interval, or stay dead per save?
- How many chapters are planned? Is Chapter 2 in scope for the first public release?
- Should the deck builder enforce a minimum / maximum deck size?

---

## Open Questions — Resolved

The following questions from the initial spec have been answered by completed goals:

- **Battle rewards beyond card drops:** Coins awarded via `coin_reward` in EnemyData (GID-007). ~~No XP system planned.~~ **Amended 2026-10-10:** XP and levels shipped (GID-030, GID-177); see Levels & XP.
- **Enemy respawn:** Defeated enemies stay dead per save via `SaveManager.defeated_enemies` (GID-009). No time-based respawn.
- **Deck size constraints:** Minimum 5, maximum 30 cards enforced in deck builder (GID-003).
- **Chapter count:** Chapter 1 is the target for v1 release. ~~Chapter 2 is out of scope.~~
  **Amended 2026-07-02 (GID-108, user-approved):** Chapter 2 ("The Road to Larik",
  see `docs/human/story.md`) is now in scope. Chapter 1 remains the v1 release gate;
  Chapter 2 ships when ready.
- **Voice acting / audio scope:** ~~Voice acting or music~~ was fully out of scope.
  **Amended 2026-07-08 (GID-116, user-approved):** Background music is now in scope —
  sourced from open-source/CC-licensed tracks; see `docs/agent/audio-soundtrack.md`
  and `assets/audio/music/CREDITS.md` for licensing. Lore scroll narration audio
  (background ambient storytelling, not real-time character voice) has also been in
  scope since GID-013. Voiced character dialogue (lip-sync, real-time conversation
  VO) remains out of scope.
- **Multiplayer / online features:** ~~Multiplayer / online features~~ was fully out
  of scope. **Amended (GID-094, see BID-022):** LAN co-op (up to 4 players sharing
  the madrian map) and LAN PvP card battles are now in scope; see the Multiplayer
  section above and `docs/agent/multiplayer-coop.md`. Online/internet multiplayer
  beyond LAN (NAT traversal, matchmaking, Steam transport), reconnection into an
  in-progress PvP battle, and PvP wagers/ranked ladder remain out of scope.

---

## Chapter 1 Victory Condition

*(Resolved 2026-07-02 via GID-108, user-approved — full detail in `docs/human/story.md`.)*

- **Trigger event:** King Eldar dialogue in blancogov_temple after `chapter1_temple_council`
  is set and the Queen and Scargroth have each been spoken to
- **Story flag set:** `chapter1_complete`
- **Ending presentation:** three-page narration overlay (reuses the scroll narration UI)
- **Post-ending flow:** return to the world as a playable epilogue (war-preparation dialogue
  via flag-gated lines); Chapter 2 begins from this state

---

## Planned Enemy Types

> **TODO for TID-068:** Define 6 new enemy types (aiming for ~2 per biome).
> Full detail belongs in `docs/human/story.md` under "New Enemy Types".
> Confirm the list below or replace with your own designs.
>
> Suggested types:
> - **Wraith** — Grasslands, fast low-HP minion deck
> - **Forest Shade** — Forest, evasive deck with draw effects
> - **Sand Stalker** — Desert, aggressive rush deck
> - **Scorched Revenant** — Scorched, burn/damage-all deck
> - **Mountain Troll** — Mountains, high-HP slow deck
> - **Stone Golem** — Mountains, boss-tier tank (used as mini-boss)

---

## References & Inspirations

- **TCG mechanics:** Hearthstone (mana curve, board zones, hero HP)
- **World exploration:** early Zelda games (top-down exploration feel in 3D)
- **Aesthetic:** classic RPG pixel art scaled into 3D isometric view
- **Story tone:** The Hobbit / Redwall — a young protagonist in a grounded fantasy world
