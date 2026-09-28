# TID-589: World & Menu Gates Follow the Ladder

**Goal:** GID-141
**Type:** agent
**Status:** pending
**Depends On:** TID-587

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

World and menu entry points are all visible from the first minute. Hide each until its ladder entry is learned.

## Research Notes

- Cantrips: `scenes/world/WorldHUD.gd` L150–160 sets `_ghost_btn.visible = true` / `_dig_btn.visible = true`
  unconditionally; `CantripManager.is_available(cantrip_id, template_ids)` checks deck family counts. Gate becomes
  learned (`feat_dig` L10 / `feat_phase` L12) AND family count. Key bindings G/D in `scenes/world/modules/Cantrips.gd`.
- Mount: `WorldHUD` L134 `_mount_btn`, visibility L590; `scenes/world/modules/Mounts.gd` (stable purchase panel,
  price from `MountRegistry`). Level 40 via `feat_mount`; stable purchase panel explains the level/training requirement.
- Menu hub: `scenes/ui/MenuHubScene.gd` `_TABS` = deck, character, skills, loadout, journal. Hide "skills" until
  `feat_skills`; "loadout" (skill bar) until at least one learnable skill beyond Strike is learned (Mend, L2); deck
  editing ok from start (but hand only matters at L4 — consider showing a "Unlocks at level 4" note).
- Bounty board: `bounty_board` npc_type in `scenes/world/modules/NpcInteractions.gd` → refuse with "come back at level 8"
  line before learned. Night hunts: `scenes/world/modules/NocturnalSpawner.gd` — no spectre spawns before `feat_night_hunts`.
- Spire + packs: find entry points (`grep -rn "spire" scenes/world scenes/ui`, `PackDefs.gd`, merchant pack purchase) —
  gate on `feat_spire` / `feat_packs` (L15).
- Keyboard + touch parity: every gated key (G, D, mount key) must also no-op with a short "Not learned yet" toast.
- Co-op: joiners with their own session characters use their own ladder; host's world features (night hunts) — decide
  host-authoritative (host's ladder) and note it.
- Tests: `test_hud_registry_guardrail` must still pass (use `register_action` / visibility, no bare add_child);
  add a gating unit test on the pure predicates; world_scene_smoke.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
