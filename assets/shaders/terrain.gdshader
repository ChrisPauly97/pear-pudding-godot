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

// How many times the textures tile per world unit. 20/128: 20 texels per world
// unit, the character sprites' pixel density (PIXEL_SIZE 0.05), so the ground
// and the sprites on it read as one pixel-art style.
uniform float uv_scale : hint_range(0.05, 2.0) = 0.15625;
// Per-texel relief: every terrain tile carries a height map in ALPHA
// (tools/generate_hd_terrain.py); its one-texel gradient tilts the normal so
// bricks, flagstones, pebbles and grass tufts catch the sun. 0 = flat.
uniform float detail_bump : hint_range(0.0, 3.0) = 1.1;
const float TEX_RES = 128.0;  // terrain tile resolution (texels per tile)

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

varying float v_blend;      // height ratio [0=flat ground .. 1=hill plateau]
varying float v_wall;       // 1.0 if this vertex sits on a wall tile
varying float v_path;       // 1.0 if this vertex sits on a path tile
varying float v_cracked;    // 1.0 if this wall vertex is a TILE_CRACKED (cracked wall)
varying vec3  v_normal_world;  // world-space normal — used for slope detection only
varying vec2  v_world_xz;
varying float v_world_y;    // world Y — used for vertical tiling on wall sides

varying float v_d0;         // fbm noise channel 0, computed per-vertex
varying float v_d1;         // fbm noise channel 1, computed per-vertex
varying float v_ley;        // ley line intensity [0..1], baked into UV2.x per vertex
varying float v_dip;        // 0 low .. 1 high flat-ground jitter (TID-515 puddles)
varying float v_water;      // stream/pond intensity [0..1], baked into UV2.y (GID-134 / TID-524)
varying vec2  v_flow;       // stream current (dir × speed), baked into CUSTOM0.xy (TID-642); 0 = still

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

