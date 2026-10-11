# GID-187: Balance the Real Player

## Objective

Every balance band so far (GID-176 / GID-186) measures one player: a bare hero with the starter deck, no gear, no
skills, no magic type, full HP, neutral battlefield, solo, real time. Bring the features a real player meets into the
sim — their collection, magic type, gear, skills, consumables, carried HP, fight conditions, encounter shapes, runs
and co-op — and retune against that player instead.

## Context

- User (2026-10-11): "we're looping balance without considering all the features of the game"; roadmap approved;
  **co-op in scope, PvP out**.
- **Co-op fights are always turn-based**: `BattleRealtime.eligible()` excludes networked fights. Co-op balance needs
  the turn-based sim (TID-785) first.
- Defaults chosen pending user confirmation: the "typical player" is the **average expected** build at a level
  (from drop / gear / skill-point curves), with a **modest** variant as the floor; turn-based is simulated (needed for
  co-op) and banded.
- Current harness: `BattleSetup.build(cfg)`, `BalanceFight`, `BalanceBot`, `BalanceBands`, `BalanceCoverage`
  (`docs/agent/balance-sim.md`). Game-side modifiers live in `scenes/battle/modules/BattleModifiers.gd` (equipment,
  well fed, companions, weather, ambush, gambits, desert scorch, persistent HP, school environment) — not reachable
  from the sim today.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-778 | Player profiles (typical build per level) | agent | todo | — |
| TID-779 | Progression rewards matter (gear / skills / upgrades bands) | agent | todo | TID-778 |
| TID-780 | Fight conditions shared by sim and game | agent | todo | TID-778 |
| TID-781 | Starting HP, potions and food | agent | todo | TID-778 |
| TID-782 | Encounter shapes: joiners, boss phase 2, boss ranges | agent | todo | TID-778 |
| TID-783 | Runs: rift / spire ladders and siege gauntlets | agent | todo | TID-781 |
| TID-784 | Bot variety (second policy) | agent | todo | TID-778 |
| TID-785 | Turn-based sim and bands | agent | todo | TID-778 |
| TID-786 | Co-op scaling (2-4 heroes, turn-based) | agent | todo | TID-785 |
| TID-787 | Retune against profiles | agent | todo | TID-779, TID-780, TID-781, TID-782, TID-784 |

Order: 778 → 779 → 787 (biggest effect), then 780-782, 784, then 783, 785 → 786.

## Acceptance Criteria

- [ ] Gating cells fight as a typical player of their level; the bare hero stays as a floor check
- [ ] Gear, skills and card upgrades each measurably help; none dominates
- [ ] Weather / biome / night / scorch / Attuned / blight run through one code path in the sim and the game, with
  bounded swings
- [ ] Partial-HP starts, potions, food, joiners, boss phase 2 and run ladders are banded
- [ ] Turn-based solo and 2-4-hero co-op are banded
- [ ] Every band passes after the retune; docs (`balance-sim.md`) current
