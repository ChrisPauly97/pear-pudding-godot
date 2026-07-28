shader_type canvas_item;
render_mode blend_disabled;

// Full-screen battle backdrop, seen from directly overhead — the board is a
// patch of ground the cards are laid out on, not a landscape behind them.
// Paints, in order:
//   1. the biome's terrain art tiled flat across the screen, sampled twice at
//      different scales and rotations so the 16x16 source never reads as a
//      repeating grid,
//   2. the biome's own scatter props, upright with a soft contact shadow,
//      thinned right down inside the play area so cards sit on clean ground,
//   3. a trodden arena — a rounded rectangle of worn earth under the board,
//      with the enemy/player divider drawn across it as a lit battle line,
//   4. a pool of biome-coloured light on the arena, a vignette, and a global
//      hold-back toward the old flat background colour.
// Every colour and shape parameter arrives as a uniform so BattleBackdrop.gd
// can drive the whole thing from the BiomeDef palettes and prop sets the 3-D
// world already uses — no new art, and nothing restated between the two.

uniform sampler2D ground_tex : source_color, filter_nearest, repeat_enable;
// The biome's two scatter props (BiomeDef.PROP_SETS). Each is drawn inside one
// grid cell, so these must not repeat.
uniform sampler2D prop_a_tex : source_color, filter_nearest, repeat_disable;
uniform sampler2D prop_b_tex : source_color, filter_nearest, repeat_disable;

uniform vec3 ground_tint = vec3(0.55, 0.70, 0.35);
// Mean colour of `ground_tex`, measured once on the CPU. Detail fades to this
// instead of to the texel soup a minified tile would otherwise sample.
uniform vec3 ground_avg = vec3(0.5);
// Bare, trodden earth: the arena floor and its worn rim.
uniform vec3 arena_tint = vec3(0.45, 0.38, 0.26);
// Colour of the light pooled on the arena, the battle line, and the faint
// overall cast. Warm sun, ember glow, cold moonlight — set per biome and
// per time of day.
uniform vec3 light_tint = vec3(1.00, 0.94, 0.72);
uniform vec3 dim_color = vec3(0.10, 0.10, 0.15);

// Tiles of ground art across one screen height.
uniform float ground_scale : hint_range(0.5, 24.0) = 9.0;
// How far the ground art is pulled to greyscale before `ground_tint` is
// applied. The terrain PNGs carry their own strong hue (the hill side is
// orange dirt), which would otherwise fight the biome tint — snow, for one,
// cannot be mixed out of orange. Desaturating first lets one source texture
// serve several biomes.
uniform float ground_desat : hint_range(0.0, 1.0) = 0.0;

// Scatter grid: cells across one screen height, the fraction of them that hold
// a prop, and prop height as a fraction of a cell. `prop_scale` must stay at
// or below 0.5 — that, plus the jitter bounds in fragment(), is what keeps a
// prop inside its own cell so one texture fetch can resolve the whole layer.
uniform float prop_cells : hint_range(2.0, 24.0) = 8.0;
uniform float prop_density : hint_range(0.0, 1.0) = 0.5;
uniform float prop_scale : hint_range(0.05, 0.5) = 0.42;
// Brightness the props are drawn at. Dropped after dark so they sit in the
// same light as the ground instead of floating over it.
uniform float prop_light : hint_range(0.0, 1.5) = 0.95;

// Arena rectangle, in UV: centre, half-extents, corner rounding.
uniform vec2 arena_center = vec2(0.43, 0.50);
uniform vec2 arena_half = vec2(0.395, 0.44);
uniform float arena_round : hint_range(0.0, 0.5) = 0.14;
// Screen-space y of the divider between the two halves of the board.
uniform float divider : hint_range(0.05, 0.95) = 0.38;

