# TID-417: Assign Personas Per Enemy Type/Boss/Rival + Doc Update

**Goal:** GID-112
**Type:** agent
**Status:** done
**Depends On:** TID-416

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

TID-415/416 build the `basic`/`aggro`/`control` personas into `BasicAI`. This
task assigns an `ai_persona` field to every enemy entry in `EnemyRegistry` (and
any special-cased enemy dict built elsewhere, e.g. duelists, rivals) so the new
logic actually varies fight-to-fight, and documents the assignment.

## Research Notes

- All enemy entries live in `autoloads/EnemyRegistry.gd`, `_ensure_loaded()`
  dictionary literal (~lines 30-300+). Each entry already carries
  `difficulty_tier` (1-4) and `lore_text` — use both to pick a persona that
  matches the enemy's flavor and doesn't spike difficulty unfairly for a tier-1
  fight:
  - `undead_basic` (tier 1, "slow but relentless... shambling") → `"basic"` —
    stays the tutorial-predictable enemy the intent banner fully explains
    (per GID-112's acceptance criteria, tier-1 keeps exact banner wording too).
  - `undead_horde` (tier 2, "pack hunters press forward in relentless waves") →
    `"aggro"` — matches the lore (numbers over cunning, races to hero damage).
  - `ghoul_pack` (tier 3) → `"aggro"`.
  - `undead_elite` (tier 4, "retains fragments of its battle tactics... brutal
    efficiency") → `"control"` — the lore explicitly says this one fights
    smarter, which is exactly what `"control"` represents.
  - `roaming_terror` (roaming boss) → `"control"` — a boss should punish
    careless play, not just race face damage.
  - `duelist_novice` → `"basic"`, `duelist_adept` → `"aggro"`,
    `duelist_champion` → `"control"` (mirrors the escalating-skill narrative
    already present in the champion-gate design, see
    `docs/agent/enemies-and-npcs.md` "Duelist NPC" section).
  - `martarquas_raider_1/2/3` → `"aggro"` (raiders); `martarquas_warleader` →
    `"control"` (named boss).
  - `rival_isfig_1/2/3` → `"control"` (the Rival is meant to feel like a
    scripted nemesis, per `docs/agent/story-implementation.md` — confirm this
    doesn't conflict with any rival-specific scripted behavior before assigning).
  - `mimic` → `"basic"` (a surprise-reveal enemy, not meant to also be tactically
    tricky — confirm no special mimic battle logic already overrides its deck/AI
    before changing anything, grep `mimic` across `game_logic/` and
    `scenes/battle/`).
- Add the field as `"ai_persona": "<value>"` alongside each entry's existing
  `"difficulty_tier"` key so `BasicAI` (via the `enemy_data` dict threaded in
  TID-415) can read it the same way `EnemyNPC.engage()` already reads
  `is_boss`/`boss_hp`/`phase2_deck` (`scenes/world/entities/EnemyNPC.gd:49-54`).
  Confirm whether a new `EnemyRegistry.get_ai_persona(type_id)` accessor
  (mirroring `get_is_boss`/`get_difficulty_tier`, lines 309/344) is cleaner than
  inline dict access at each of the few call sites — prefer the accessor for
  consistency with the rest of the file.
- Doc updates required:
  - `docs/agent/battle-system.md` — add an "AI Personas" subsection near the
    existing "BasicAI Logic" section (~line 166-174) describing the three
    personas and the shared lethal check.
  - `docs/agent/enemies-and-npcs.md` — add an "AI Persona" column to the "Enemy
    Types" table (~lines 21-26) and to the "Duelist" table (~lines 158-165).

## Plan

_Written during Plan phase._

## Changes Made

Assigned `ai_persona` across all 20 `EnemyRegistry` entries, roughly by fantasy:

- `aggro` — undead_horde, ghoul_pack, duelist_adept, all three martarquas
  raiders, spectre_phantom.
- `control` — undead_elite, duelist_champion, roaming_terror,
  martarquas_warleader, all three Isfig rival stages, spectre_wraith,
  blight_heart.
- `basic` — undead_basic, duelist_novice, spectre_wisp, mimic (tier-1 and
  gimmick fights keep the readable, teachable AI).

`docs/agent/battle-system.md` rewritten around the AI: the BasicAI Logic section
now documents personas, the lethal check and its two constraints (Ward outranks
lethal; armor counts), and banner tier scaling. Also corrected two stale claims
elsewhere in that doc — the Turn Sequence bullet still described the old
"greedy, lowest cost first" AI, and the Ward section still described
`decide_turn`/`describe_turn` each collecting `ward_targets` separately.
