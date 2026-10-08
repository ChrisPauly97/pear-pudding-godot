# TID-710: Retire SkillBar dependents + docs

**Goal:** GID-175
**Type:** agent
**Status:** done
**Depends On:** TID-708, TID-709

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Remove the last references to the fixed bar and update the docs.

## Research Notes

- References (grep `SkillBar|skill_bar`): `scenes/ui/SkillBarScene.gd` (loadout picker, delete), `scenes/ui/MenuHubScene.gd` (entry), `MentorBarks.gd` / `BarkRules.gd` (Kick/Strike barks → hand cards), `CombatOnboarding.gd` / `BattleOnboarding.gd` (first-time tips), `FightStats.gd` (post-fight coaching), tests `test_skill_bar`, `test_combat_onboarding`, `test_combat_momentum`, `test_unlock_ladder`.
- Delete `game_logic/battle/SkillBar.gd` once nothing preloads it (or reduce it to a data table read by the cards).
- Docs: combat-model.md, ui-and-scene-management.md (SkillBarScene), enemies-and-npcs.md (trainer), starter-zone-and-training.md, the CLAUDE.md BattleRealtime row (mentions `BattleSkillBar.gd` / `SkillBar.gd`).
- Full suite: no `SCRIPT ERROR` in the log.

## Plan

Low complexity, so I proceeded without an approval stop.
1. Delete the bar files.
2. Drop the Menu Hub tab and the L key, and point the trainer button at the Deck tab.
3. Drop the `skill_bar` save field, `set_skill_bar` and the `skill_cooldown` knob.
4. Repoint tests at TechniqueDefs.
5. Fix stale comments and tip wording.
6. Update docs + CLAUDE.md.

## Changes Made

- Deleted: `game_logic/battle/SkillBar.gd`, `scenes/battle/modules/BattleSkillBar.gd`, `scenes/ui/SkillBarScene.gd` + `.tscn`, `tests/unit/test_skill_bar.gd` (with `.uid`s). Their behaviour is covered by `test_technique_cards`, `test_technique_learning` and `realtime_battle_smoke`.
- `scenes/ui/MenuHubScene.gd`: no "loadout" tab / L key. `tests/menu_hub_smoke.gd` tab list updated.
- `scenes/world/modules/NpcInteractions.gd`: the combat trainer's "Skill Bar" button is now "Deck" (opens the Deck tab) once more than Strike is known.
- `autoloads/SaveManager.gd`: `skill_bar` var + PERSISTED_FIELDS entry + `set_skill_bar()` removed; comments updated. v46 still erases the key from old saves.
- `game_logic/battle/CombatTuning.gd`: `skill_cooldown` knob removed. A saved override for it is harmless: `CombatTuning.apply` ignores unknown keys.
- Tests: `test_combat_momentum` (combo via `on_player_hit` builder hits), `test_combat_onboarding`, `test_unlock_ladder` now use TechniqueDefs.
- Comments/text: FightStats (post-fight tips mention cards), BarkRules, CombatOnboarding, MentorBarks, TechniqueDefs, realtime_battle_smoke (`_check_techniques`).
- Validation: full suite PASS with 0 SCRIPT ERROR; all 12 CI smoke tests clean; gdlint (whole repo) and unsafe-hits clean.

## Documentation Updates

combat-model.md (old bar sections replaced by a short "retired" note; Momentum, onboarding table, barks and FightStats wording), ui-and-scene-management.md (Menu Hub tabs, SkillBarScene removed), enemies-and-npcs.md (trainer panel), starter-zone-and-training.md, story-implementation.md, battle-system.md (keys), home-garden-potions.md (keys), CLAUDE.md BattleRealtime row.
