# GID-068: Ley Lines — Visible Currents of Magic

## Objective

Glowing mana streams snake deterministically across the terrain; walking them grants a speed boost, entering battle on one grants an "Attuned" +1 starting mana crystal, and line intersections spawn rare Mana Wells.

## Context

The overworld and the card game share a magic fiction but no mechanical bridge: mana exists only inside battles. Ley lines make magic a visible, positional feature of the world — players can route along a line for speed, choose to engage enemies while standing on one for a turn-one mana edge, and detour to intersections for Mana Well pickups. Everything derives from one pure deterministic intensity function, so rendering, movement, and battle effects all agree. This complements (and does not duplicate) GID-059 Battlefield Resonance, which modifies battles by biome/time — ley lines are about *where you stand*, not where you are biome-wise.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-247 | Ley Line Field Math — Deterministic Position → Intensity Function | agent | done | — |
| TID-248 | Ley Line Rendering — Terrain Shader Overlay + Minimap Hint | agent | done | TID-247 |
| TID-249 | Ley Gameplay — Speed Boost, Attuned Battle Buff, Mana Wells | agent | done | TID-247 |

## Acceptance Criteria

- [ ] Ley intensity is a pure deterministic function of (world position, world_seed); same seed → same lines.
- [ ] Ley lines glow visibly on terrain (emissive band, slow pulse) and hint on the minimap.
- [ ] Player move speed is boosted (~1.15×) while standing on a ley line.
- [ ] Engaging an enemy while on a ley line grants the player +1 mana crystal on turn 1 ("Attuned"), with a HUD indicator while eligible.
- [ ] Mana Wells spawn deterministically at line intersections; pickup grants a reward once and persists as collected.
- [ ] All tests pass headless.
