shader_type spatial;
render_mode cull_disabled;

// --- Color palette ---
// color_base owns the dark-at-root look directly; no AO multiplier needed.
uniform vec4  color_base       : source_color = vec4(0.03, 0.15, 0.06, 1.0);
uniform vec4  color_mid        : source_color = vec4(0.10, 0.42, 0.20, 1.0);
uniform vec4  color_tip        : source_color = vec4(0.40, 0.78, 0.38, 1.0);

// --- Wind ---
uniform float wind_strength    : hint_range(0.0, 1.0) = 0.28;
uniform vec2  wind_direction                          = vec2(1.0, 0.35);

// Player position for immediate blade push (only applied while moving)
uniform vec3  player_pos                               = vec3(-9999.0, 0.0, -9999.0);
uniform vec2  player_move_dir  = vec2(0.0);
uniform float player_radius    : hint_range(0.0, 2.0)  = 0.3;
uniform float player_push      : hint_range(0.0, 2.0)  = 0.5;

// Persistent trample map (sliding window centred near the player)
uniform sampler2D trample_map : filter_linear;
uniform float     trample_map_size = 128.0;
uniform float     trample_origin_x = -64.0;
uniform float     trample_origin_z = -64.0;
uniform float     trample_push     : hint_range(0.0, 1.5) = 0.8;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	float t    = UV.y;
	float bend = t * t;
	vec3  root = MODEL_MATRIX[3].xyz;

	// ---- Natural growth variation ----
	// h1/h2 are reused below as wind phase and trample angle seeds.
	float h1 = hash(root.xz);
	float h2 = hash(root.xz * 2.73 + vec2(19.3, 47.1));
	VERTEX.x += (h1 - 0.5) * 0.10 * bend;
	VERTEX.z += (h2 - 0.5) * 0.10 * bend;

	// ---- Wind animation ----
	float phase  = h1 * 6.2832;  // reuse h1 — already a stable per-blade random
	float sway   = sin(TIME * 2.0 + phase + root.x * 0.4 + root.z * 0.25);
	float gust   = sin(TIME * 0.65 + phase * 0.4) * 0.35 + 0.65;
	float ripple = sin(TIME * 3.1 + phase * 0.7 + root.z * 0.6) * 0.15;
	float wind_amt = wind_strength * (sway * gust + ripple) * bend;
	vec2  wdir = normalize(wind_direction);
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

	// Three-zone gradient from root to tip
	vec3 col;
	if (UV.y < 0.45) {
		col = mix(color_base.rgb, color_mid.rgb, UV.y / 0.45);
	} else {
		col = mix(color_mid.rgb, color_tip.rgb, (UV.y - 0.45) / 0.55);
	}

	ALBEDO = col;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	ALPHA = step(UV.y, 0.92);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
