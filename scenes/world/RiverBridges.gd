## Stone bridges where a road crosses a river (GID-172 / TID-695). The road's tiles under the
## deck stay river water (`Rivers.road_tile`), so the river flows beneath; the deck tiles are
## not deep water (`Rivers.deep_water`), so the hero, tap-to-move and swimming treat the bridge
## as ground. Static builder: the `Coastline` world module (the waterfront and its water edges)
## adds one per `Rivers.bridges()` entry. Scenery only (every peer builds the same bridges).
extends RefCounted

const _Coastline = preload("res://scenes/world/modules/Coastline.gd")

## Deck top just above the ground the hero walks on (like the piers).
const DECK_Y: float = 0.04
const DECK_THICK: float = 0.18
const SLAB: float = 0.5  # world units per paving slab along the deck
const PARAPET_H: float = 0.55
const PARAPET_T: float = 0.28
## Pillars under the deck, this many world units apart across the water.
const PILLAR_STEP: float = 3.0
const STONE := Color(0.60, 0.58, 0.54)
const STONE_DARK := Color(0.43, 0.41, 0.38)
const STONE_CAP := Color(0.70, 0.68, 0.63)


## One bridge as a Node3D: its local +X runs along the road, +Z across it.
static func make_bridge(b: Dictionary, mat: Material, ground_y: float) -> Node3D:
	var ts: float = IsoConst.TILE_SIZE
	var c: Vector2 = b["centre"]
	var dir: Vector2 = b["dir"]
	var half_len: float = float(b["half_len"]) * ts
	var half_wid: float = float(b["half_wid"]) * ts
	var node := Node3D.new()
	node.name = "Bridge"
	node.position = Vector3(c.x * ts, ground_y, c.y * ts)
	node.rotation.y = atan2(-dir.y, dir.x)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Paving slabs across the deck, alternating shades.
	var n: int = int(2.0 * half_len / SLAB)
	for i: int in n:
		var x0: float = -half_len + float(i) * SLAB
		var col: Color = STONE if i % 2 == 0 else STONE.darkened(0.06)
		_Coastline._box(st, Vector3(x0 + 0.02, DECK_Y - DECK_THICK, -half_wid),
				Vector3(x0 + SLAB - 0.02, DECK_Y, half_wid), col)
	# Parapets along both sides, capped; open at the ends where the road runs on.
	for side: float in [-1.0, 1.0]:
		var z_in: float = side * (half_wid - PARAPET_T)
		var za: float = minf(z_in, side * half_wid)
		var zb: float = maxf(z_in, side * half_wid)
		_Coastline._box(st, Vector3(-half_len, DECK_Y, za), Vector3(half_len, DECK_Y + PARAPET_H, zb), STONE_DARK)
		_Coastline._box(st, Vector3(-half_len - 0.05, DECK_Y + PARAPET_H, za - 0.04),
				Vector3(half_len + 0.05, DECK_Y + PARAPET_H + 0.08, zb + 0.04), STONE_CAP)
	# Pillars down into the river bed.
	var x: float = -half_len + PILLAR_STEP * 0.5
	while x < half_len:
		_Coastline._box(st, Vector3(x - 0.3, -1.0, -half_wid + 0.1), Vector3(x + 0.3, DECK_Y - DECK_THICK, half_wid - 0.1),
				STONE_DARK)
		x += PILLAR_STEP
	var mi := MeshInstance3D.new()
	mi.name = "Deck"
	mi.mesh = st.commit()
	mi.material_override = mat
	node.add_child(mi)
	return node
