shader_type spatial;
render_mode cull_disabled, unshaded, blend_mix, depth_draw_opaque;

uniform vec4  color_base       : source_color      = vec4(0.18, 0.48, 0.12, 1.0);
uniform vec4  color_mid        : source_color      = vec4(0.28, 0.62, 0.18, 1.0);
uniform vec4  color_tip        : source_color      = vec4(0.52, 0.80, 0.32, 1.0);


// Player trample trail — 8 snapshots, oldest have lower weight
uniform vec3  player_trail[8];
uniform float trail_weights[8];
uniform vec2  player_move_dir  = vec2(0.0);  // XZ velocity direction (normalised)
uniform float player_radius    : hint_range(0.0, 2.0)  = 0.3;
uniform float player_push      : hint_range(0.0, 2.0)  = 0.5;

// Persistent trample map (sliding window centred near the player)
uniform sampler2D trample_map : filter_linear;
uniform float     trample_map_size = 128.0;  // world units covered by the window
uniform float     trample_origin_x = -64.0;  // world-space X of the window's left edge
uniform float     trample_origin_z = -64.0;  // world-space Z of the window's top edge
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
	VERTEX.x += (h1 - 0.5) * 0.08 * bend;
	VERTEX.z += (h2 - 0.5) * 0.08 * bend;

	// ---- Player trample with springback and direction-aware push ----
	vec2 total_push = vec2(0.0);
	bool has_move_dir = length(player_move_dir) > 0.1;

	for (int i = 0; i < 8; i++) {
		float w = trail_weights[i];
		if (w < 0.01) continue;

		vec2  to_blade = root.xz - player_trail[i].xz;
		float dist     = length(to_blade);
		if (dist >= player_radius || dist < 0.01) continue;

		float push_t  = 1.0 - dist / player_radius;
		push_t        = push_t * push_t;

		// Direction-aware on current position only: don't push grass behind player
		float dir_factor = 1.0;
		if (i == 0 && has_move_dir) {
			dir_factor = step(0.0, dot(to_blade, player_move_dir));
		}

		total_push += normalize(to_blade) * push_t * player_push * w * dir_factor;
	}

	VERTEX.x += total_push.x * t;
	VERTEX.z += total_push.y * t;

	// ---- Persistent trample from trample map ----
	vec2 trample_uv = (root.xz - vec2(trample_origin_x, trample_origin_z)) / trample_map_size;
	float trample = texture(trample_map, trample_uv).r;
	if (trample > 0.01) {
		// Push blade outward from its root using a hash-based random direction
		// (each blade gets a consistent lean direction)
		float angle = hash(root.xz * 3.17) * 6.2832;
		vec2  lean_dir = vec2(cos(angle), sin(angle));
		VERTEX.x += lean_dir.x * trample * trample_push * t;
		VERTEX.z += lean_dir.y * trample * trample_push * t;
		// Also flatten — reduce height
		VERTEX.y *= 1.0 - trample * 0.4 * t;
	}
}

void fragment() {
	vec3 col;
	if (UV.y < 0.5) {
		col = mix(color_base.rgb, color_mid.rgb, UV.y * 2.0);
	} else {
		col = mix(color_mid.rgb, color_tip.rgb, (UV.y - 0.5) * 2.0);
	}
	ALBEDO = col;
	ALPHA  = smoothstep(1.0, 0.6, UV.y);  // tip fades to transparent
}
