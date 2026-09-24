// Screen-space sun rays (GID-129 / TID-488) — the Medium-tier fallback for
// volumetric light shafts, and a lighter companion to them on High.
//
// The iso camera is orthographic, so the sun is never on screen: SunRaysFx
// places a virtual source just past the screen edge the sun direction points
// at (source_uv). Each pixel gets
//   * shafts   — irregular angular bands radiating from the source, slowly drifting;
//   * falloff  — fading with distance from the source (rays die out mid-screen);
//   * lit      — a short occlusion march (SAMPLES taps) toward the source over
//                the screen texture: dark pixels (tree canopies, cliffs, shade)
//                on the way break the shaft, bright ground lets it through.
// The result is added (blend_add) in the sun colour. SunRaysFx hides the layer
// when strength is ~0 (midday, night, storms), so the screen copy and the
// SAMPLES taps cost nothing then.
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform vec2 source_uv = vec2(1.1, 0.5);
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform vec3 ray_color : source_color = vec3(1.0, 0.8, 0.5);
uniform float aspect = 1.7778;
// Peak added brightness at full strength; kept low so rays never wash out the screen.
uniform float intensity = 0.32;
// Luminance around which a screen pixel counts as lit (not an occluder).
uniform float lit_threshold = 0.35;

const int SAMPLES = 10;
// Fraction of the pixel → source distance the occlusion march covers.
const float MARCH_REACH = 0.35;

float hash11(float p) {
	return fract(sin(p * 127.1) * 43758.5453);
}

// 1D value noise over the ray angle, wrapped so there is no seam at ±PI.
float angle_noise(float a, float freq, float drift) {
	float x = (a / 6.2831853 + 0.5) * freq + drift;
	float i = floor(x);
	float f = fract(x);
	float u = f * f * (3.0 - 2.0 * f);
	return mix(hash11(mod(i, freq)), hash11(mod(i + 1.0, freq)), u);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 to_src = source_uv - uv;
	vec2 d = -to_src * vec2(aspect, 1.0);
	float dist = length(d);
	float ang = atan(d.y, d.x);

	float shafts = angle_noise(ang, 48.0, TIME * 0.05) * 0.65
			+ angle_noise(ang, 131.0, -TIME * 0.03) * 0.35;
	// A soft warm floor so the source edge glows between the distinct shafts.
	shafts = 0.25 + 0.75 * smoothstep(0.35, 0.9, shafts);
	float falloff = exp(-dist * 1.6);

	vec2 stp = to_src * (MARCH_REACH / float(SAMPLES));
	vec2 p = uv;
	float lit = 0.0;
	float wsum = 0.0;
	float w = 1.0;
	for (int i = 0; i < SAMPLES; i++) {
		p += stp;
		vec3 c = texture(screen_tex, clamp(p, vec2(0.0), vec2(1.0))).rgb;
		float l = dot(c, vec3(0.299, 0.587, 0.114));
		lit += smoothstep(lit_threshold - 0.15, lit_threshold + 0.15, l) * w;
		wsum += w;
		w *= 0.85;
	}
	lit /= wsum;

	float a = strength * intensity * shafts * falloff * lit;
	COLOR = vec4(ray_color * a, 1.0);
}
