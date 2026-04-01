// Pixel-art card frame shader (canvas_item)
// Draws a dark outer border, inner bevel (light top/left, dark bottom/right),
// and fills the interior with base_color.
// Optional illustration texture blended into the upper portion of the card.
shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(0.3, 0.3, 0.3, 1.0);
uniform bool selected = false;
uniform sampler2D illustration;
uniform bool has_illustration = false;

// Normalized UV widths (fraction of card size)
const float OUTER = 0.065;  // outer border thickness
const float BEVEL = 0.028;  // inner bevel/highlight thickness

void fragment() {
	float bx = min(UV.x, 1.0 - UV.x);
	float by = min(UV.y, 1.0 - UV.y);
	float bd = min(bx, by);

	vec3 border_rgb;
	if (selected) {
		border_rgb = vec3(1.0, 0.85, 0.0);
	} else {
		border_rgb = mix(base_color.rgb, vec3(0.0), 0.55);
	}

	vec3 bevel_hi = mix(base_color.rgb, vec3(1.0), 0.42);
	vec3 bevel_lo = mix(base_color.rgb, vec3(0.0), 0.28);

	vec3 col;

	if (bd < OUTER) {
		// Outer border (all four edges)
		col = border_rgb;
	} else if (UV.y < OUTER + BEVEL || UV.x < OUTER + BEVEL) {
		// Top and left inner bevel — lighter (highlight)
		col = bevel_hi;
	} else if (UV.y > 1.0 - OUTER - BEVEL || UV.x > 1.0 - OUTER - BEVEL) {
		// Bottom and right inner bevel — darker (shadow)
		col = bevel_lo;
	} else {
		// Interior
		if (has_illustration && UV.y < 0.55) {
			// Remap UV into the illustration region
			float inner_start = OUTER + BEVEL;
			float inner_end_x = 1.0 - OUTER - BEVEL;
			float inner_end_y = 0.55;
			vec2 illus_uv = vec2(
				(UV.x - inner_start) / (inner_end_x - inner_start),
				UV.y / inner_end_y
			);
			illus_uv = clamp(illus_uv, vec2(0.0), vec2(1.0));
			vec4 illus = texture(illustration, illus_uv);
			// Blend illustration over base_color using illustration alpha
			col = mix(base_color.rgb, illus.rgb, illus.a * 0.85);
		} else {
			col = base_color.rgb;
		}
	}

	COLOR = vec4(col, 1.0);
}
