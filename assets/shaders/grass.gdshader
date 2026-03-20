shader_type spatial;
render_mode unshaded;

uniform vec4  color_light  : source_color = vec4(0.22, 0.52, 0.14, 1.0);
uniform vec4  color_dark   : source_color = vec4(0.14, 0.38, 0.09, 1.0);
uniform float blade_scale  : hint_range(2.0, 32.0) = 12.0;
uniform float height_scale : hint_range(0.0, 0.5)  = 0.12;

// --- noise helpers ---
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
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
	// Displace Y using noise — unshaded mode so NORMAL is not needed
	vec2 world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	float h = fbm(world_xz * blade_scale * 0.08);
	VERTEX.y += h * height_scale;
}

void fragment() {
	vec2 uv = UV * blade_scale;

	float base    = fbm(uv);
	float detail  = vnoise(uv * 3.7 + vec2(5.3, 2.7));
	float pattern = base * 0.65 + detail * 0.35;

	ALBEDO = mix(color_dark.rgb, color_light.rgb, pattern);
}
