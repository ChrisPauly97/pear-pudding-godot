// Smoky lantern glass on the town street lamps: vertex colour carries the soot
// (dark at the top, amber below) and the glow follows it, so the grime shows
// against the light. `glow` is driven by the night factor from TownStreetsView.
shader_type spatial;
render_mode cull_disabled;

uniform float glow : hint_range(0.0, 4.0) = 0.0;

void fragment() {
	ALBEDO = COLOR.rgb * 0.6;
	ROUGHNESS = 0.35;
	EMISSION = COLOR.rgb * glow;
}
