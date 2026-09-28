# TID-593: First-30-Minutes Visual Finish Audit

**Goal:** GID-141
**Type:** agent
**Status:** done
**Depends On:** TID-591

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Appeal weakness #4: the pixel-art-in-3D look varies in finish between older and newer systems. Audit exactly what a new
player sees in their first 30 minutes (menu → biome pick → Madrian → outskirts → first battles → trainer/quest UI).

## Research Notes

- Capture screenshots headless/with the automation bridge used in earlier polish goals (see GID-131..134 task files for
  the capture approach, and `docs/agent/visual-polish.md`). Portrait + landscape.
- Checklist: old vs new sprite pack art (`docs/agent/art-sprites.md` manifest), missing outlines (`SpriteOutline`),
  contact shadows (`CharacterPresence`), UI not using `UiTheme`/factories (hand-styled StyleBoxFlat, hard-coded px),
  fonts (Cinzel titles), battle backdrop, name tags, placeholder textures from `TextureGen`, inconsistent icon sets.
- Output: a ranked findings table in this task file (screen, issue, file, fix size). Log leftovers as BID items.

## Plan

Capture the first-session path under xvfb (Compatibility renderer, 1280×720) with a throwaway SceneTree script:
main menu → new game at Madrian → Hilda → each starter camp → graveyard → trainer → quest panel → trainer panel.
Rank what a new player sees; fix the small ones in TID-594, log art-sized ones as backlog.

## Changes Made

Capture script (kept out of the repo): `SceneTree` that instantiates `MenuScene` / `WorldScene`, teleports the
player, ticks `starter_camps`, opens `npc_interactions` panels and saves `get_viewport().get_texture().get_image()`.
Run with `xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 -s <script>`.

### Findings (ranked)

| # | Screen | Issue | Where | Size |
|---|---|---|---|---|
| 1 | World HUD | XP bar reads "0 / 50 XP" at level 1, but level 2 needs 200 XP — every level's bar is one level behind | `WorldHUD._refresh_xp` (L543–555) uses `xp_for_level(lvl)` as the *next* threshold | S — fix |
| 2 | Madrian | Quest givers and trainers wear random role tags ("Shepherd", "Pilgrim"): Hilda the Baker, the Combat Trainer, etc. can't be found by name | `TownspersonNPC._extract_name` — only "My name is…" dialogue or a `name` key | S — fix |
| 3 | Madrian | Combat Trainer and training dummy stand on top of the south fence wall (local 78/81, 44) | `madrian.tres` (TID-537 placement) | S — fix |
| 4 | Quest panel | Fixed 62 % height leaves the lower half empty | `NpcInteractions._quest_panel` | S — fix |
| 5 | World HUD | "Ley-Attuned" pill sits under the compass objective label and overlaps it | `WorldHUD` ley indicator position | S — fix |
| 6 | Starter camps | Undead Wanderer / Horde Shambler use `enemy_undead.png`, a 16 px skull icon — the most-seen enemies of the first 30 minutes look least finished (ghouls have proper art) | `assets/textures/characters/enemy_undead*.png` | M art → BID-065 |
| 7 | Graveyard / crypt | Built from the town's tall brick wall tiles; no gravestones, reads as another wall | `madrian.tres` walls | M art/props → BID-066 |
| 8 | Main menu | Flat dark background, no key art or world behind the buttons | `MenuScene` | M → BID-067 |
| 9 | Madrian | Townsfolk share three tiny tinted townsperson sprites | `npc_townsperson*.png` | M art (covered by BID-065) |

## Documentation Updates

None (findings live here; fixes and docs in TID-594).
