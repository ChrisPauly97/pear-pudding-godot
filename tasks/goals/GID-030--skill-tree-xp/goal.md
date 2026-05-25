# GID-030: Skill Tree & XP System

## Objective

Add an XP/levelling system rewarding battle wins, a skill tree of passive and active skills unlocked by spending skill points, and an HUD XP bar so the player can see their progress at all times.

## Context

The spec open question "what are rewards for winning battles beyond card drops?" was partially answered with coins (GID-007). XP closes the loop: it provides a long-term progression curve and makes every battle meaningful even when no card or equipment drops. The skill tree gives earned skill points a spend path and lets the player customise their battle style (passive stat boosts or active hero powers). The active hero power is a once-per-battle ability in BattleScene, similar to Hearthstone's hero powers.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-110 | XP & leveling — `xp`, `level`, `skill_points` in SaveManager (v12 migration), XP on battle win, `level_up` GameBus signal, level-up toast | agent | done | — |
| TID-111 | SkillData resource + SkillRegistry autoload + 10 skill `.tres` files with `.uid` sidecars | agent | pending | TID-110 |
| TID-112 | Passive skill application — `unlocked_skills` in SaveManager, BattleScene applies unlocked passives at battle start | agent | pending | TID-111 |
| TID-113 | Active hero power in BattleScene — once-per-battle button, 4 active effect types | agent | pending | TID-111 |
| TID-114 | Skill Tree Scene UI — node grid overlay, tap-to-unlock with prerequisite enforcement, S key + HUD button, SceneManager routing | agent | pending | TID-112, TID-113 |
| TID-115 | HUD XP bar — level number + XP progress bar in world HUD, updates on `level_up` signal, mobile-safe sizing | agent | pending | TID-110 |

## Acceptance Criteria

- [ ] SaveManager tracks `xp`, `level`, and `skill_points`; save v12 migration backfills 0 defaults for old saves
- [ ] Winning a battle awards XP; amount scales with enemy difficulty
- [ ] `level_up` signal fires on `GameBus` when threshold is crossed; a toast notification announces the new level
- [ ] At least 10 skills exist across passive and active types with `.uid` sidecars
- [ ] Unlocked passive skills are applied to `PlayerState` at battle start (alongside weapon effects)
- [ ] An active hero power button appears in BattleScene when an active skill is equipped; usable once per battle
- [ ] Skill Tree Scene opens via S key and HUD button; skill nodes show locked/unlocked state and prerequisites
- [ ] Spending a skill point on a node unlocks it and decrements `skill_points` in SaveManager
- [ ] An XP bar and level number are visible in the world HUD at all times
- [ ] XP bar updates immediately on `level_up` signal without requiring a scene reload
