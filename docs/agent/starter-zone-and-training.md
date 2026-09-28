# Starter Zone & Trainer-Taught Unlocks (GID-141)

A new player learns the game one system at a time. Each level makes **one** new thing *available*; the player has to
visit that thing's trainer, read what it does and pay gold to learn it. Nothing on the ladder works until learned.

## Key Features

- One source of truth for what unlocks when: `game_logic/progression/UnlockLadder.gd`.
- Level-up only announces training (`GameBus.training_available`); learning happens at a trainer for gold.
- A fresh save knows only Strike and auto-attack.
- Existing saves are migrated whole (they keep every system they already had).

## How It Works

### The ladder (TID-587)

`UnlockLadder.LADDER` rows `{id, kind, trainer, title, how_to[, level_req, cost]}`:

| Lvl | id | Trainer | Gold |
|---|---|---|---|
| 1 | Strike + auto-attack | — (known) | — |
| 2 | `mend` | combat | 15 |
| 3 | `kick` | combat | 25 |
| 4 | `feat_minions` (hand / minion cards in battle) | combat | 40 |
| 5 | `feat_spells` (spell cards) | combat | 60 |
| 6 | `feat_companion` (Maiteln as battle companion) | maiteln | 80 |
| 7 | `feat_skills` (Skills tab + magic type) | maiteln | 100 |
| 8 | `feat_bounties` | bounty | 120 |
| 9 | `feat_night_hunts` | bounty | 140 |
| 10 | `feat_dig` (Skeleton Dig) | gravedigger | 175 |
| 11 | `guard` | combat | 60 |
| 12 | `feat_phase` (Ghost Phase) | gravedigger | 220 |
| 13 | `ember_lance` | combat | 90 |
| 14 | `mana_tap` | combat | 90 |
| 15 | `feat_spire` (Rifts, GID-142), `feat_packs` | combat, merchant | 300, 200 |
| 16 | `sweep` | combat | 120 |
| 18 | `daze` | combat | 150 |
| 40 | `feat_mount` (riding) | stable | 1000 |

- **Skill rows** (`kind: "skill"`) read `level_req` / `learn_cost` from `SkillBar.ABILITIES` — never duplicated.
  `SkillBar.ALWAYS_KNOWN` is now just `["strike"]`; `LEARNABLE_ORDER` includes Mend and Kick.
- `how_to` is the text the trainer shows (the "read it before you buy it" moment) — keep it concrete: what the
  button is, where it appears, when to use it. Soulbinding is introduced in the minion/spell rows.
- API: `def`, `has`, `level_req`, `cost`, `trainer_for`, `trainer_name`, `is_learned` (non-ladder ids are always
  on), `can_learn`, `available_at(level)`, `pending(level, learned)`, `for_trainer`, `ids_up_to`, `all_ids`.

### Save

- Learned entries live in `SaveManager.learned_abilities` (already persisted). `SaveManager.has_learned(id)` is the
  gate every system checks. `learn_ability(id, cost)` deducts coins (now emits `coins_changed`), slots a learned
  skill into a free slot of a customised bar, progresses `learn` quest objectives and emits
  `GameBus.feature_learned(id)`.
- `add_xp` emits `GameBus.training_available(ids)` with every entry unlocked by the level(s) just gained.
- `new_game()` resets `learned_abilities` and `skill_bar`; **Head Start (debug)** learns the whole ladder.
- Migration v44 (`SaveMigrations._m44_unlock_ladder`): existing saves get every ladder *feature* plus Mend/Kick;
  riding only if they own a mount; unbought trainer skills stay unlearned.
- `SkillBar.resolved_bar()` pads unknown slots with `""` (shown as "—") instead of offering unlearned skills;
  `SkillBar._init` falls back to the known part of `DEFAULT_BAR`.

### XP pacing

Curve unchanged: `xp_for_level(l) = 50·l²` (L2 50, L5 800, L10 4 500, L15 10 600, L40 78 400). Early levels come from
starter quests (TID-592) plus level-1 kills at 20 XP; zone levels (TID-536) scale kill XP up by 10 %/level, so the
same curve stretches naturally toward the long-term level-40 riding goal.

## Integrations

- Combat gates (TID-588), world/menu gates (TID-589), trainer flow (TID-590), starter zone (TID-591), quest chain
  (TID-592) — see their sections as they land.
- Rifts (GID-142) are `feat_spire`.

## Asset Requirements

None beyond existing NPC sprites.
