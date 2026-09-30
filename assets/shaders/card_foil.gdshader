// Card foil (GID-151 / TID-641): a light band sweeping diagonally across an
// epic / legendary card's frame. Screen-space (FRAGCOORD) so every foil card on
// screen catches the same sweep. Applied to the card panel only (children keep
// their own material), so it touches the frame, rim and glow, not the text.
shader_type canvas_item;

uniform vec4 tint : source_color = vec4(1.0, 0.8, 0.2, 1.0);
uniform float strength = 0.5;
uniform float band_px = 50.0;
uniform float period_px = 520.0;
uniform float speed = 170.0;

void fragment() {
	float d = mod(FRAGCOORD.x + FRAGCOORD.y * 0.6 - TIME * speed, period_px);
	float band = 1.0 - smoothstep(0.0, band_px, abs(d - band_px));
	COLOR.rgb = mix(COLOR.rgb, COLOR.rgb + tint.rgb * 0.8, band * strength);
}
