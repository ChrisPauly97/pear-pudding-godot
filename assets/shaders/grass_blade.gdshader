shader_type spatial;
render_mode cull_disabled, alpha_to_coverage;

// --- Color palette ---
// Tuned to blend with the terrain's flat-grass procedural base (~0.44, 0.62, 0.25).
uniform vec4  color_base       : source_color = vec4(0.22, 0.32, 0.12, 1.0);
uniform vec4  color_mid        : source_color = vec4(0.36, 0.52, 0.18, 1.0);
uniform vec4  color_tip        : source_color = vec4(0.46, 0.64, 0.24, 1.0);

// --- Wind ---
uniform float wind_strength    : hint_range(0.0, 1.0) = 0.28;
uniform vec2  wind_direction                          = vec2(1.0, 0.35);

// Player position for immediate blade push (only applied while moving).
// Global so any system can update them once and all chunks see the new value.
global uniform vec3  player_pos;
global uniform vec2  player_move_dir;
uniform float player_radius : hint_range(0.0, 2.0) = 0.3;
uniform float player_push   : hint_range(0.0, 2.0) = 0.5;

// Persistent trample map (sliding window centred near the player).
// Global so the window-origin shift propagates to all chunks in one call.
global uniform sampler2D trample_map;
global uniform float     trample_origin_x;
global uniform float     trample_origin_z;
uniform float trample_map_size = 128.0;
uniform float trample_push     : hint_range(0.0, 1.5) = 0.8;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	float t    = UV.y;
	float bend = t * t;
	vec3  root = MODEL_MATRIX[3].xyz;

	// ---- Natural growth variation ----
	// h1/h2 used only for static lean and trample direction below.
	float h1 = hash(root.xz);
	float h2 = hash(root.xz * 2.73 + vec2(19.3, 47.1));
	VERTEX.x += (h1 - 0.5) * 0.10 * bend;
	VERTEX.z += (h2 - 0.5) * 0.10 * bend;

	// ---- Wind animation ----
	// Uniform breeze: all blades share the same TIME-based wave so the
	// field moves as one. Two overlapping sines give gentle variation
	// without per-blade randomness. Direction drifts slowly (~±20°).
	float sway     = sin(TIME * 1.4) * 0.65 + sin(TIME * 0.38) * 0.35;
	float wind_amt = wind_strength * sway * bend;
	float drift    = sin(TIME * 0.07) * 0.35;
	float cd = cos(drift); float sd = sin(drift);
	vec2  wdir = normalize(vec2(
		wind_direction.x * cd - wind_direction.y * sd,
		wind_direction.x * sd + wind_direction.y * cd));
	VERTEX.x += wdir.x * wind_amt;
	VERTEX.z += wdir.y * wind_amt;

	// ---- Player immediate push (moving only) ----
	// When stationary the trample map already handles displacement;
	// this push only adds value while the player is actively walking.
	if (length(player_move_dir) > 0.1) {
		vec2  to_blade = root.xz - player_pos.xz;
		float dist     = length(to_blade);
		if (dist < player_radius && dist > 0.01) {
			float push_t   = 1.0 - dist / player_radius;
			push_t         = push_t * push_t;
			float dir_factor = step(0.0, dot(to_blade, player_move_dir));
			vec2  push     = normalize(to_blade) * push_t * player_push * dir_factor;
			VERTEX.x += push.x * t;
			VERTEX.z += push.y * t;
		}
	}

	// ---- Persistent trample from trample map ----
	vec2  trample_uv = (root.xz - vec2(trample_origin_x, trample_origin_z)) / trample_map_size;
	float trample    = texture(trample_map, trample_uv).r;
	if (trample > 0.01) {
		float angle    = h2 * 6.2832;  // reuse h2 — uncorrelated from h1
		vec2  lean_dir = vec2(cos(angle), sin(angle));
		VERTEX.x += lean_dir.x * trample * trample_push * t;
		VERTEX.z += lean_dir.y * trample * trample_push * t;
		VERTEX.y  *= 1.0 - trample * 0.4 * t;
	}
}

void fragment() {
	// Double-sided lighting: flip normal when viewing the back face
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}

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
	// Match terrain's emission floor so grass doesn't go pitch-black in shadow
	EMISSION = col * 0.15;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	// Hard cutoff at tip instead of smooth fade
	ALPHA = step(UV.y, 0.92);
	// Low threshold keeps this material in Godot's opaque pass (depth writes,
	// depth testing vs. player/terrain). alpha_to_coverage then handles MSAA
	// coverage anti-aliasing for the remaining semi-transparent pixels.
	ALPHA_SCISSOR_THRESHOLD = 0.01;
}
