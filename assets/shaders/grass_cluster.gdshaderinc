// Shared body of grass_cluster.gdshader (unshaded) and grass_cluster_lit.gdshader (GID-131 / TID-508).

uniform vec4  color_base       : source_color = vec4(0.18, 0.38, 0.13, 1.0);
uniform vec4  color_mid        : source_color = vec4(0.32, 0.58, 0.19, 1.0);
uniform vec4  color_tip        : source_color = vec4(0.56, 0.80, 0.30, 1.0);
instance uniform vec4 grass_recolor = vec4(1.0, 1.0, 1.0, 0.0);
uniform float wind_strength  : hint_range(0.0, 1.0) = 0.28;
uniform vec2  wind_direction                         = vec2(1.0, 0.35);
// Weather wind (TID-486): see grass_blade.gdshader.
global uniform float grass_wind_scale;
global uniform float grass_wind_lean;

// Sun+ambient approximation so unshaded clusters still follow day/night.
global uniform vec3 grass_day_tint;
#include "res://assets/shaders/contact_shadow.gdshaderinc"
#include "res://assets/shaders/terrain_puddles.gdshaderinc"
// Blade root in world space, for contact shadows (GID-131 / TID-503).
varying vec3 v_root_world;

void vertex() {
	v_root_world = MODEL_MATRIX[3].xyz;
	// Blades rooted in standing water sink into it (TID-515).
	float in_puddle = puddle_mask(v_root_world.xz, puddle_dip(v_root_world.xz), 1.0);
	VERTEX.y *= 1.0 - smoothstep(0.3, 0.8, in_puddle);
	// Y-axis billboard: rotate the quad around world Y to face the camera,
	// keeping it upright (no look_at tilt). Extract camera XZ direction from
	// the inverse view matrix, flatten to Y=0, then rebuild the local axes.
	// INV_VIEW_MATRIX is engine-provided — never call inverse() per vertex.
	vec3 cam_world = INV_VIEW_MATRIX[3].xyz;
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
	VERTEX += right * wdir.x * (wind_strength * grass_wind_scale * sway + grass_wind_lean) * bend * 0.35;
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

	// Smooth base→mid→tip gradient (GID-131 / TID-506; was three hard bands
	// with an olive base that read as dark spikes on the bright ground), plus
	// per-blade brightness/hue jitter from the root position so a field is not
	// one flat colour.
	vec3 col = mix(color_base.rgb, color_mid.rgb, smoothstep(0.0, 0.45, UV.y));
	col = mix(col, color_tip.rgb, smoothstep(0.4, 0.95, UV.y));
	// Per-biome recolour (GID-134): straw in the desert, burnt stubble when scorched.
	col = mix(col, grass_recolor.rgb * mix(0.55, 1.1, UV.y), grass_recolor.a);
	float jitter = fract(sin(dot(v_root_world.xz, vec2(12.9898, 78.233))) * 43758.5453);
	col *= mix(0.9, 1.1, jitter);
	col = mix(col, col * vec3(1.1, 1.04, 0.8), step(0.8, jitter) * 0.5);
#ifdef GRASS_LIT
	// Lit variant (GID-131 / TID-508, High): the engine lights the blade like
	// the ground under it (normal forced up), so it receives sun shadows and
	// real light instead of the grass_day_tint approximation.
	// ×1.3 matches the unshaded path's grass_day_tint peak (1.25) against the
	// brighter terrain texture; the small emission floor mirrors terrain's.
	ALBEDO = col * 1.3 * mix(contact_shadow(v_root_world), 1.0, UV.y * 0.6) * cloud_shadow(v_root_world.xz);
	EMISSION = ALBEDO * 0.08;
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
#else
	ALBEDO = col * grass_day_tint * mix(contact_shadow(v_root_world), 1.0, UV.y * 0.6) * cloud_shadow(v_root_world.xz);
#endif
	ALPHA  = a * step(UV.y, 0.92);
	// Low threshold keeps material in the opaque pass so clusters depth-test
	// correctly against the player and terrain.
	ALPHA_SCISSOR_THRESHOLD = 0.01;
}
