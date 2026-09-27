// Shared body of grass_tuft.gdshader (unshaded) and grass_tuft_lit.gdshader.
//
// Each MultiMesh instance is a unit quad (X -0.5..0.5, Y 0..1) scaled to the
// tuft's pixel size by GrassBlades: TUFT_PX texels wide, SHORT_PX or TALL_PX
// tall at PIXEL world units per texel. The atlas stores a tone (R) on the
// base→mid→tip ramp below plus coverage (A), so biome recolour and day/night
// still come from uniforms. Atlas: tools/generate_hd_terrain.py.

uniform sampler2D tuft_atlas : filter_nearest, hint_default_transparent;
uniform vec4  color_base       : source_color = vec4(0.12, 0.23, 0.07, 1.0);
uniform vec4  color_mid        : source_color = vec4(0.22, 0.35, 0.11, 1.0);
uniform vec4  color_tip        : source_color = vec4(0.34, 0.46, 0.16, 1.0);
instance uniform vec4 grass_recolor = vec4(1.0, 1.0, 1.0, 0.0);
uniform float wind_strength  : hint_range(0.0, 1.0) = 0.28;
uniform vec2  wind_direction                         = vec2(1.0, 0.35);
// Weather wind (TID-486): scale multiplies wind_strength, lean is a steady
// downwind bend at the tip. Written by DayNightCycle from WeatherLook.
global uniform float grass_wind_scale;
global uniform float grass_wind_lean;
// Sun+ambient approximation so unshaded tufts still follow day/night.
global uniform vec3 grass_day_tint;

// Player push while walking, and the persistent trample map (GrassBlades).
global uniform vec3  player_pos;
global uniform vec2  player_move_dir;
global uniform sampler2D trample_map;
global uniform float     trample_origin_x;
global uniform float     trample_origin_z;
uniform float trample_map_size = 128.0;
uniform float player_radius : hint_range(0.0, 2.0) = 0.6;
uniform float player_push   : hint_range(0.0, 2.0) = 0.35;

#include "res://assets/shaders/contact_shadow.gdshaderinc"
#include "res://assets/shaders/terrain_puddles.gdshaderinc"

const float PIXEL = 0.05;      // world units per texel — Player.PIXEL_SIZE
const float TUFT_PX = 16.0;
const float SHORT_PX = 12.0;
const float TALL_PX = 24.0;
const float VARIANTS = 8.0;

