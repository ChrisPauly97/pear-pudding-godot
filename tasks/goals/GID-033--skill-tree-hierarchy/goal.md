# GID-033: Skill Tree Hierarchy Visualization

## Objective

Replace the flat skill grid with a top-down tree layout where connector lines visually link each prerequisite skill to its dependent, making the unlock hierarchy immediately obvious.

## Context

The current `SkillTreeScene` renders each branch as a `GridContainer` with skill nodes at `(tree_row, tree_col)` positions. Prerequisite enforcement already exists in code (`_prerequisites_met()`), but the flat grid gives no visual cue that row-0 skills must be taken before row-1 skills, or row-1 before row-2. Users have requested an explicit top-down tree look with branch connectors.

Each branch has two parallel chains using columns 0 and 3:
- Left chain (col 0):  root (r0) → mid (r1) → capstone (r2)
- Right chain (col 3): root (r0) → mid (r1) → capstone (r2)

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-128 | Tree layout with connector lines | agent | done | — |

## Acceptance Criteria

- [ ] Each home-branch tab shows skills in a top-down layout with row 0 at the top
- [ ] Vertical connector bars appear between each prerequisite-linked pair of nodes
- [ ] Connector bars for an unlocked parent are bright (branch color); locked parent bars are dimmed
- [ ] Nodes whose prerequisites are not met remain visually greyed out
- [ ] Cross-magic tab is unchanged (flat list, no connectors needed)
- [ ] Layout works on mobile viewport sizes without horizontal overflow
