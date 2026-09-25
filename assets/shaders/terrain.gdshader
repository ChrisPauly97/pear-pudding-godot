shader_type spatial;
render_mode cull_disabled;

// Vertex colour R channel: 0.0 = flat grass, 1.0 = hill plateau top.
// Normals are computed from the height field and baked into the mesh.

uniform sampler2D grass_texture     : source_color, filter_nearest, hint_default_white;
// Earthy dirt shown on the steep sides of hills (mid-height zone)
uniform sampler2D hill_side_texture : source_color, filter_nearest, hint_default_white;
// Grassy top shown on the flat plateau of hills (high-height zone)
uniform sampler2D hill_texture      : source_color, filter_nearest, hint_default_white;
// Earthy/stone texture shown on the steep slopes of walls
uniform sampler2D wall_side_texture : source_color, filter_nearest, hint_default_white;
// Stone floor shown on the flat plateau of walls
uniform sampler2D wall_top_texture  : source_color, filter_nearest, hint_default_white;
// Brown packed-earth shown on path tiles (flat, walkable, town roads)
uniform sampler2D path_texture      : source_color, filter_nearest, hint_default_white;
uniform vec3 path_tint = vec3(1.0, 1.0, 1.0);

// How many times the textures tile per world unit
uniform float uv_scale : hint_range(0.05, 2.0) = 0.5;

// Per-chunk biome color tints — set per material instance by ChunkRenderer.
// Default vec3(1,1,1) = no tint (original texture colors).
uniform vec3 grass_tint = vec3(1.0, 1.0, 1.0);
uniform vec3 hill_tint  = vec3(1.0, 1.0, 1.0);
uniform vec3 wall_tint  = vec3(1.0, 1.0, 1.0);
// Desaturate the (green) ground textures before tinting: desert sand, scorched
// ash, mountain snow read as themselves instead of tinted meadow (GID-134).
uniform float ground_desat : hint_range(0.0, 1.0) = 0.0;
uniform float wall_moss : hint_range(0.0, 1.0) = 1.0;  // per biome: 0 in desert/scorched

// Per-chunk blight intensity [0=clean, 1=fully blighted].
// Set via MeshInstance3D.set_instance_shader_parameter() — no material duplication needed.
instance uniform float blight_amount : hint_range(0.0, 1.0) = 0.0;

// Rain wetness [0=dry, 1=soaked] (GID-129 / TID-487). Declared in project.godot
// [shader_globals]; DayNightCycle eases it in with rain and dries it slowly.
#include "res://assets/shaders/terrain_puddles.gdshaderinc"
#include "res://assets/shaders/contact_shadow.gdshaderinc"
// Wall cutaway: the player's feet in world space, written every frame by
// WorldScene. Terrain between the iso camera and the player (above their feet)
// dithers away in a soft circle so walls never hide them. Default in
// [shader_globals] sits far above the world, so nothing is cut until it's set.
global uniform vec3 occlusion_focus;

varying float v_blend;      // height ratio [0=flat ground .. 1=hill plateau]
varying float v_wall;       // 1.0 if this vertex sits on a wall tile
varying float v_path;       // 1.0 if this vertex sits on a path tile
varying float v_cracked;    // 1.0 if this wall vertex is a TILE_CRACKED (cracked wall)
varying vec3  v_normal_world;  // world-space normal — used for slope detection only
varying vec2  v_world_xz;
varying float v_world_y;    // world Y — used for vertical tiling on wall sides
const float OCCLUSION_RADIUS = 3.5;  // world units (~1.75 tiles)

varying float v_d0;         // fbm noise channel 0, computed per-vertex
varying float v_d1;         // fbm noise channel 1, computed per-vertex
varying float v_ley;        // ley line intensity [0..1], baked into UV2.x per vertex
varying float v_dip;        // 0 low .. 1 high flat-ground jitter (TID-515 puddles)
varying float v_water;      // stream/pond intensity [0..1], baked into UV2.y (GID-134 / TID-524)

// -- noise for micro grass detail on flat areas --
float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash2(i),               hash2(i + vec2(1.0, 0.0)), f.x),
		mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}
