shader_type spatial;
render_mode unshaded;

// Vertex colour R channel: 0.0 = flat grass, 1.0 = hill top.
// Normals are computed from the height field and baked into the mesh.

uniform sampler2D grass_texture  : source_color, hint_default_white;
uniform sampler2D hill_texture   : source_color, hint_default_white;

// How many times the textures tile per world unit
uniform float uv_scale : hint_range(0.05, 2.0) = 0.5;

// Light direction for manual directional shading (approximate isometric sun)
uniform vec3 sun_dir                    = vec3(0.577, 0.577, 0.577);
uniform vec4 sun_color   : source_color = vec4(1.0, 0.95, 0.8, 1.0);
uniform vec4 ambient_col : source_color = vec4(0.3, 0.38, 0.45, 1.0);

varying float v_blend;   // grass↔hill blend [0..1]
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
	// Pass blend factor and world normal to fragment
	v_blend = COLOR.r;
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
	// Triplanar-style UV from world position so textures don't stretch on slopes
	vec2 uv_xz = v_world_xz * uv_scale;

	vec3 grass_col = texture(grass_texture, uv_xz).rgb;
	vec3 hill_col  = texture(hill_texture,  uv_xz).rgb;

	// Slope computed from world normal — used to blend towards rocky on steep faces
	float up_dot  = clamp(v_normal_world.y, 0.0, 1.0);
	float slope   = 1.0 - up_dot;           // 0 = flat, 1 = vertical

	// Steeper slopes look rockier regardless of height
	float blend = max(v_blend, smoothstep(0.4, 0.75, slope));
	blend = smoothstep(0.15, 0.75, blend);  // soft threshold

	vec3 base_col = mix(grass_col, hill_col, blend);

	// Simple directional light baked from normal
	vec3 n  = normalize(v_normal_world);
	vec3 ld = normalize(sun_dir);
	float diff = max(dot(n, ld), 0.0);

	ALBEDO = base_col * (ambient_col.rgb + sun_color.rgb * diff);
}