// 0 = day, 1 = night. Adds drifting motes; the ground is darkened CPU-side.
uniform float night : hint_range(0.0, 1.0) = 0.0;
// How far the finished image is pulled toward `dim_color`. The board is drawn
// on top, so the backdrop is deliberately held back for card legibility.
uniform float dim : hint_range(0.0, 1.0) = 0.42;
// Set to 0.0 to freeze the drifting motes / pulsing battle line, which makes a
// captured frame reproducible (used by the preview tool and by tests).
uniform float anim : hint_range(0.0, 1.0) = 1.0;

const vec3 LUMA = vec3(0.299, 0.587, 0.114);

// ── Noise (same value-noise shape as terrain.gdshader) ─────────────────────

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash2(i),                 hash2(i + vec2(1.0, 0.0)), f.x),
		mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

// Draws one scatter prop plus its contact shadow into `col`. `base` is where
// the prop meets the ground and `h` its height, both in square units; `fade`
// thins it out over the arena. Takes the sampler as a parameter because Godot
// shaders cannot select between two samplers with a ternary — the two call
// sites below are what pick which of the biome's sprites this cell holds.
void draw_prop(inout vec3 col, sampler2D tex, vec2 p, vec2 base, float h,
		float fade) {
	vec2 ts = vec2(textureSize(tex, 0));
	float w = h * (ts.x / max(ts.y, 1.0));   // keep the source's proportions

	// Contact shadow first, so the sprite sits on top of it.
	float sh = 1.0 - smoothstep(0.0, 1.0,
		length((p - base) / vec2(w * 0.55, h * 0.14)));
	col *= mix(1.0, 0.60, sh * fade);

	vec2 luv = vec2((p.x - base.x) / w + 0.5, (p.y - (base.y - h)) / h);
	if (luv.x < 0.0 || luv.x > 1.0 || luv.y < 0.0 || luv.y > 1.0) {
		return;
	}
	vec4 s = texture(tex, luv);
	// Knocked back toward the ground so props read as texture on the mat
	// rather than as clutter competing with the cards.
	col = mix(col, s.rgb * prop_light, s.a * 0.85 * fade);
}

