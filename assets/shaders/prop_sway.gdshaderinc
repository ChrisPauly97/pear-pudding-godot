// Ground props and trees that bend in the wind (GID-152 / TID-647). Mirrors
// the StandardMaterial3D the props used (camera-facing billboard keeping the
// instance scale, alpha scissor, nearest filtering) and leans the sprite's
// top toward the wind, stepped in whole texels like the grass tufts.
// Included by prop_sway.gdshader (unshaded) and prop_sway_lit.gdshader.

uniform sampler2D albedo_texture : source_color, filter_nearest;
// World units the top edge leans at full wind (per prop key, ChunkRenderer).
uniform float sway_amount = 0.06;
// Seconds per sway cycle at wind scale 1 — bigger plants move slower.
uniform float sway_period = 2.6;

global uniform float grass_wind_scale;
global uniform float grass_wind_lean;
global uniform vec2 plant_wind_dir;

const float PIXEL = 0.05;  // world units per texel (SpriteRegistry.CHAR_PIXEL_SIZE)

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	float phase = fract(sin(dot(root.xz, vec2(12.9898, 78.233))) * 43758.5453) * 6.2831;
	// Stepped time (6 fps) so the lean changes in frames, not a smooth glide.
	float t = floor(TIME * 6.0) / 6.0;
	float w = 6.2831 / sway_period;
	float sway = sin(t * w + phase) * 0.7 + sin(t * w * 0.37 + phase * 1.7) * 0.3;
	// Wind across the screen: its component along the camera's right axis.
	vec3 right = normalize(MAIN_CAM_INV_VIEW_MATRIX[0].xyz);
	vec2 wdir = length(plant_wind_dir) > 0.001 ? normalize(plant_wind_dir) : vec2(1.0, 0.0);
	float across = dot(vec3(wdir.x, 0.0, wdir.y), right);
	float lean = across * (sway * grass_wind_scale + grass_wind_lean) * sway_amount;
	lean = round(lean / PIXEL) * PIXEL;
	float top = 1.0 - UV.y;  // QuadMesh: UV.y = 0 at the top edge
	float sx = length(MODEL_MATRIX[0].xyz);
	VERTEX.x += lean * top * top / max(sx, 0.001);
	// Billboard (BaseMaterial3D BILLBOARD_ENABLED + billboard_keep_scale).
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(MAIN_CAM_INV_VIEW_MATRIX[0], MAIN_CAM_INV_VIEW_MATRIX[1],
			MAIN_CAM_INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(sx, 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	ALBEDO = tex.rgb;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