float fbm(vec2 p) {
	float v = 0.5 * vnoise(p);
	p = p * 2.1 + vec2(1.7, 3.1);
	v += 0.25 * vnoise(p);
	return v;
}

void vertex() {
	// Pass blend factor, wall flag, and world normal to fragment
	v_blend   = COLOR.r;
	v_wall    = COLOR.g;
	v_path    = COLOR.b;
	// Alpha < 0.5 encodes TILE_CRACKED (cracked wall); regular walls have alpha = 1.0
	v_cracked = COLOR.a < 0.5 ? 1.0 : 0.0;
	// World-space normal is only used for slope detection in fragment(),
	// not for lighting — Godot transforms NORMAL to view space automatically.
	v_normal_world = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_xz     = world_pos.xz;
	v_world_y      = world_pos.y;

	// Subtle micro-bump on flat grass — single hash instead of full FBM (cheap).
	// Suppressed on path tiles so roads stay visually flat.
	float flat_factor = clamp(1.0 - v_blend * 4.0, 0.0, 1.0);
	v_dip = v_path > 0.5 ? 0.5 : puddle_dip(v_world_xz);
	if (flat_factor > 0.01 && v_path < 0.5) {
		VERTEX.y += hash2(v_world_xz * 0.08) * 0.12 * flat_factor;
	}

	// Macro variation (GID-131 / TID-505): slow world-space noise, per vertex
	// (it changes over tens of units, so interpolation across a 1-unit tile is
	// exact enough) — breaks the repeating grass tile into lighter/darker and
	// drier/lusher patches without per-pixel cost.
	v_d0 = fbm(world_pos.xz * 0.045);
	v_d1 = fbm(world_pos.xz * 0.09 + vec2(7.3, 2.1));
	// Ley intensity baked per vertex into UV2.x by ChunkRenderer.
	v_ley = UV2.x;
	// Streams and ponds (UV2.y): the water surface sits a little below the
	// meadow so it reads as a channel; collision is untouched (the hero wades).
	v_water = UV2.y;
	if (v_water > 0.01 && v_path < 0.5) {
		VERTEX.y -= smoothstep(0.1, 0.6, v_water) * 0.2 * flat_factor;
	}
}

