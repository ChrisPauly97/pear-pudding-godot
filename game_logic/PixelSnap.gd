extends RefCounted
## Pixel-grid snapping for the orthographic iso camera (GID-131 / TID-504).
##
## Nearest-filtered pixel art at a non-integer screen scale shimmers when the
## camera glides by sub-pixel amounts. Snapping the camera (and the player's
## sprites) to whole screen pixels in the camera plane keeps every texel on
## the same screen columns frame to frame. Depth along the view axis is left
## alone — it never moves anything on screen.


## World units covered by one screen pixel. Camera3D.size is the FULL view
## height for KEEP_HEIGHT orthographic cameras (the old WorldScene code used
## size × 2 and snapped to 2-pixel steps).
static func pixel_world_size(cam_size: float, viewport_height: float) -> float:
	return cam_size / maxf(viewport_height, 1.0)


## `pos` rounded to the pixel grid on the camera's right/up axes.
static func snap(pos: Vector3, cam_basis: Basis, pixel: float) -> Vector3:
	if pixel <= 0.0:
		return pos
	var right: Vector3 = cam_basis.x.normalized()
	var up: Vector3 = cam_basis.y.normalized()
	var fwd: Vector3 = cam_basis.z.normalized()
	var r: float = roundf(pos.dot(right) / pixel) * pixel
	var u: float = roundf(pos.dot(up) / pixel) * pixel
	return right * r + up * u + fwd * pos.dot(fwd)
