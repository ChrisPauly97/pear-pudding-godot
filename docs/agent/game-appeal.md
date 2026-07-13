# Game Appeal — Why People Play Pear Pudding TCG

> Analysis doc (GID-117 / TID-439). Unlike the feature docs in this directory, this file
> answers a product question — "why would people play this game?" — and grounds every claim
> in a shipped goal (GID) so the answer stays honest as the game evolves. It is the source
> for the positioning statement drafted in TID-442 and the audit checklist used by TID-440.

---

## 1. Thesis

Pear Pudding TCG is one of the very few games where the exploration layer and the card
layer feed each other in both directions. In most exploration-RPG × card-game hybrids the
overworld is a menu between battles; here, **the world changes your deck** (enemies are
capturable as cards, where and when you fight alters the rules, cards accrue personal
history) and **your deck changes the world** (deck composition unlocks traversal and
harvesting abilities). Wrapped around that fusion is a warm, Hobbit/Redwall-toned collector
loop and a 4-player co-op/PvP suite that is an outlier for a mobile-first indie RPG. The
one-line answer: *you play it because your deck is not a loadout — it is your character,
your key ring, and your trophy shelf at once.*

---

## 2. Player Motivations Served

| Motivation | What serves it | Evidence |
|---|---|---|
| **Collector / completionist** | Every enemy type has a signature card obtainable only by winning under a special capture condition, one-time per save (Soulbinding); bestiary completion rewards; card packs with pity counter; achievement-gated legendary cards; trophy hall in the player home | GID-061, GID-045, GID-050, GID-024, GID-046 |
| **Explorer** | Infinite 5-biome world, discoverable Ancient Colossi with generated names, treasure-map dig sites, ley lines, waystone network, dungeon secrets & mimics | GID-067, GID-043, GID-068, GID-044, GID-057 |
| **Tactician** | Hearthstone-grade battle depth: keywords (Ward/Surge/Shroud), 40 spell cards across 4 magic branches, status effects, targeting/intent, biome board rules, puzzle battles, roguelike draft mode (Endless Spire) | GID-025, GID-076, GID-019, GID-059, GID-040, GID-038 |
| **Social / competitive** | 4-player shared-world co-op with joint battles on a shared battlefield, PvP duels, draft duels, tournaments, spectator wagers, guildhall, leaderboards, trading, rally travel and dungeon rescue | GID-090–106 (esp. GID-099/100 joint battles, GID-104 competitive formats) |
| **Narrative / cozy** | The Tale of Saimtar (Chapters 1–2), Hobbit/Redwall tone, lore scrolls with journal, player home with garden & potion brewing, rideable mounts, day/night atmosphere and weather | GID-108, GID-013, GID-046, GID-056, GID-048, GID-042 |

The load-bearing observation: most competitors serve one or two of these motivations. This
game has shipped systems for all five, and its *distinctive* systems (section 4) are the
ones that serve several motivations at once — soulbinding is simultaneously a collector
chase, a tactical constraint (win *this specific way*), and an explorer reward.

---

## 3. Target Player Profiles

Primary platform is Android (spec, Goals); all profiles assume mostly-mobile play in
short-to-medium sessions.

**P1 — The Pocket Collector.** Played Pokémon and/or Marvel Snap; wants a collection that
grows every session and visible progress meters. Hooked by: soulbind hunts, bestiary,
packs/pity, veteran card ranks. Session shape: 10–20 min commutes. Risk: churns if the
first session shows only generic undead battles (see §6).

