// Character sprite outline (GID-132 / TID-513).
//
// Set as `material_override` on world character Sprite3D / AnimatedSprite3D
// by SpriteOutline.gd. SpriteBase3D does not hand its texture to an override
// material, so SpriteOutline feeds `sprite_tex` (once for Sprite3D, per frame
// for AnimatedSprite3D). Everything else still comes from the sprite's own
// mesh: UVs carry flip_h / region, vertex COLOR carries `modulate` (tints and
// fade tweens keep working). The quad is billboarded here, as the built-in
// BILLBOARD_ENABLED material would.
//
// A transparent texel next to an opaque one (4-neighbourhood, one texel)
// becomes outline colour, so every sprite gets a crisp 1-texel dark edge.
// depth_prepass_alpha keeps the alpha-cut depth behaviour sprites rely on
// (a rider drawn over its mount by a tiny depth nudge; CLAUDE.md).
shader_type spatial;
render_mode unshaded, depth_prepass_alpha, cull_disabled, shadows_disabled;

uniform sampler2D sprite_tex : source_color, filter_nearest, repeat_disable;
uniform vec4 outline_color : source_color = vec4(0.07, 0.05, 0.09, 1.0);
uniform float outline_alpha : hint_range(0.0, 1.0) = 0.9;

void vertex() {
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * sx, INV_VIEW_MATRIX[1] * sy,
			INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec4 c = texture(sprite_tex, UV);
	vec2 px = 1.0 / vec2(textureSize(sprite_tex, 0));
	float n = texture(sprite_tex, UV + vec2(px.x, 0.0)).a;
	n = max(n, texture(sprite_tex, UV - vec2(px.x, 0.0)).a);
	n = max(n, texture(sprite_tex, UV + vec2(0.0, px.y)).a);
	n = max(n, texture(sprite_tex, UV - vec2(0.0, px.y)).a);
	float edge = step(0.5, n) * (1.0 - step(0.5, c.a));
	vec3 col = mix(c.rgb, outline_color.rgb, edge);
	float a = max(c.a, edge * outline_alpha);
	ALBEDO = col * COLOR.rgb;
	ALPHA = a * COLOR.a;
}
