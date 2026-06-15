## Coordinate transform helpers for MapViewOverlay.
## Kept in a separate script (no inner classes) so static calls work from tests.
extends RefCounted

static func world_to_panel_coords(wx: float, wz: float,
		panel_x: float, panel_y: float, panel_size: float, tile_size: float) -> Vector2:
	var tx: float = wx / tile_size
	var tz: float = wz / tile_size
	return Vector2(panel_x + (tx / 100.0) * panel_size, panel_y + (tz / 100.0) * panel_size)

static func panel_to_world_coords(screen_x: float, screen_y: float,
		panel_x: float, panel_y: float, panel_size: float, tile_size: float) -> Vector3:
	var tx: float = (screen_x - panel_x) / panel_size * 100.0
	var tz: float = (screen_y - panel_y) / panel_size * 100.0
	return Vector3(tx * tile_size, 0.0, tz * tile_size)
