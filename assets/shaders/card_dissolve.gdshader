// Card dissolve (GID-151): burns a card away in blocky pixel cells with a
// glowing edge. Noise is taken in screen space (FRAGCOORD) so the frame, text
// and art of a whole card tree dissolve as one when children use the parent's
// material. progress 0 = intact, 1 = gone.
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.6, 0.25, 1.0);
uniform float edge_width = 0.08;
uniform float cell_px = 6.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 cell = floor(FRAGCOORD.xy / cell_px);
	float n = value_noise(cell * 0.12) * 0.8 + hash(cell) * 0.2;
	float p = progress * (1.0 + edge_width);
	if (n < p - edge_width) {
		COLOR.a = 0.0;
	} else if (n < p) {
		COLOR = vec4(edge_color.rgb * 1.4, COLOR.a);
	}
}
