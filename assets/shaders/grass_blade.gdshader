shader_type spatial;
render_mode cull_disabled, unshaded;

// --- Color palette (Genshin-inspired: deep emerald base → bright teal-green tip) ---
uniform vec4  color_base       : source_color = vec4(0.04, 0.22, 0.08, 1.0);
uniform vec4  color_mid        : source_color = vec4(0.10, 0.42, 0.20, 1.0);
uniform vec4  color_tip        : source_color = vec4(0.40, 0.78, 0.38, 1.0);

// --- Wind ---
uniform float wind_strength    : hint_range(0.0, 1.0) = 0.28;
uniform vec2  wind_direction                          = vec2(1.0, 0.35);

// Player position for immediate blade push
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

	// ---- Tiny natural growth variation ----
	float h1 = hash(root.xz);
	float h2 = hash(root.xz * 2.73 + vec2(19.3, 47.1));
	VERTEX.x += (h1 - 0.5) * 0.10 * bend;
	VERTEX.z += (h2 - 0.5) * 0.10 * bend;

	// ---- Wind animation ----
	// Per-blade phase offset so blades don't all sway in sync
	float phase = hash(root.xz * 1.37) * 6.2832;
	// Primary sway — medium frequency
	float sway  = sin(TIME * 2.0 + phase + root.x * 0.4 + root.z * 0.25);
	// Slow gust envelope
	float gust  = sin(TIME * 0.65 + phase * 0.4) * 0.35 + 0.65;
	// Secondary ripple — slightly faster, perpendicular offset
	float ripple = sin(TIME * 3.1 + phase * 0.7 + root.z * 0.6) * 0.15;
	float wind_amt = wind_strength * (sway * gust + ripple) * bend;
	vec2  wdir = normalize(wind_direction);
	VERTEX.x += wdir.x * wind_amt;
	VERTEX.z += wdir.y * wind_amt;

	// ---- Player immediate push ----
	vec2  to_blade = root.xz - player_pos.xz;
	float dist     = length(to_blade);
	if (dist < player_radius && dist > 0.01) {
		float push_t = 1.0 - dist / player_radius;
		push_t = push_t * push_t;
		float dir_factor = length(player_move_dir) > 0.1
				? step(0.0, dot(to_blade, player_move_dir))
				: 1.0;
		vec2 push = normalize(to_blade) * push_t * player_push * dir_factor;
		VERTEX.x += push.x * t;
		VERTEX.z += push.y * t;
	}

	// ---- Persistent trample from trample map ----
	vec2 trample_uv = (root.xz - vec2(trample_origin_x, trample_origin_z)) / trample_map_size;
	float trample = texture(trample_map, trample_uv).r;
	if (trample > 0.01) {
		float angle = hash(root.xz * 3.17) * 6.2832;
		vec2  lean_dir = vec2(cos(angle), sin(angle));
		VERTEX.x += lean_dir.x * trample * trample_push * t;
		VERTEX.z += lean_dir.y * trample * trample_push * t;
		VERTEX.y *= 1.0 - trample * 0.4 * t;
	}
}

void fragment() {
	// Three-zone gradient — base zone is larger (0→0.45) so deep color shows more
	vec3 col;
	if (UV.y < 0.45) {
		col = mix(color_base.rgb, color_mid.rgb, UV.y / 0.45);
	} else {
		col = mix(color_mid.rgb, color_tip.rgb, (UV.y - 0.45) / 0.55);
	}

	// Ambient occlusion — darken blades near the ground
	float ao = smoothstep(0.0, 0.35, UV.y);
	col *= mix(0.35, 1.0, ao);

	// Subsurface / tip glow — tips appear slightly luminous (backlit by sky)
	float sss = pow(UV.y, 2.5) * 0.32;
	col += vec3(sss * 0.05, sss * 0.22, sss * 0.04);

	// Center-edge brightening — gives each blade a subtle midrib / 3D feel
	float edge_mask = 1.0 - abs(UV.x - 0.5) * 2.0;
	col += col * edge_mask * UV.y * 0.18;

	ALBEDO = col;
	// Hard alpha cutoff — opaque render pass, no sorting needed
	ALPHA = step(UV.y, 0.92);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
