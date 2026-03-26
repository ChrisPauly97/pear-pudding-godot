// Billboard grass cluster shader.
// Each MultiMesh instance is a flat quad that rotates around Y to face the
// camera (billboard_fixed_y).  The fragment shader draws five tapered blade
// silhouettes across the UV space so a single quad looks like a small tuft of
// grass.  This gives cheap apparent density without individual blade geometry.
shader_type spatial;
render_mode cull_disabled, alpha_to_coverage, unshaded;

uniform vec4  color_base : source_color = vec4(0.22, 0.32, 0.12, 1.0);
uniform vec4  color_mid  : source_color = vec4(0.36, 0.52, 0.18, 1.0);
uniform vec4  color_tip  : source_color = vec4(0.46, 0.64, 0.24, 1.0);
uniform float wind_strength  : hint_range(0.0, 1.0) = 0.28;
uniform vec2  wind_direction                         = vec2(1.0, 0.35);

void vertex() {
	// Y-axis billboard: rotate the quad around world Y to face the camera,
	// keeping it upright (no look_at tilt). Extract camera XZ direction from
	// the inverse view matrix, flatten to Y=0, then rebuild the local axes.
	vec3 cam_world = (inverse(VIEW_MATRIX) * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 world_pos = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 to_cam = cam_world - world_pos;
	to_cam.y = 0.0;
	float len = length(to_cam);
	if (len > 0.001) {
		to_cam /= len;
	} else {
		to_cam = vec3(0.0, 0.0, 1.0);
	}
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), to_cam));
	vec3 up    = vec3(0.0, 1.0, 0.0);
	// Rebuild vertex position in billboard space, keeping instance scale/offset
	vec3 local = VERTEX;
	VERTEX = right * local.x + up * local.y;

	// Sway the top of the quad in the billboard-right direction.
	// UV.y is 0 at the root, 1 at the tip.
	float bend  = UV.y * UV.y;
	float sway  = sin(TIME * 1.4) * 0.65 + sin(TIME * 0.38) * 0.35;
	float drift = sin(TIME * 0.07) * 0.35;
	float cd = cos(drift);
	float sd = sin(drift);
	vec2 wdir = normalize(vec2(
		wind_direction.x * cd - wind_direction.y * sd,
		wind_direction.x * sd + wind_direction.y * cd));
	VERTEX += right * wdir.x * wind_strength * sway * bend * 0.35;
}

// Returns 1.0 inside a tapered blade shape, 0.0 outside.
// cx     = horizontal centre in UV space
// half_w = half-width at the base
// h      = blade height as a fraction of the quad height (0..1)
float blade(vec2 uv, float cx, float half_w, float h) {
	float taper = half_w * max(0.0, 1.0 - uv.y / h);
	return step(abs(uv.x - cx), taper) * step(uv.y, h);
}

void fragment() {
	// Five blades at varied positions and heights for a natural tuft silhouette.
	float a = 0.0;
	a = max(a, blade(UV, 0.10, 0.055, 0.80));
	a = max(a, blade(UV, 0.28, 0.068, 0.95));
	a = max(a, blade(UV, 0.50, 0.075, 1.00));
	a = max(a, blade(UV, 0.72, 0.065, 0.90));
	a = max(a, blade(UV, 0.90, 0.050, 0.76));

	// Smooth tip fade matching grass_blade.gdshader
	a *= 1.0 - smoothstep(0.78, 1.0, UV.y);

	// Three flat color bands — pixel art style, no gradient blending
	vec3 col;
	if (UV.y < 0.33) {
		col = color_base.rgb;
	} else if (UV.y < 0.66) {
		col = color_mid.rgb;
	} else {
		col = color_tip.rgb;
	}

	ALBEDO = col;
	ALPHA  = a * step(UV.y, 0.92);
	// Low threshold keeps material in the opaque pass so clusters depth-test
	// correctly against the player and terrain.
	ALPHA_SCISSOR_THRESHOLD = 0.01;
}
