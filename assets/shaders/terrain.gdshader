shader_type spatial;
render_mode unshaded, cull_disabled;

// Vertex colour R channel: 0.0 = flat grass, 1.0 = hill plateau top.
// Normals are computed from the height field and baked into the mesh.

uniform sampler2D grass_texture     : source_color, hint_default_white;
// Earthy dirt shown on the steep sides of hills (mid-height zone)
uniform sampler2D hill_side_texture : source_color, hint_default_white;
// Grassy top shown on the flat plateau of hills (high-height zone)
uniform sampler2D hill_texture      : source_color, hint_default_white;
// Stone floor shown under wall tiles
uniform sampler2D wall_top_texture  : source_color, hint_default_white;

// How many times the textures tile per world unit
uniform float uv_scale : hint_range(0.05, 2.0) = 0.5;

// Light direction for manual directional shading (approximate isometric sun)
uniform vec3 sun_dir                    = vec3(0.577, 0.577, 0.577);
uniform vec4 sun_color   : source_color = vec4(1.0, 0.95, 0.8, 1.0);
uniform vec4 ambient_col : source_color = vec4(0.3, 0.38, 0.45, 1.0);

varying float v_blend;   // height ratio [0=flat ground .. 1=hill plateau]
varying float v_wall;    // 1.0 if this vertex sits on a wall tile
varying vec3  v_normal_world;
varying vec2  v_world_xz;

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
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p  = p * 2.1 + vec2(1.7, 3.1);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	// Pass blend factor, wall flag, and world normal to fragment
	v_blend = COLOR.r;
	v_wall  = COLOR.g;
	v_normal_world = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	v_world_xz     = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;

	// Subtle micro-bump on flat grass only (same scale as old grass shader)
	float flat_factor = clamp(1.0 - v_blend * 4.0, 0.0, 1.0);
	if (flat_factor > 0.01) {
		float bump = fbm(v_world_xz * 0.08);
		VERTEX.y += bump * 0.12 * flat_factor;
	}
}

void fragment() {
	// World-space XZ used for both texture sampling and procedural noise
	vec2 uv_xz = v_world_xz * uv_scale;

	// slope: 0 = flat-up, 1 = vertical face
	float slope = 1.0 - clamp(v_normal_world.y, 0.0, 1.0);

	// Two independent fbm channels for micro colour variation
	// (fbm is defined in vertex scope — visible here via the same helper)
	float d0 = fbm(uv_xz * 3.7);
	float d1 = fbm(uv_xz * 3.7 + vec2(7.31, 2.97));

	// Zone blend factors (unchanged from before)
	float t_side = max(
		smoothstep(0.05, 0.55, v_blend),
		smoothstep(0.35, 0.70, slope)
	);
	float t_top = smoothstep(0.60, 0.92, v_blend)
	            * (1.0 - smoothstep(0.35, 0.70, slope));

	// Procedural zone colours — always visible, no external texture required.
	// Texture uniforms are kept for future override; if loaded they multiply in.
	vec3 grass_col = vec3(0.44 + d0 * 0.11, 0.62 + d0 * 0.09, 0.25 + d0 * 0.05);
	vec3 side_col  = vec3(0.36 + d1 * 0.08, 0.27 + d1 * 0.04, 0.13);
	vec3 top_col   = vec3(0.39 + d0 * 0.08, 0.58 + d0 * 0.09, 0.21 + d0 * 0.04);
	vec3 wall_col  = vec3(0.49 + d1 * 0.07, 0.38 + d1 * 0.05, 0.18 + d1 * 0.04);

	// Optional texture tint: (0.5 + tex*0.5) means white→factor=1 (no-op),
	// coloured texture→subtle tint.  Works correctly whether textures load or not.
	grass_col *= 0.5 + texture(grass_texture,     uv_xz).rgb * 0.5;
	side_col  *= 0.5 + texture(hill_side_texture, uv_xz).rgb * 0.5;
	top_col   *= 0.5 + texture(hill_texture,      uv_xz).rgb * 0.5;
	wall_col  *= 0.5 + texture(wall_top_texture,  uv_xz).rgb * 0.5;

	vec3 base_col = mix(grass_col, side_col, t_side);
	base_col = mix(base_col, top_col, t_top);
	base_col = mix(base_col, wall_col, step(0.5, v_wall));

	// Simple directional light baked from normal
	vec3 n  = normalize(v_normal_world);
	vec3 ld = normalize(sun_dir);
	float diff = max(dot(n, ld), 0.0);

	ALBEDO = base_col * (ambient_col.rgb + sun_color.rgb * diff);
}
