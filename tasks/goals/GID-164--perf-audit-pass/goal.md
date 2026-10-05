# GID-164: Perf Audit Pass — Mobile Rendering, Chunk Water, Per-Frame Modules, Battle UI, Save

## Objective

Implement every finding of the 2026-10-05 three-agent performance audit and measure the result.

## Context

User asked for perf improvements; three read-only audits covered world/chunk streaming, per-frame world logic,
and battle/UI/save/rendering. Builds on GID-160 (per-frame perf), GID-162 (measured pass), GID-163 (worker chunk gen).
Android is a target, so mobile render cost and per-frame GDScript work weigh most.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| [TID-672](TID-672--mobile-medium-tier.md) | Medium tier: one AA, deband off, cheaper sun rays | agent | done | — |
| [TID-673](TID-673--water-math-early-out.md) | WaterMath: early-out dry vertices, bucket dry points, bounded reserved distance | agent | done | — |
| [TID-674](TID-674--water-probe-cache.md) | Cache per-chunk dry points for water probes | agent | done | TID-673 |
| [TID-675](TID-675--packed-grid-lookups.md) | Direct packed-grid indexing in mesh/prop builders; per-town plan lookup | agent | done | TID-673 |
| [TID-676](TID-676--presence-townlife-cache.md) | CharacterPresence + TownLife cached records; WalkCycle manager; faces_left error | agent | done | — |
| [TID-677](TID-677--minimap-lights-hp.md) | Minimap redraw throttle; NightLights flicker in shader; HeroHealth on change | agent | done | — |
| [TID-678](TID-678--per-frame-minor.md) | Minor per-frame fixes: EnemyNPC meta, GrassBlades uploads, co-op enemy sync, downed banner | agent | done | — |
| [TID-679](TID-679--rt-battle-hud.md) | Realtime battle HUD: value-only updates, cached styleboxes, reused status labels | agent | done | — |
| [TID-680](TID-680--card-refresh-cache.md) | Card refresh: cached face templates, badge signature diff | agent | done | TID-679 |
| [TID-681](TID-681--backdrop-bake.md) | Bake static battle backdrop once | agent | done | — |
| [TID-682](TID-682--town-building-batching.md) | Town buildings: shared materials, merged trim, off-main-thread build | agent | done | — |
| [TID-683](TID-683--save-flush-cost.md) | Save flush: section-dirty copies, compact JSON, flat HMAC, .bak once per session | agent | pending | — |
| [TID-684](TID-684--deck-builder-incremental.md) | Deck builder: debounced search, persistent tiles, incremental add/remove | agent | pending | — |
| [TID-685](TID-685--measure-and-docs.md) | Profile before/after, docs + CLAUDE.md | agent | pending | TID-672..TID-684 |

## Acceptance Criteria

- [x] Medium tier drops redundant AA/deband; sun rays cheaper.
- [ ] Town chunk `prepare_terrain` measurably faster; chunk output proven identical by equivalence tests.
- [ ] Per-frame module costs (CharacterPresence, TownLife, WalkCycle, Minimap, NightLights, HeroHealth) reduced in profiler.
- [ ] Realtime battle HUD/card refresh no longer allocates styleboxes/labels/template dicts per frame/swing.
- [ ] Save flush cheaper; legacy save envelopes still load.
- [ ] Deck builder no longer full-rebuilds per keystroke.
- [ ] Tests, smoke tests, gdlint, `unsafe-hits.sh`, headless import clean; docs updated.