varying vec3 v_root_world;
varying flat float v_variant;  // atlas column, 0..7
varying flat float v_tall;     // 1 = tall row
varying flat float v_flip;     // 1 = mirrored

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	v_root_world = MODEL_MATRIX[3].xyz;
	vec3 root = v_root_world;
	float h1 = hash(root.xz);
	float h2 = hash(root.xz * 2.73 + vec2(19.3, 47.1));
	v_variant = floor(h1 * VARIANTS);
	v_flip = step(0.5, h2);
	// Tall tufts are instanced at TALL_PX texels high (see GrassBlades).
	v_tall = step((SHORT_PX + TALL_PX) * 0.5 * PIXEL, length(MODEL_MATRIX[1].xyz));

	// Tufts rooted in standing water sink into it (TID-515).
	float in_puddle = puddle_mask(root.xz, puddle_dip(root.xz), 1.0);
	float sink = 1.0 - smoothstep(0.3, 0.8, in_puddle);

	// Y-axis billboard: face the camera, stay upright. INV_VIEW_MATRIX is
	// engine-provided — never call inverse() per vertex.
	vec3 to_cam = INV_VIEW_MATRIX[3].xyz - root;
	to_cam.y = 0.0;
	float len = length(to_cam);
	to_cam = len > 0.001 ? to_cam / len : vec3(0.0, 0.0, 1.0);
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), to_cam));
	float w = length(MODEL_MATRIX[0].xyz);
	float hgt = length(MODEL_MATRIX[1].xyz);

	// Everything below leans the top edge sideways (in billboard space) and,
	// for trampling, squashes it. Offsets snap to whole texels so the tuft
	// shifts like a pixel-art animation frame instead of smearing.
	float top = UV.y;
	float sway  = sin(TIME * 1.4 + h1 * 1.5) * 0.65 + sin(TIME * 0.38) * 0.35;
	float drift = sin(TIME * 0.07) * 0.35;
	vec2 wdir = normalize(vec2(
		wind_direction.x * cos(drift) - wind_direction.y * sin(drift),
		wind_direction.x * sin(drift) + wind_direction.y * cos(drift)));
	vec3 wdir3 = vec3(wdir.x, 0.0, wdir.y);
	float lean = dot(wdir3, right) * (wind_strength * grass_wind_scale * sway + grass_wind_lean) * 0.35 * hgt;
	float squash = 0.0;
	if (length(player_move_dir) > 0.1) {
		vec2 away = root.xz - player_pos.xz;
		float d = length(away);
		if (d < player_radius && d > 0.01) {
			float p = 1.0 - d / player_radius;
			lean += dot(vec3(away.x, 0.0, away.y) / d, right) * p * p * player_push;
		}
	}
	vec2 trample_uv = (root.xz - vec2(trample_origin_x, trample_origin_z)) / trample_map_size;
	float trample = texture(trample_map, trample_uv).r;
	if (trample > 0.01) {
		lean += (h2 - 0.5) * 2.0 * trample * 0.25;
		squash = trample * 0.45;
	}
	lean = round(lean / PIXEL) * PIXEL;
	// world_vertex_coords: VERTEX is rebuilt in world space from the UVs
	// (x -0.5..0.5 across, 0..1 up), so no per-vertex matrix inverse.
	float y = top * hgt * sink * (1.0 - squash * top);
	VERTEX = root + right * ((UV.x - 0.5) * w + lean * top) + vec3(0.0, round(y / PIXEL) * PIXEL, 0.0);
}

void fragment() {
	float u = v_flip > 0.5 ? 1.0 - UV.x : UV.x;
	float rows = mix(SHORT_PX, TALL_PX, v_tall);
	int px = int(min(floor(u * TUFT_PX), TUFT_PX - 1.0)) + int(v_variant * TUFT_PX);
	// UV.y is 0 at the root; atlas rows run top-down.
	int py = int(min(floor((1.0 - UV.y) * rows), rows - 1.0)) + int(v_tall * SHORT_PX);
	vec4 texel = texelFetch(tuft_atlas, ivec2(px, py), 0);
	if (texel.a < 0.5) {
		discard;
	}
	float t = texel.r;
	// Tone ramp: 0 = outline (darkened base), 0.5 = mid, 1 = sunlit tip.
	vec3 col = t < 0.5
		? mix(color_base.rgb * 0.6, color_mid.rgb, t * 2.0)
		: mix(color_mid.rgb, color_tip.rgb, t * 2.0 - 1.0);
	// Per-biome recolour (GID-134): straw in the desert, burnt stubble when scorched.
	col = mix(col, grass_recolor.rgb * mix(0.55, 1.1, t), grass_recolor.a);
	// Per-tuft brightness/hue jitter so a field is not one flat colour.
	float jitter = fract(sin(dot(v_root_world.xz, vec2(12.9898, 78.233))) * 43758.5453);
	col *= mix(0.9, 1.1, jitter);
	col = mix(col, col * vec3(1.1, 1.04, 0.8), step(0.8, jitter) * 0.5);
	float shade = mix(contact_shadow(v_root_world), 1.0, UV.y * 0.6) * cloud_shadow(v_root_world.xz);
#ifdef GRASS_LIT
	// Lit like the ground under it (normal forced up), so it takes sun shadows.
	// ×1.3 matches the unshaded path's grass_day_tint peak against the terrain.
	ALBEDO = col * 1.3 * shade;
	EMISSION = ALBEDO * 0.08;
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
#else
	ALBEDO = col * grass_day_tint * shade;
#endif
}
