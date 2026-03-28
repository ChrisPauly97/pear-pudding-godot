# BID-001: Tutorial / Onboarding for New Players

**Category:** spec-gap
**Discovered During:** ad-hoc review (GID-006 gap analysis)

## Description

The game has no onboarding. A new player spawns directly in the procedural world with no guidance on:
- WASD / joystick movement
- How to engage enemies (walk into them)
- The `E` key to interact with NPCs and chests
- The `I` key to open the inventory / deck builder
- What the TCG battle system is or how to play cards

The story Introduction (Saimtar escaping Madrian with Maiteln) provides a natural onboarding moment but it is not yet interactive — the player just loads into the world with no context.

## Evidence

- `docs/agent/ui-and-scene-management.md` — no tutorial scene listed
- `autoloads/SceneManager.gd` — no tutorial state in the scene state machine
- Spec open questions do not mention tutorial, but new player friction is high without one

## Suggested Resolution

Options (for human to decide):
1. **Dialogue-driven tutorial:** Maiteln's opening dialogue in `madrian` teaches controls one at a time (move here → interact with this → open inventory)
2. **Contextual HUD tips:** Small fade-in labels ("Press E to interact", "Press I for inventory") triggered by proximity to the first NPC/chest
3. **Splash tutorial screen:** A simple scene before the first world load showing control reminders

Option 2 is lowest scope and fits well with the existing HUD fade patterns in WorldScene.