// Sample a terrain tile and its one-texel height (alpha) gradient.
// Returns rgb in .rgb; writes the (du, dv) height step to `grad`.
vec3 tile_sample(sampler2D tex, vec2 uv, out vec2 grad, out float h) {
	vec4 c = texture(tex, uv);
	h = c.a;
	grad = vec2(texture(tex, uv + vec2(1.0 / TEX_RES, 0.0)).a - c.a,
	            texture(tex, uv + vec2(0.0, 1.0 / TEX_RES)).a - c.a);
	return c.rgb;
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
	v_flow = CUSTOM0.xy;
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
	// Anti-tiling (TID-505): inside irregular noise blobs every ground layer
	// swaps to one of four rotated, offset copies of its tile, so the repeat
	// never lines up. A hard switch (not a blend) keeps the pixel art crisp.
	// tan_u / tan_v are the world directions of the sampled tile's +u / +v
	// axes (rows of the rotation), used to tilt the bump the same way.
	int rot = int(vnoise(v_world_xz * 0.23) > 0.5) + 2 * int(vnoise(v_world_xz * 0.17 + vec2(31.0, 7.0)) > 0.5);
	vec2 uv_ground = uv_xz;
	vec3 tan_u = vec3(1.0, 0.0, 0.0);
	vec3 tan_v = vec3(0.0, 0.0, 1.0);
	if (rot == 1) {
		uv_ground = vec2(-uv_xz.y, uv_xz.x) + vec2(0.37, 0.61);
		tan_u = vec3(0.0, 0.0, -1.0);
		tan_v = vec3(1.0, 0.0, 0.0);
	} else if (rot == 2) {
		uv_ground = -uv_xz + vec2(0.71, 0.13);
		tan_u = vec3(-1.0, 0.0, 0.0);
		tan_v = vec3(0.0, 0.0, -1.0);
	} else if (rot == 3) {
		uv_ground = vec2(uv_xz.y, -uv_xz.x) + vec2(0.19, 0.83);
		tan_u = vec3(0.0, 0.0, 1.0);
		tan_v = vec3(-1.0, 0.0, 0.0);
	}
	// Wall-side UV: U from the along-face horizontal axis, V from world Y so the
	// texture tiles both horizontally and vertically on wall sides.
	// X-facing wall (|normal.x|≈1): along-face axis is Z → U = world_Z
	// Z-facing wall (|normal.z|≈1): along-face axis is X → U = world_X
	float side_u = mix(v_world_xz.y, v_world_xz.x, abs(v_normal_world.z));
	vec2 uv_side = vec2(side_u, v_world_y) * uv_scale;

	vec2 hgrad = vec2(0.0);  // height step of the dominant tile
	float tex_h = 0.5;       // its height (0 = crevice/mortar, 1 = raised)
	vec2 g2;
	float h2;
	if (is_path) {
		base_col = tile_sample(path_texture, uv_ground, hgrad, tex_h);
	} else if (is_wall) {
		// Use surface normal to pick side vs top — no grass on wall tiles.
		// slope=0: flat top → wall_top_texture; slope=1: vertical face → wall_side_texture.
		float wall_slope = 1.0 - clamp(v_normal_world.y, 0.0, 1.0);
		float t_wall_side = smoothstep(0.3, 0.7, wall_slope);
		vec3 top_col = tile_sample(wall_top_texture, uv_ground, hgrad, tex_h);
		if (t_wall_side > 0.01) {
			vec3 side_col = tile_sample(wall_side_texture, uv_side, g2, h2);
			base_col = mix(top_col, side_col, t_wall_side);
			if (t_wall_side > 0.5) {
				hgrad = g2;
				tex_h = h2;
				tan_u = mix(vec3(0.0, 0.0, 1.0), vec3(1.0, 0.0, 0.0), abs(v_normal_world.z));
				tan_v = vec3(0.0, 1.0, 0.0);
			}
		} else {
			base_col = top_col;
		}
	} else {
		// Flat grass is the common case (~60-70% of terrain): one tile, no mixing.
		base_col = tile_sample(grass_texture, uv_ground, hgrad, tex_h);
		if (t_side > 0.01) {
			base_col = mix(base_col, tile_sample(hill_side_texture, uv_ground, g2, h2), t_side);
			if (t_side > 0.5) {
				hgrad = g2;
				tex_h = h2;
			}
		}
		if (t_top > 0.01) {
			base_col = mix(base_col, tile_sample(hill_texture, uv_ground, g2, h2), t_top);
			if (t_top > 0.5) {
				hgrad = g2;
				tex_h = h2;
			}
		}
	}
	// Detail normal: the height-field normal tilted by the tile's relief.
	vec3 n_geo = normalize(v_normal_world);
	vec3 n_detail = normalize(n_geo - detail_bump * (hgrad.x * tan_u + hgrad.y * tan_v));

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
		base_col = mix(base_col, texture(path_texture, uv_ground).rgb * path_tint / max(grass_tint, vec3(0.01)), path_t);
	}

	// Hand the base colour to Godot's lighting pipeline.
	// Override NORMAL from the height-field gradient (v_normal_world) so lighting
	// is always correct regardless of GPU 2D-winding.  Steep hill triangles can
	// have their projected winding flipped under isometric view, causing the GPU
	// to treat them as back-faces; overriding NORMAL here fixes that without
	// needing FRONT_FACING hacks or removing cull_disabled.
	NORMAL = normalize((VIEW_MATRIX * vec4(n_detail, 0.0)).xyz);

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
		// Moss is decided per texel of the tile under it (pixel-crisp, not a
		// smooth smear) and prefers the mortar and crevices (low tile height).
		vec2 texel = floor((side > 0.5 ? uv_side : uv_ground) * TEX_RES);
		vec2 tq = (texel + 0.5) / (TEX_RES * uv_scale);
		float mn = side > 0.5 ? vnoise(tq * vec2(0.9, 1.4)) : vnoise(tq * 0.8);
		float crevice = (0.45 - tex_h) * 0.35;
		float moss = side * (smoothstep(0.45, 0.0, v_blend) * 0.9 + smoothstep(0.6, 0.78, mn + crevice) * 0.7);
		moss = max(moss, (1.0 - side) * smoothstep(0.55, 0.75, mn + crevice) * 0.8);
		// Hard edge with only a little per-texel jitter, so moss grows in
		// clumps with ragged pixel borders rather than a salt-and-pepper speckle.
		float th = hash2(tq * 31.7 + vec2(side * 13.0));
		moss = step(0.5 + (th - 0.5) * 0.3, clamp(moss, 0.0, 1.0) * wall_moss);
		// Three moss tones picked per texel, lighter on raised stone.
		float tone = floor(fract(th * 11.3) * 3.0) / 2.0;
		vec3 moss_col = vec3(0.34, 0.50, 0.19) * (0.72 + 0.3 * tone + 0.25 * tex_h);
		tinted_col = mix(tinted_col * 1.3, moss_col, moss * 0.8);
		tinted_col *= mix(1.0, mix(0.6, 1.0, smoothstep(0.0, 0.3, v_blend)), side);
		tinted_col += side * smoothstep(0.9, 1.0, v_blend) * vec3(0.10, 0.09, 0.07);
	}

	// Blight tint: lerp toward a dark desaturated purple as blight_amount increases.
	if (blight_amount > 0.0) {
		float lum = dot(tinted_col, vec3(0.299, 0.587, 0.114));
		vec3 blight_col = vec3(lum * 0.35 + 0.05, lum * 0.15, lum * 0.30);
		tinted_col = mix(tinted_col, blight_col, blight_amount * 0.75);
	}

	// Water is pixel art like everything else: evaluated per world texel (the
	// ground's 20 texels/unit = the sprites' density), animated in stepped
	// frames, flat colour bands and blinking pixel glints — no smooth
	// specular sheen, which read as glossy 3-D against the pixel art.
	float px_per_unit = TEX_RES * uv_scale;
	vec2 wq = (floor(v_world_xz * px_per_unit) + 0.5) / px_per_unit;
	// Per-texel blink: each texel re-rolls a few times a second on its own phase.
	float blink = hash2(wq * 17.3 + floor(TIME * 3.0 + hash2(wq * 3.1) * 3.0));

	// Wet ground (rain): darker and slightly less rough; puddles in dips on
	// level ground (TID-515) as flat pixel water with rain glints.
	float wet_rough = 0.9;
	float wet_spec = 0.1;
	if (terrain_wetness > 0.001) {
		float up = smoothstep(0.55, 0.95, v_normal_world.y);
		float wet = terrain_wetness * mix(0.25, 1.0, up);
		float level_ground = up * (1.0 - smoothstep(0.02, 0.1, v_blend)) * (is_wall ? 0.0 : 1.0);
		float puddle = step(0.5, puddle_mask(wq, puddle_dip(wq), level_ground));
		tinted_col *= 1.0 - 0.3 * wet;
		tinted_col = mix(tinted_col, vec3(0.30, 0.37, 0.46), puddle * 0.7);
		tinted_col = mix(tinted_col, vec3(0.70, 0.78, 0.86), puddle * step(1.0 - 0.06 * terrain_rain, blink));
		wet_rough = mix(0.9, 0.6, wet);
		wet_spec = mix(0.1, 0.25, max(wet, puddle));
	}

	// Streams and ponds (GID-134 / TID-524): level grass only, ragged pixel
	// banks with a one-texel shoreline, three depth bands, drifting ripple
	// streaks and glints. Drawn after the wet block so standing water wins.
	if (v_water > 0.01 && !is_wall && !is_path) {
		float lg = step(0.75, v_normal_world.y) * step(v_blend, 0.06);
		float wv = v_water + (vnoise(wq * 1.3) - 0.5) * 0.12;
		if (lg > 0.5 && wv > 0.24) {
			float depth = wv - 0.24;
			vec3 wcol = depth < 0.2 ? vec3(0.20, 0.40, 0.43)
				: (depth < 0.45 ? vec3(0.14, 0.31, 0.40) : vec3(0.09, 0.22, 0.34));
			// Ripple streaks, stepped in time. Streams scroll them along the
			// baked current (TID-642) as a two-phase flow map: each layer drifts
			// for one cycle then resets while hidden, so the pattern never
			// smears out; still ponds keep a slow wind drift.
			float frame = floor(TIME * 4.0) / 4.0;
			float rip;
			float spd = length(v_flow);
			if (spd > 0.05) {
				const float CYCLE = 1.5;
				const float RIPPLE_SPEED = 1.5;  // world units / s at flow speed 1
				float ph0 = fract(frame / CYCLE);
				float ph1 = fract(frame / CYCLE + 0.5);
				vec2 w0 = wq - v_flow * ph0 * CYCLE * RIPPLE_SPEED;
				vec2 w1 = wq - v_flow * ph1 * CYCLE * RIPPLE_SPEED + vec2(17.3, 9.1);
				float r0 = vnoise(w0 * 1.8);
				float r1 = vnoise(w1 * 1.8);
				// Threshold each layer, then fade it by weight: a streak pops in or
				// out whole (pixel look) instead of the blend washing both out.
				float bl = abs(2.0 * ph0 - 1.0);
				float s0 = step(0.68, r0) * step(0.25, 1.0 - bl);
				float s1 = step(0.68, r1) * step(0.25, bl);
				rip = max(s0, s1);
			} else {
				rip = vnoise(wq * vec2(1.2, 3.0) + vec2(frame * 0.35, frame * 0.2));
			}
			wcol = mix(wcol, wcol * 1.3 + vec3(0.03), step(0.7, rip));
			wcol = mix(wcol, vec3(0.80, 0.90, 0.93), step(0.992, blink) * step(0.05, depth));
			// One-texel pale shoreline where the water meets the bank.
			// fwidth(v_water) is its change per screen pixel; a texel spans ~2.5.
			wcol = mix(wcol, vec3(0.48, 0.62, 0.58), step(depth, fwidth(v_water) * 2.5));
			tinted_col = wcol;
			wet_rough = 0.6;
			wet_spec = 0.2;
			NORMAL = normalize((VIEW_MATRIX * vec4(n_geo, 0.0)).xyz);
		}
	}

	ALBEDO = tinted_col * contact_shadow(vec3(v_world_xz.x, v_world_y, v_world_xz.y)) * cloud_shadow(v_world_xz);

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
