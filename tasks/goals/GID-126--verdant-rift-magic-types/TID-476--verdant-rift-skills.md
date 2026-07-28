# TID-476: Bloom / Thorn / Flux / Fracture Skill Resources

Goal: [GID-126](goal.md) · Type: agent · Status: done

## Problem

The four new branches have no skills, so their tabs would render empty.

## Plan

24 `SkillData` resources (6 per branch), matching the shape every existing branch
uses: two three-deep prerequisite chains at `tree_col` 0 and 3, `tree_row` 0–2,
with the row-2 entry of the first chain being the cross-purchasable active.

## Changes Made

- **`data/skills/bloom_*.tres`** (6) — Verdant sustain/ramp:
  Seedling (+8 HP) → Deep Roots (+15 HP) → **Overgrowth** (heal 10, cross★);
  First Shoots (+1 mana) → Sunward Reach (+1 draw) → Bountiful Harvest (+4 mana).
- **`data/skills/thorn_*.tres`** (6) — Verdant retribution:
  Barbed Growth (+1 atk) → Bramble Wall (+12 HP) → **Thornburst** (AoE 2, cross★);
  Wild Sap (+1 mana) → Rampant Vines (+2 atk) → Second Bloom (heal 6).
- **`data/skills/flux_*.tres`** (6) — Rift tempo:
  Leyward Focus (+1 mana) → Phase Shift (+1 draw) → **Reweave** (draw 3, cross★);
  Unstable Form (+8 HP) → Kinetic Charge (+2 atk) → Mana Surge (+4 mana).
- **`data/skills/fracture_*.tres`** (6) — Rift unmaking:
  Hairline Crack (+1 atk) → Splintering (+2 atk) → **Shatterwave** (AoE 3, cross★);
  Hollow Core (+8 HP) → Fault Line (+1 mana) → Scavenged Shards (draw 2).

  ★ = `alt_cost = 2`, one per branch (Ember and Ash also have one; Dawn and Dusk
  are the outliers with two).

- Each `.tres` has its `.uid` sidecar, per CLAUDE.md.
- **`autoloads/SkillRegistry.gd`** — 24 new `const … := preload(...)` lines and
  24 new entries in the `_ensure_loaded()` list. The explicit preload chain is
  what gets these files into the Android APK; `DirAccess` scanning would not.
- **`data/SkillData.gd`** — the `magic_branch` doc comment now lists all eight
  branches.

## Balance Note

Effect magnitudes were copied from the Light/Dark equivalents at the same tree
position rather than invented, so the new trees are power-neutral against the
existing ones. No new `effect_type` values were introduced — `BattleScene`
already applies all four passive and all four active types generically by
`effect_type`, so these skills work with zero battle-system changes.

## Documentation Updates

`docs/agent/skill-trees.md` (TID-479).
