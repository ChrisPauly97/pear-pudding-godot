shader_type spatial;
render_mode cull_disabled;

// Vertex colour R channel: 0.0 = flat grass, 1.0 = hill plateau top.
// Normals are computed from the height field and baked into the mesh.

uniform sampler2D grass_texture     : source_color, filter_nearest, hint_default_white;
// Earthy dirt shown on the steep sides of hills (mid-height zone)
uniform sampler2D hill_side_texture : source_color, filter_nearest, hint_default_white;
// Grassy top shown on the flat plateau of hills (high-height zone)
uniform sampler2D hill_texture      : source_color, filter_nearest, hint_default_white;
// Earthy/stone texture shown on the steep slopes of walls
uniform sampler2D wall_side_texture : source_color, filter_nearest, hint_default_white;
// Stone floor shown on the flat plateau of walls
uniform sampler2D wall_top_texture  : source_color, filter_nearest, hint_default_white;

// How many times the textures tile per world unit
uniform float uv_scale : hint_range(0.05, 2.0) = 0.5;

varying float v_blend;      // height ratio [0=flat ground .. 1=hill plateau]
varying float v_wall;       // 1.0 if this vertex sits on a wall tile
varying vec3  v_normal_world;  // world-space normal — used for slope detection only
varying vec2  v_world_xz;
varying float v_world_y;    // world Y — used for vertical tiling on wall sides
varying float v_d0;         // fbm noise channel 0, computed per-vertex
varying float v_d1;         // fbm noise channel 1, computed per-vertex

// -- noise for micro grass detail on flat areas --
float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash2(i),               hash2(i + vec2(1.0, 0.0)), f.x),
		mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}
float fbm(vec2 p) {
	float v = 0.5 * vnoise(p);
	p = p * 2.1 + vec2(1.7, 3.1);
	v += 0.25 * vnoise(p);
	return v;
}

void vertex() {
	// Pass blend factor, wall flag, and world normal to fragment
	v_blend = COLOR.r;
	v_wall  = COLOR.g;
	// World-space normal is only used for slope detection in fragment(),
	// not for lighting — Godot transforms NORMAL to view space automatically.
	v_normal_world = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_xz     = world_pos.xz;
	v_world_y      = world_pos.y;

	// Subtle micro-bump on flat grass — single hash instead of full FBM (cheap)
	float flat_factor = clamp(1.0 - v_blend * 4.0, 0.0, 1.0);
	if (flat_factor > 0.01) {
		VERTEX.y += hash2(v_world_xz * 0.08) * 0.12 * flat_factor;
	}

	// Noise variation removed — pixel art uses flat texture colors only.
	v_d0 = 0.0;
	v_d1 = 0.0;
}

void fragment() {
	// World-space XZ used for both texture sampling and procedural noise
	vec2 uv_xz = v_world_xz * uv_scale;

	// slope: 0 = flat-up, 1 = vertical face
	float slope = 1.0 - clamp(v_normal_world.y, 0.0, 1.0);

	// Noise variation pre-computed per-vertex; hardware interpolates across the triangle.
	float d0 = v_d0;
	float d1 = v_d1;

	// Zone blend factors — driven by height only, not slope.
	// Slope-based blending caused dungeon floor tiles adjacent to tall walls
	// to incorrectly show the hill-side (dirt) texture.
	float t_side = smoothstep(0.05, 0.55, v_blend);
	float t_top  = smoothstep(0.60, 0.92, v_blend);

	// Sample only the textures actually contributing to this fragment.
	// Flat grass is the common case (~60-70% of terrain) — skip all other fetches.
	vec3 base_col;
	// Threshold 0.05 instead of 0.5 so the steep wall-base triangle
	// (interpolated between is_wall=0 grass vertex and is_wall=1 wall vertex)
	// is classified as wall and receives stone texture rather than grass/hill.
	bool is_wall = v_wall > 0.05;

	if (is_wall) {
		// Use surface normal to pick side vs top — no grass on wall tiles.
		// slope=0: flat top → wall_top_texture; slope=1: vertical face → wall_side_texture.
		float wall_slope = 1.0 - clamp(v_normal_world.y, 0.0, 1.0);
		float t_wall_side = smoothstep(0.3, 0.7, wall_slope);
		// Side UV: U from the along-face horizontal axis, V from world Y so the
		// texture tiles both horizontally and vertically on wall sides.
		// X-facing wall (|normal.x|≈1): along-face axis is Z → U = world_Z
		// Z-facing wall (|normal.z|≈1): along-face axis is X → U = world_X
		float side_u = mix(v_world_xz.y, v_world_xz.x, abs(v_normal_world.z));
		vec2 uv_side = vec2(side_u, v_world_y) * uv_scale;
		base_col = mix(texture(wall_top_texture, uv_xz).rgb,
		               texture(wall_side_texture, uv_side).rgb, t_wall_side);
	} else if (t_side < 0.01 && t_top < 0.01) {
		// Pure flat grass — most common case
		base_col = texture(grass_texture, uv_xz).rgb;
	} else {
		base_col = texture(grass_texture, uv_xz).rgb;
		if (t_side > 0.01) {
			base_col = mix(base_col, texture(hill_side_texture, uv_xz).rgb, t_side);
		}
		if (t_top > 0.01) {
			base_col = mix(base_col, texture(hill_texture, uv_xz).rgb, t_top);
		}
	}

	// Hand the base colour to Godot's lighting pipeline.
	// Override NORMAL from the height-field gradient (v_normal_world) so lighting
	// is always correct regardless of GPU 2D-winding.  Steep hill triangles can
	// have their projected winding flipped under isometric view, causing the GPU
	// to treat them as back-faces; overriding NORMAL here fixes that without
	// needing FRONT_FACING hacks or removing cull_disabled.
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(v_normal_world), 0.0)).xyz);
	ALBEDO = base_col;
	// Soft emission floor keeps cast shadows from going pitch-black.
	// Value is below glow_hdr_threshold (0.5) so it won't trigger bloom.
	EMISSION = base_col * 0.15;
	ROUGHNESS = 0.9;
	METALLIC = 0.0;
	SPECULAR = 0.1;
}