**P2 — The Deck Tinkerer.** Played Hearthstone/Slay the Spire; cares about build variety
and being rewarded for clever wins. Hooked by: capture conditions ("win without attacking
the hero with a minion"), biome board rules changing the puzzle, spell branches, the
Spire draft mode. Risk: reads "4 card types" on a store page and bounces — the pitch must
lead with 46+ templates, keywords, and spells, not the family count.

**P3 — The Couch Party.** Plays with the same 1–3 friends on LAN/VPN; wants shared
progression and things to do *together*, not just alongside. Hooked by: joint battles on a
shared square battlefield, co-op dungeon crawls, rally/rescue mechanics, guildhall,
tournaments with spectator wagers. Risk: connectivity friction (no NAT traversal — spec
Connectivity constraints) makes this profile LAN-first by design; the pitch should not
promise frictionless internet play.

---

## 4. Differentiation vs. Genre Neighbors

**vs. Hearthstone-likes (pure TCG):** they have no world — matches are queued from a menu.
Here every battle happens *somewhere*, and the somewhere matters: biome board rules and
day/night cost modifiers travel into the battle from the exact spot the encounter fired
(GID-059), night hunts boost drops (GID-055), ley-line attunement grants a battle buff
(GID-068). The TCG is comparable in depth (mana curve, 5-slot boards, keywords, spells,
status effects) but is embedded, not abstracted.

**vs. Zelda-likes (pure exploration RPG):** they have no deck — combat is reflexes. Here
combat is a collectible system with build identity, and the deck leaks back into
exploration: Ghost Phase (≥4 Ghost-family cards → phase through walls) and Skeleton Dig
(≥4 Skeleton-family cards → dig burial mounds) make deck-building a traversal decision
(GID-065). No Zelda-like gives you a reason to re-spec your combat loadout in order to
reach a place.

**vs. monster-collectors (Pokémon-likes) — the closest analog:** capturing enemies into
your battle roster is their core loop too. Three differences: (1) capture here is
*skill-gated, not RNG-gated* — each signature card requires winning under a specific
condition (spell final blow, low-HP win, win by turn N, pacifist-vs-hero win; GID-061),
so a capture is a trophy of play, not of luck; (2) captured individuals keep *earned
history* — per-instance kill/survival counters, ranks, titles, and player renaming
(GID-060), where Pokémon's equivalent (EVs) is invisible math; (3) the collection loop is
a TCG (deck construction, mana curve), not a party-of-six battler.

**vs. other mobile indie RPGs:** shipping 4-player shared-world co-op *plus* joint battles
*plus* PvP/draft/tournament/wager formats (GID-090–106) is an outlier feature set at this
scope. Co-op is host-authoritative with persistent per-player session characters resumed
on reconnect (GID-095) — closer to a tiny MMO session than to the async-only multiplayer
common in the segment.

---

## 5. The Retention Layer (Why People *Keep* Playing)

- **Between-battle life:** home ownership and trophy pedestals (GID-046), garden plots that
  grow across in-game days into potion ingredients (GID-056), mounts (GID-048), daily
  bounty board with seeded rollover (GID-051).
- **Rhythms:** day/night changes what spawns (night hunts, GID-055) and what cards cost
  (Dawn/Dusk modifiers, GID-059); weather and biome atmosphere (GID-042); living world
  events (GID-039).
- **Long arcs:** skill trees with corruption/redemption currencies (GID-030/032/086),
  bestiary and colossi completion (GID-045/067), Spire best-floor record (GID-038),
  champion ladder (GID-037), the rival Isfig arc (GID-053), Chapters 1–2 story (GID-108).
- **Loss is cheap:** defeat keeps the world alive with Retry/Respawn (GID-069), battles
  can be fled, battle speed is adjustable — the loop respects mobile session lengths.

---

## 6. Honest Weaknesses

Stated plainly so downstream work targets them rather than the pitch papering over them.

1. **The hooks are invisible in the first session.** A new player's path is menu → biome
   pick → tutorial → basic undead battle. Soulbinding only reveals itself *after* a win
   against an enemy with a signature (and is never explained in advance); cantrips require
   4 same-family cards and a gated HUD button the tutorial never mentions; resonance and
   veterancy are unlabelled until encountered. The systems that answer "why this game"
   are precisely the ones a first session doesn't show. → Audited in TID-440, fixed in
   TID-441; findings land in §7 below.
2. **No articulated positioning.** `docs/human/specification.md` describes features, never
   audience or differentiation; there is no elevator pitch in the repo. → TID-442.
3. **"4 card types" undersells the battle system.** The base families (Ghost, Skeleton,
   Zombie, Ghoul) read as thin even though the shipped reality is 46+ templates, 40 spells,
   keywords, dual-faced cards, and per-instance stats. Any public copy must lead with the
   latter numbers.
4. **Multiplayer has connectivity friction by design.** LAN/loopback by default; internet
   play needs port-forwarding/VPN; Android hosting discovery is limited (spec,
   Connectivity constraints). The co-op pitch must be framed as "play with *your* people,"
   not matchmaking.
5. **Audio/music gap.** Music hooks exist but all 7 tracks are missing files until GID-116
   lands assets; first impressions currently carry no soundtrack.
6. **Placeholder feel in places.** Visual polish shipped broadly (GID-070/089/114), but
   the pixel-art-in-3D aesthetic still varies in finish between old and new systems.

---

## 7. First-Session Hook Visibility

_To be filled by TID-440: table of hook | first visible moment | file:line | verdict
(visible / late / invisible), plus ranked recommendations for TID-441._

---

## Integrations with Other Features

This doc cites rather than owns its systems; the authoritative feature docs are
`soulbinding.md`, `card-cantrips.md`, `battle-system.md` (resonance rules),
`multiplayer-coop.md`, `meta-progression.md`, `player-home.md`, `home-garden-potions.md`,
`night-hunts.md`, `ley-lines.md`, and `skill-trees.md`. When a cited mechanic changes,
update the claim here in the same task.

## Asset Requirements

None — analysis doc only.
