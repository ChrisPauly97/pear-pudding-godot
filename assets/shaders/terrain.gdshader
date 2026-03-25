shader_type spatial;
render_mode cull_disabled;

// Vertex colour R channel: 0.0 = flat grass, 1.0 = hill plateau top.
// Normals are computed from the height field and baked into the mesh.

uniform sampler2D grass_texture     : source_color, hint_default_white;
// Earthy dirt shown on the steep sides of hills (mid-height zone)
uniform sampler2D hill_side_texture : source_color, hint_default_white;
// Grassy top shown on the flat plateau of hills (high-height zone)
uniform sampler2D hill_texture      : source_color, hint_default_white;
// Earthy/stone texture shown on the steep slopes of walls
uniform sampler2D wall_side_texture : source_color, hint_default_white;
// Stone floor shown on the flat plateau of walls
uniform sampler2D wall_top_texture  : source_color, hint_default_white;

// How many times the textures tile per world unit
uniform float uv_scale : hint_range(0.05, 2.0) = 0.5;

varying float v_blend;   // height ratio [0=flat ground .. 1=hill plateau]
varying float v_wall;    // 1.0 if this vertex sits on a wall tile
varying vec3  v_normal_world;  // world-space normal — used for slope detection only
varying vec2  v_world_xz;
varying float v_d0;      // fbm noise channel 0, computed per-vertex
varying float v_d1;      // fbm noise channel 1, computed per-vertex

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
	v_world_xz     = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;

	// Subtle micro-bump on flat grass — single hash instead of full FBM (cheap)
	float flat_factor = clamp(1.0 - v_blend * 4.0, 0.0, 1.0);
	if (flat_factor > 0.01) {
		VERTEX.y += hash2(v_world_xz * 0.08) * 0.12 * flat_factor;
	}

	// Pre-compute noise variation per-vertex instead of per-fragment.
	vec2 noise_uv = v_world_xz * uv_scale * 3.7;
	v_d0 = fbm(noise_uv);
	v_d1 = fbm(noise_uv + vec2(7.31, 2.97));
}

void fragment() {
	// World-space XZ used for both texture sampling and procedural noise
	vec2 uv_xz = v_world_xz * uv_scale;

	// slope: 0 = flat-up, 1 = vertical face
	float slope = 1.0 - clamp(v_normal_world.y, 0.0, 1.0);

	// Noise variation pre-computed per-vertex; hardware interpolates across the triangle.
	float d0 = v_d0;
	float d1 = v_d1;

	// Zone blend factors (unchanged from before)
	float t_side = max(
		smoothstep(0.05, 0.55, v_blend),
		smoothstep(0.35, 0.70, slope)
	);
	float t_top = smoothstep(0.60, 0.92, v_blend)
	            * (1.0 - smoothstep(0.35, 0.70, slope));

	// Sample only the textures actually contributing to this fragment.
	// Flat grass is the common case (~60-70% of terrain) — skip all other fetches.
	vec3 base_col;
	bool is_wall = v_wall > 0.5;

	if (is_wall) {
		// Same slope-based zone blending as hills, but with wall textures
		vec3 grass_col_w = vec3(0.44 + d0 * 0.11, 0.62 + d0 * 0.09, 0.25 + d0 * 0.05);
		grass_col_w = mix(grass_col_w, texture(grass_texture, uv_xz).rgb, 0.85);
		base_col = grass_col_w;
		if (t_side > 0.01) {
			vec3 side_col = vec3(0.42 + d1 * 0.07, 0.36 + d1 * 0.05, 0.28 + d1 * 0.04);
			side_col = mix(side_col, texture(wall_side_texture, uv_xz).rgb, 0.85);
			base_col = mix(base_col, side_col, t_side);
		}
		if (t_top > 0.01) {
			vec3 top_col = vec3(0.49 + d1 * 0.07, 0.38 + d1 * 0.05, 0.18 + d1 * 0.04);
			top_col = mix(top_col, texture(wall_top_texture, uv_xz).rgb, 0.85);
			base_col = mix(base_col, top_col, t_top);
		}
	} else if (t_side < 0.01 && t_top < 0.01) {
		// Pure flat grass — most common, single texture fetch
		vec3 grass_col = vec3(0.44 + d0 * 0.11, 0.62 + d0 * 0.09, 0.25 + d0 * 0.05);
		base_col = mix(grass_col, texture(grass_texture, uv_xz).rgb, 0.85);
	} else {
		vec3 grass_col = vec3(0.44 + d0 * 0.11, 0.62 + d0 * 0.09, 0.25 + d0 * 0.05);
		grass_col = mix(grass_col, texture(grass_texture, uv_xz).rgb, 0.85);
		base_col = grass_col;
		if (t_side > 0.01) {
			vec3 side_col = vec3(0.36 + d1 * 0.08, 0.27 + d1 * 0.04, 0.13);
			side_col = mix(side_col, texture(hill_side_texture, uv_xz).rgb, 0.85);
			base_col = mix(base_col, side_col, t_side);
		}
		if (t_top > 0.01) {
			vec3 top_col = vec3(0.39 + d0 * 0.08, 0.58 + d0 * 0.09, 0.21 + d0 * 0.04);
			top_col = mix(top_col, texture(hill_texture, uv_xz).rgb, 0.85);
			base_col = mix(base_col, top_col, t_top);
		}
	}

	// Hand the base colour to Godot's lighting pipeline.
	// The DirectionalLight3D (sun/moon) and WorldEnvironment ambient are applied
	// by the engine — including the shadow map already baked on the sun light.
	ALBEDO = base_col;
	// Minimum emission so back-faces and fully-shadowed geometry never go black.
	// Value is below glow_hdr_threshold (0.5) so it won't trigger bloom.
	EMISSION = base_col * 0.3;
	ROUGHNESS = 0.9;
	METALLIC = 0.0;
	SPECULAR = 0.1;
}