void fragment() {
	// World-space XZ used for both texture sampling and procedural noise
	vec2 uv_xz = v_world_xz * uv_scale;

	// slope: 0 = flat-up, 1 = vertical face
	float slope = 1.0 - clamp(v_normal_world.y, 0.0, 1.0);

	// Noise variation pre-computed per-vertex; hardware interpolates across the triangle.
	float d0 = v_d0;
	float d1 = v_d1;

	// Zone blend factors — driven by height only, not slope.
	// Slope-based blending caused dungeon floor tiles adjacent to tall walls
	// to incorrectly show the hill-side (dirt) texture.
	// Soft hill edges (GID-134 / TID-520): grass climbs the lower slope and the
	// dirt only shows where the side is genuinely steep, with a ragged noise
	// edge — not a hard brown ring the moment the ground starts to rise.
	float t_side = v_blend > 0.05
		? smoothstep(0.2, 0.62, v_blend + (vnoise(v_world_xz * 0.9) - 0.5) * 0.3)
			* smoothstep(0.18, 0.5, slope) : 0.0;
	float t_top  = smoothstep(0.60, 0.92, v_blend);

	// Sample only the textures actually contributing to this fragment.
	// Flat grass is the common case (~60-70% of terrain) — skip all other fetches.
	vec3 base_col;
	// Threshold 0.05 instead of 0.5 so the steep wall-base triangle
	// (interpolated between is_wall=0 grass vertex and is_wall=1 wall vertex)
	// is classified as wall and receives stone texture rather than grass/hill.
	bool is_wall = v_wall > 0.05;
	// Soft, ragged path edges (TID-505): the vertex-interpolated path flag plus
	// noise, instead of a hard on/off at 0.05 that drew the tile grid.
	float path_t = v_path > 0.001
		? smoothstep(0.2, 0.7, v_path + (vnoise(v_world_xz * 1.7) - 0.5) * 0.45) : 0.0;
	bool is_path = path_t > 0.99;
	// Anti-tiling (TID-505): swap to a rotated, offset copy of the grass tile
	// inside irregular noise blobs, so the 2-unit repeat never lines up. A hard
	// switch (not a blend) keeps the pixel art crisp.
	vec2 uv_grass = uv_xz;
	if (vnoise(v_world_xz * 0.23) > 0.5) {
		uv_grass = vec2(-uv_xz.y, uv_xz.x) + vec2(0.37, 0.61);
	}

	if (is_path) {
		base_col = texture(path_texture, uv_xz).rgb;
	} else if (is_wall) {
		// Use surface normal to pick side vs top — no grass on wall tiles.
		// slope=0: flat top → wall_top_texture; slope=1: vertical face → wall_side_texture.
		float wall_slope = 1.0 - clamp(v_normal_world.y, 0.0, 1.0);
		float t_wall_side = smoothstep(0.3, 0.7, wall_slope);
		// Side UV: U from the along-face horizontal axis, V from world Y so the
		// texture tiles both horizontally and vertically on wall sides.
		// X-facing wall (|normal.x|≈1): along-face axis is Z → U = world_Z
		// Z-facing wall (|normal.z|≈1): along-face axis is X → U = world_X
		float side_u = mix(v_world_xz.y, v_world_xz.x, abs(v_normal_world.z));
		vec2 uv_side = vec2(side_u, v_world_y) * uv_scale;
		base_col = mix(texture(wall_top_texture, uv_xz).rgb,
		               texture(wall_side_texture, uv_side).rgb, t_wall_side);
	} else if (t_side < 0.01 && t_top < 0.01) {
		// Pure flat grass — most common case
		base_col = texture(grass_texture, uv_grass).rgb;
	} else {
		base_col = texture(grass_texture, uv_grass).rgb;
		if (t_side > 0.01) {
			base_col = mix(base_col, texture(hill_side_texture, uv_xz).rgb, t_side);
		}
		if (t_top > 0.01) {
			base_col = mix(base_col, texture(hill_texture, uv_xz).rgb, t_top);
		}
	}

	if (!is_wall && ground_desat > 0.0) {
		base_col = mix(base_col, vec3(dot(base_col, vec3(0.299, 0.587, 0.114))) * 1.3, ground_desat);
	}
	if (!is_wall) {
		// Hill foot: a gentle darkening where the ground starts to rise grounds
		// the hill instead of it floating on the meadow.
		base_col *= 1.0 - 0.12 * smoothstep(0.0, 0.06, v_blend) * (1.0 - smoothstep(0.12, 0.35, v_blend));
		// Macro variation (GID-134 / TID-519): brightness swell, drier golden
		// patches and deeper, cooler lush hollows so a meadow isn't one green.
		base_col *= mix(0.82, 1.12, d0);
		base_col = mix(base_col, base_col * vec3(1.10, 1.02, 0.74), smoothstep(0.5, 0.75, d1) * 0.7);
		base_col = mix(base_col, base_col * vec3(0.80, 0.92, 0.88), smoothstep(0.42, 0.22, d1) * 0.6);
	}
	if (path_t > 0.001 && !is_path && !is_wall) {
		base_col = mix(base_col, texture(path_texture, uv_xz).rgb * path_tint / max(grass_tint, vec3(0.01)), path_t);
	}

	// Hand the base colour to Godot's lighting pipeline.
	// Override NORMAL from the height-field gradient (v_normal_world) so lighting
	// is always correct regardless of GPU 2D-winding.  Steep hill triangles can
	// have their projected winding flipped under isometric view, causing the GPU
	// to treat them as back-faces; overriding NORMAL here fixes that without
	// needing FRONT_FACING hacks or removing cull_disabled.
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(v_normal_world), 0.0)).xyz);

	// Biome color tint: walls use wall_tint, paths use path_tint, hills blend grass→hill.
	vec3 tint;
	if (is_path) {
		tint = path_tint;
	} else if (is_wall) {
		tint = wall_tint;
	} else {
		tint = mix(grass_tint, hill_tint, clamp(v_blend * 2.0, 0.0, 1.0));
	}
	vec3 tinted_col = base_col * tint;

	// Cracked walls: darker with a warm brownish shift to distinguish them subtly
	if (is_wall && v_cracked > 0.5) {
		tinted_col = vec3(tinted_col.r * 0.80 + 0.06, tinted_col.g * 0.65, tinted_col.b * 0.60);
	}

	// Wall & ruin detail (GID-134 / TID-521). v_blend runs 0 at a wall face's
	// foot to 1 at its top (TerrainMath.build_wall_face_mesh). Moss creeps up
	// from the base and in noisy patches, caps carry moss tufts, the foot sits
	// in a soft contact shadow and the top edge catches a little light.
	if (is_wall) {
		float side = smoothstep(0.3, 0.7, slope);
		// Noise in face space (along-face axis × height) so moss forms patches
		// on the bricks instead of diagonal streaks.
		float su = mix(v_world_xz.y, v_world_xz.x, abs(v_normal_world.z));
		float mn = mix(vnoise(v_world_xz * 0.8), vnoise(vec2(su * 0.9, v_world_y * 1.4)), side);
		float moss = side * clamp(smoothstep(0.45, 0.0, v_blend) * 0.9 + smoothstep(0.6, 0.78, mn) * 0.7, 0.0, 1.0);
		moss = max(moss, (1.0 - side) * smoothstep(0.55, 0.75, mn) * 0.75) * wall_moss;
		vec3 moss_col = vec3(0.36, 0.52, 0.20) * (0.8 + 0.4 * mn);
		tinted_col = mix(tinted_col * 1.3, moss_col, moss * 0.7);
		tinted_col *= mix(1.0, mix(0.6, 1.0, smoothstep(0.0, 0.3, v_blend)), side);
		tinted_col += side * smoothstep(0.9, 1.0, v_blend) * vec3(0.10, 0.09, 0.07);
	}

	// Blight tint: lerp toward a dark desaturated purple as blight_amount increases.
	if (blight_amount > 0.0) {
		float lum = dot(tinted_col, vec3(0.299, 0.587, 0.114));
		vec3 blight_col = vec3(lum * 0.35 + 0.05, lum * 0.15, lum * 0.30);
		tinted_col = mix(tinted_col, blight_col, blight_amount * 0.75);
	}

	// Wet ground: darker albedo, low roughness and more specular so the sun,
	// sky and lightning glint off it. Upward-facing ground holds the water (wall
	// faces barely darken); noise patches pool into glossier puddles. Uniform
	// branch — dry weather skips it entirely.
	float wet_rough = 0.9;
	float wet_spec = 0.1;
	if (terrain_wetness > 0.001) {
		float up = smoothstep(0.55, 0.95, v_normal_world.y);
		float wet = terrain_wetness * mix(0.25, 1.0, up);
		// Puddles stand in dips on level ground (TID-515), not on walls or hills.
		float level_ground = up * (1.0 - smoothstep(0.02, 0.1, v_blend)) * (is_wall ? 0.0 : 1.0);
		float puddle = puddle_mask(v_world_xz, v_dip, level_ground);
		tinted_col *= 1.0 - 0.35 * wet - 0.1 * puddle;
		// Standing water: darker, cooler, picks up a sky-grey sheen.
		tinted_col = mix(tinted_col, vec3(0.30, 0.37, 0.46), puddle * 0.5);
		wet_rough = mix(0.9, 0.35, wet);
		wet_rough = mix(wet_rough, 0.04, puddle);
		wet_spec = mix(0.1, 0.45, max(wet, puddle));
		if (puddle > 0.01) {
			vec2 rip = puddle_ripple(v_world_xz, TIME) * puddle * 0.35;
			vec3 n_world = normalize(vec3(-rip.x, 1.0, -rip.y));
			NORMAL = normalize((VIEW_MATRIX * vec4(mix(normalize(v_normal_world), n_world, puddle), 0.0)).xyz);
		}
	}

	// Streams and ponds (GID-134 / TID-524): level grass only, ragged banks, a
	// lighter shoreline, deeper colour mid-channel and drifting ripples that
	// catch the sky. Drawn after the wet block so standing water wins.
	if (v_water > 0.01 && !is_wall && !is_path) {
		float lg = smoothstep(0.55, 0.95, v_normal_world.y) * (1.0 - smoothstep(0.02, 0.1, v_blend));
		float water = smoothstep(0.16, 0.36, v_water + (vnoise(v_world_xz * 1.3) - 0.5) * 0.12) * lg;
		if (water > 0.001) {
			float deep = smoothstep(0.35, 0.9, v_water);
			vec2 wp = v_world_xz * 1.4 + vec2(TIME * 0.35, TIME * 0.2);
			float r0 = vnoise(wp);
			float rx = vnoise(wp + vec2(0.15, 0.0)) - r0;
			float rz = vnoise(wp + vec2(0.0, 0.15)) - r0;
			vec3 wcol = mix(vec3(0.24, 0.46, 0.48), vec3(0.10, 0.25, 0.36), deep) * (0.94 + r0 * 0.12);
			float shore = smoothstep(0.0, 0.3, water) * (1.0 - smoothstep(0.3, 0.75, water));
			tinted_col = mix(tinted_col, wcol, water * 0.9) + shore * vec3(0.10, 0.12, 0.10);
			wet_rough = mix(wet_rough, 0.06, water);
			wet_spec = mix(wet_spec, 0.6, water);
			vec3 wn = normalize(vec3(-rx * 2.5, 1.0, -rz * 2.5));
			NORMAL = normalize((VIEW_MATRIX * vec4(mix(normalize(v_normal_world), wn, water), 0.0)).xyz);
		}
	}

	ALBEDO = tinted_col * contact_shadow(vec3(v_world_xz.x, v_world_y, v_world_xz.y)) * cloud_shadow(v_world_xz);

	// Wall cutaway — see occlusion_focus. The camera is orthographic and locked
	// to (-1,-1,-1), so "between camera and player" is a cylinder along that axis.
	vec3 focus = occlusion_focus + vec3(0.0, 1.0, 0.0);
	vec3 rel = vec3(v_world_xz.x, v_world_y, v_world_xz.y) - focus;
	const vec3 CAM_FWD = vec3(-0.57735, -0.57735, -0.57735);
	float along = dot(rel, CAM_FWD);
	// Walls only: hills have no floor beneath them, so cutting one punches a
	// hole through to the clear colour.
	if (is_wall && along < -0.5 && v_world_y > occlusion_focus.y + 0.3) {
		float perp = length(rel - along * CAM_FWD);
		float cut = 1.0 - smoothstep(OCCLUSION_RADIUS * 0.65, OCCLUSION_RADIUS, perp);
		if (cut > 0.0) {
			// 4x4 Bayer screen-door; keeps ~20% of pixels as a ghost outline.
			ivec2 p = ivec2(FRAGCOORD.xy) & ivec2(3);
			int idx = p.x + p.y * 4;
			const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
				3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
			if ((BAYER[idx] + 0.5) / 16.0 < cut * 0.8) {
				discard;
			}
		}
	}

	// Soft emission floor keeps cast shadows from going pitch-black.
	// Keep low — this adds straight onto lit albedo, brightening midday too.
	vec3 base_emission = tinted_col * 0.08;
	// Ley line glow: a tight pale-teal core down the line's centre plus a faint
	// halo, so the whole (gameplay-wide) band doesn't wash the ground blue.
	if (v_ley > 0.01 && !is_wall) {
		float pulse = 0.8 + 0.2 * sin(TIME * 0.8);
		float core = smoothstep(0.6, 0.92, v_ley);
		float glow = core * 0.4 + v_ley * v_ley * 0.06;
		base_emission += glow * pulse * vec3(0.45, 0.95, 0.70);
	}
	EMISSION = base_emission;
	ROUGHNESS = wet_rough;
	METALLIC = 0.0;
	SPECULAR = wet_spec;
}