// Signed distance to the arena's rounded rectangle. Negative inside.
float arena_sd(vec2 p, vec2 c, vec2 half_ext, float r) {
	vec2 q = abs(p - c) - half_ext + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	// SCREEN_PIXEL_SIZE is 1/viewport, so this stays correct through every
	// resize and orientation change with no CPU-side uniform to keep in sync.
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 uv = UV;
	// Square units: one unit is one screen height either way, so tiles and
	// props stay square and the scatter grid stays regular on any aspect.
	vec2 p = vec2(uv.x * aspect, uv.y);
	float t = anim * TIME;

	// ── Ground ─────────────────────────────────────────────────────────────
	vec2 g = p * ground_scale;
	vec3 tex = texture(ground_tex, g).rgb;
	tex = mix(tex, vec3(dot(tex, LUMA)), ground_desat);
	// The terrain PNGs ship without mipmaps; fade texel detail out once one
	// screen pixel covers a good part of a texel.
	float detail = 1.0 - smoothstep(0.06, 0.40, length(fwidth(g)));
	vec3 col = mix(ground_avg, tex, detail) * ground_tint;
	// Per-tile brightness jitter, then broad patches of light and shade. This
	// is what stops a 16x16 source laid flat from reading as a repeating grid.
	// Cross-fading a second, rotated sampling of the same tile was tried first
	// and is worse: on anything with strong seams — flagstones especially —
	// you see both grids at once and it reads as a bug, not as texture.
	col *= 0.93 + 0.14 * hash2(floor(g));
	col *= 0.86 + 0.28 * vnoise(p * 3.1);

	// ── Arena ──────────────────────────────────────────────────────────────
	vec2 ac = vec2(arena_center.x * aspect, arena_center.y);
	vec2 ah = vec2(arena_half.x * aspect, arena_half.y);
	float sd = arena_sd(p, ac, ah, min(ah.x, ah.y) * arena_round);
	// Ground worn bare where the fight happens. The falloff is deliberately
	// soft and wide — a crisp edge reads as a UI frame drawn over the ground
	// rather than as a patch of earth trodden flat, which is what a stroked
	// version of this looked like.
	// (smoothstep runs high-to-low because `sd` is negative inside the shape.)
	float inside = smoothstep(0.11, -0.07, sd);
	// Tinted toward bare earth *and* lifted a little: on a biome whose bare
	// earth is close to its ground colour (sand on sand) the tint alone does
	// nothing, and the arena has to read on every biome.
	col = mix(col, mix(col * 1.12, arena_tint, 0.45), inside * 0.80);
	// A churned band either side of the boundary, no brighter than the floor.
	col = mix(col, arena_tint * 0.80, smoothstep(0.06, 0.0, abs(sd)) * 0.25);

	// ── Props ──────────────────────────────────────────────────────────────
	// One cell test, one texture fetch: `prop_scale <= 0.5` plus the jitter
	// bounds below keep every prop wholly inside its own cell, so no
	// neighbour can ever reach this pixel. Thinned to a quarter inside the
	// arena — the board stays legible, the margins get dressed.
	float cs = 1.0 / prop_cells;
	vec2 ci = floor(p / cs);
	if (hash2(ci) < prop_density) {
		float h = cs * prop_scale * (0.70 + 0.55 * hash2(ci + 37.0));
		// x anywhere in the middle half, y in the lower half: the sprite grows
		// upward from its base, and the shadow sits just below it.
		vec2 base = (ci + vec2(0.25 + 0.50 * hash2(ci + 11.0),
			0.50 + 0.40 * hash2(ci + 23.0))) * cs;
		float fade = 1.0 - inside * 0.75;

		if (hash2(ci + 53.0) < 0.5) {
			draw_prop(col, prop_a_tex, p, base, h, fade);
		} else {
			draw_prop(col, prop_b_tex, p, base, h, fade);
		}
	}

	// ── Board lighting ─────────────────────────────────────────────────────
	// The divider between the enemy half and the player half, drawn as a line
	// scored into the earth: a thin core with a wide soft bloom, tapered off
	// at both ends so it does not stop dead like a UI rule.
	float dy = abs(uv.y - divider);
	float taper = 1.0 - smoothstep(0.55, 1.0, abs(p.x - ac.x) / ah.x);
	col += light_tint * inside * taper
		* (smoothstep(0.0035, 0.0, dy) * 0.20 + smoothstep(0.030, 0.0, dy) * 0.10)
		* (0.85 + 0.15 * sin(t * 1.1));
	// Light pooled over the board, brightest at its centre.
	col += light_tint * smoothstep(1.0, 0.0, length((p - ac) / (ah * 1.15))) * 0.13;
	// A faint cast of the same light over everything, which is most of what
	// separates a scorched battlefield from a snowfield at a glance.
	col *= mix(vec3(1.0), light_tint, 0.20);

	// Drifting motes after dark: sparse, slow, and only over the arena.
	if (night > 0.01) {
		vec2 mp = p * 26.0 + vec2(t * 0.05, sin(t * 0.15 + p.x * 3.0) * 0.20);
		vec2 mc = floor(mp);
		float m = step(0.992, hash2(mc)) * smoothstep(0.9, 0.2,
			length(fract(mp) - 0.5));
		col += light_tint * m * night * inside
			* (0.22 + 0.18 * sin(t * 2.2 + hash2(mc) * 30.0));
	}

	// Vignette, then the global hold-back that keeps card text legible. The
	// left and right edges are pulled down hard on purpose: the side panel's
	// turn/mana labels have no background of their own, and the darkened
	// margins are what they read against.
	float vig = smoothstep(0.22, 0.78, length((uv - vec2(0.5)) * vec2(0.90, 1.0)));
	col *= 1.0 - vig * 0.60;
	col = mix(col, dim_color, dim);

	COLOR = vec4(col, 1.0);
}
