# BID-060: Grass, props and world items are unshaded — ignore shadows and lights

**Category:** design-inconsistency
**Discovered During:** GID-129 research

## Description

The terrain shader is lit, but the grass shaders, ChunkRenderer prop MultiMeshes, landmark stone material and WorldItem all use `unshaded` rendering. They never receive sun shadows or point light, so grass in a building's shadow is as bright as grass in the sun, and future night lights (TID-489) won't light them. DayNightCycle works around this by writing an approximate brightness global for the grass.

## Evidence

- `assets/shaders/grass_blade.gdshader:6`, `grass_cluster.gdshader:7` — `render_mode ... unshaded`
- `scenes/world/ChunkRenderer.gd:375` (props, also `disable_receive_shadows`), `:608` (landmarks)
- `scenes/world/entities/WorldItem.gd:92` comment: "All geometry in this game is unshaded so OmniLight3D has no effect."
- `scenes/world/DayNightCycle.gd:159` brightness approximation

## Suggested Resolution

Evaluate making grass lit (diffuse only, receive shadows) at Medium/High and keep unshaded on Low, measuring the mobile cost. Alternatively sample the shadow/light in a cheap way (for example a light-pool mask texture) for the unshaded shaders. Decide as part of TID-485/489.
