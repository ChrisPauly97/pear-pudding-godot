// Screen transitions (GID-133 / TID-516) — TransitionManager's full-screen rect.
//
// `progress` 0 = clear, 1 = fully covered.
//   style 0 (WIPE):   diamond tiles sweep in diagonally, top-left → bottom-right
//                     (matches the iso grid). Each tile grows from its centre as
//                     the sweep front passes, so the edge reads as a mosaic.
//   style 1 (BATTLE): an iris closes on the screen centre with a slight swirl
//                     in its edge, for entering a fight.
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform int style = 0;
uniform float aspect = 1.7778;
uniform float cells = 14.0;
uniform vec4 cover_color : source_color = vec4(0.04, 0.04, 0.07, 1.0);

void fragment() {
	vec2 uv = UV;
	float covered;
	if (style == 1) {
		vec2 p = (uv - 0.5) * vec2(aspect, 1.0);
		float r = length(p);
		float ang = atan(p.y, p.x);
		float edge = 0.04 * sin(ang * 7.0 + progress * 9.0);
		float max_r = length(vec2(aspect, 1.0)) * 0.5 + 0.1;
		covered = step(max_r * (1.0 - progress) + edge, r);
	} else {
		vec2 g = uv * vec2(aspect, 1.0) * cells / aspect;
		vec2 cell = fract(g) - 0.5;
		float diamond = abs(cell.x) + abs(cell.y);  // 0 at centre .. 1 at corners
		// Sweep front runs diagonally; each tile has ~0.35 of the progress to fill.
		float front = (uv.x + uv.y) * 0.5;
		float local = clamp((progress * 1.35 - front * 1.0) / 0.35, 0.0, 1.0);
		covered = step(diamond, local * 1.02);
	}
	COLOR = vec4(cover_color.rgb, cover_color.a * covered);
}
