shader_type canvas_item;
render_mode blend_disabled;

// Full-screen battle backdrop. Paints, top to bottom:
//   1. a graded sky (day or night) with drifting cloud banks, stars and a
//      sun/moon disc,
//   2. two parallax ridge silhouettes cut out of 1-D fbm,
//   3. a line of the biome's own scatter props standing on the skyline,
//   4. a ground plane tiled from the game's 16x16 terrain pixel art, laid into
//      a shallow perspective and hazed out toward the horizon.
// Every colour and shape parameter arrives as a uniform so BattleBackdrop.gd
// can drive the whole thing from the BiomeDef palettes and prop sets the 3-D
// world already uses — no new art, and nothing restated between the two.
//
// The horizon sits on the BattleScene divider (anchor 0.38), so the seam
// between the enemy half and the player half reads as the skyline.

uniform sampler2D ground_tex : source_color, filter_nearest, repeat_enable;
// The biome's two scatter props (BiomeDef.PROP_SETS), silhouetted along the
// skyline. Sampled inside one quad each, so these must not repeat.
uniform sampler2D prop_a_tex : source_color, filter_nearest, repeat_disable;
uniform sampler2D prop_b_tex : source_color, filter_nearest, repeat_disable;

uniform vec3 sky_top     = vec3(0.07, 0.09, 0.20);
uniform vec3 sky_horizon = vec3(0.35, 0.31, 0.42);
uniform vec3 ridge_far   = vec3(0.30, 0.34, 0.40);
uniform vec3 ridge_near  = vec3(0.16, 0.18, 0.24);
uniform vec3 ground_tint = vec3(0.55, 0.70, 0.35);
// Mean colour of `ground_tex`, measured once on the CPU. The far field fades
// to this instead of to the texel soup it would otherwise sample.
uniform vec3 ground_avg = vec3(0.5);
uniform vec3 glow_tint   = vec3(1.00, 0.85, 0.45);

// Screen-space y of the skyline. Matches BattleScene's Divider anchor.
uniform float horizon : hint_range(0.05, 0.95) = 0.38;
// Silhouette height as a fraction of screen height, its horizontal frequency,
// and how far it is pushed from rolling hills (0) toward sharp peaks (1).
uniform float ridge_amp : hint_range(0.0, 0.30) = 0.07;
uniform float ridge_jag : hint_range(0.5, 8.0) = 2.0;
uniform float ridge_sharp : hint_range(0.0, 1.0) = 0.5;
// Height of the tallest skyline prop, as a fraction of screen height.
// 0 removes the prop line entirely.
uniform float prop_h : hint_range(0.0, 0.15) = 0.030;
// How much of the ground plane one screen width spans at the near edge —
// larger tiles the terrain art more finely.
uniform float ground_scale : hint_range(0.5, 12.0) = 4.0;
// How far the ground art is pulled to greyscale before `ground_tint` is
// applied. The terrain PNGs carry their own strong hue (the hill side is
// orange dirt), which would otherwise fight the biome tint — snow, for one,
// cannot be mixed out of orange. Desaturating first lets one source texture
// serve several biomes.
uniform float ground_desat : hint_range(0.0, 1.0) = 0.0;
// 0 = midday, 1 = night. Swaps the celestial body's colour and reveals stars.
uniform float night : hint_range(0.0, 1.0) = 0.0;
// Sun/moon opacity. Dungeons and other roofed battlefields set this to 0 —
// they still want the graded vault and the silhouettes, just no sky object.
uniform float celestial : hint_range(0.0, 1.0) = 1.0;
// How far the finished image is pulled toward `dim_color`. The board is drawn
// on top, so the backdrop is deliberately held back for card legibility.
uniform float dim : hint_range(0.0, 1.0) = 0.42;
uniform vec3 dim_color = vec3(0.10, 0.10, 0.15);
// Set to 0.0 to freeze the drifting clouds / pulsing seam, which makes a
// captured frame reproducible (used by the preview tool and by tests).
uniform float anim : hint_range(0.0, 1.0) = 1.0;

// ── Noise (same value-noise/fbm shape as terrain.gdshader) ──────────────────

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

// Three octaves — enough shape for a skyline, cheap enough to run full-screen
// on mobile. Only ever evaluated above the horizon (see fragment()).
float fbm(vec2 p) {
	float v = 0.5 * vnoise(p);
	p = p * 2.1 + vec2(1.7, 3.1);
	v += 0.25 * vnoise(p);
	p = p * 2.3 + vec2(5.3, 1.9);
	v += 0.125 * vnoise(p);
	return v / 0.875;
}

// Skyline height profile in [0,1]. `sharp` folds the noise about its midpoint,
// turning rolling dunes into the jagged spires the scorched and mountain
// biomes want.
float ridge_profile(float x, float sharp) {
	float n = fbm(vec2(x, 0.5));
	return mix(n, 1.0 - abs(2.0 * n - 1.0), sharp);
}

// Draws one prop, standing on the skyline, into `col`. `cx` is the prop's
// centre in UV x, `h` its height in UV y. Only the alpha is read — props are
// rendered as flat silhouettes, not lit sprites.
void draw_prop(inout vec3 col, sampler2D tex, vec2 uv, float aspect, float cx,
		float h, vec3 tint) {
	vec2 ts = vec2(textureSize(tex, 0));
	float w = h * (ts.x / max(ts.y, 1.0)) / aspect;   // keep the source square
	vec2 luv = vec2((uv.x - cx) / w + 0.5, (uv.y - (horizon - h)) / h);
	if (luv.x < 0.0 || luv.x > 1.0 || luv.y < 0.0 || luv.y > 1.0) {
		return;
	}
	col = mix(col, tint, texture(tex, luv).a);
}

void fragment() {
	// SCREEN_PIXEL_SIZE is 1/viewport, so this stays correct through every
	// resize and orientation change with no CPU-side uniform to keep in sync.
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 uv = UV;
	float t = anim * TIME;
	vec3 col;

	if (uv.y < horizon) {
		// ── Sky ────────────────────────────────────────────────────────────
		float s = clamp(uv.y / max(horizon, 0.001), 0.0, 1.0);
		col = mix(sky_top, sky_horizon, pow(s, 1.5));

		// Stars: a sparse hash lattice that fades out toward the horizon glow.
		if (night > 0.01) {
			vec2 cell = floor(uv * vec2(260.0 * aspect, 260.0));
			float star = step(0.9965, hash2(cell));
			float twinkle = 0.65 + 0.35 * sin(t * 1.7 + hash2(cell + 7.0) * 30.0);
			col += vec3(0.85, 0.88, 1.0) * star * twinkle * night * (1.0 - s * s);
		}

		// Sun / moon, low over the right shoulder of the board.
		vec2 cpos = vec2(0.74, horizon * 0.34);
		float cd = length((uv - cpos) * vec2(aspect, 1.0));
		vec3 cel = mix(vec3(1.0, 0.93, 0.72), vec3(0.86, 0.90, 1.0), night);
		col += cel * celestial
			* (smoothstep(0.042, 0.030, cd) + smoothstep(0.22, 0.0, cd) * 0.30);

		// Cloud banks drifting sideways, thickest around mid-sky.
		float cl = fbm(vec2(uv.x * 2.6 * aspect + t * 0.012, uv.y * 7.0));
		float band = smoothstep(0.05, 0.45, s) * (1.0 - smoothstep(0.55, 1.0, s));
		col = mix(col, mix(sky_horizon, cel, 0.25), smoothstep(0.52, 0.92, cl) * band * 0.55);

		// ── Ridges ─────────────────────────────────────────────────────────
		// Two silhouettes: a tall hazy range behind, a shorter dark one in
		// front. Both are clipped by the horizon, so they only cost work in
		// the band just above it.
		if (uv.y > horizon - ridge_amp * 1.7) {
			float y_far = horizon - ridge_amp * 1.5
				* (0.15 + 0.85 * ridge_profile(uv.x * ridge_jag * 3.0 + 11.0, ridge_sharp));
			float y_near = horizon - ridge_amp * 0.75
				* (0.15 + 0.85 * ridge_profile(uv.x * ridge_jag * 1.7 + 41.0, ridge_sharp * 0.6));
			// A hair of feathering keeps the silhouette edge from crawling.
			float e = 0.0022;
			col = mix(col, mix(ridge_far, sky_horizon, 0.45),
				smoothstep(y_far - e, y_far + e, uv.y));
			col = mix(col, mix(ridge_near, sky_horizon, 0.15),
				smoothstep(y_near - e, y_near + e, uv.y));
		}

		// ── Skyline props ──────────────────────────────────────────────────
		// One cell per slot across the width; roughly two thirds are occupied,
		// each with a jittered position, height and choice of the biome's two
		// prop sprites. Nearest-neighbour sampling keeps them pixel-crisp.
		if (prop_h > 0.0 && uv.y > horizon - prop_h * 1.6) {
			float cells = 30.0;
			float ci = floor(uv.x * cells);
			// Neighbouring cells can overlap this one, so test three.
			for (float k = -1.0; k <= 1.0; k += 1.0) {
				float i = ci + k;
				float r = hash2(vec2(i, 3.0));
				if (r < 0.34) {
					continue;
				}
				float h = prop_h * (0.55 + 0.85 * hash2(vec2(i, 9.0)));
				float cx = (i + 0.12 + 0.76 * hash2(vec2(i, 17.0))) / cells;
				vec3 tint = mix(ridge_near * 0.55, sky_horizon, 0.10);
				if (hash2(vec2(i, 23.0)) < 0.5) {
					draw_prop(col, prop_a_tex, uv, aspect, cx, h, tint);
				} else {
					draw_prop(col, prop_b_tex, uv, aspect, cx, h, tint);
				}
			}
		}
	} else {
		// ── Ground ─────────────────────────────────────────────────────────
		// g: 0 at the horizon, 1 at the bottom of the screen.
		float g = (uv.y - horizon) / max(1.0 - horizon, 0.001);
		// Shallow reciprocal depth ramp. Clamped well short of the vanishing
		// point, so the plane reads as receding ground rather than a corridor.
		float depth = min(1.0 / (g * 2.6 + 0.14), 7.0);
		// The +5.5 offset keeps the u wrap seam away from the board's centre.
		vec2 guv = vec2((uv.x - 0.5) * aspect * depth + 5.5, depth) * ground_scale;
		vec3 tex = texture(ground_tex, guv).rgb;
		tex = mix(tex, vec3(dot(tex, vec3(0.299, 0.587, 0.114))), ground_desat);

		// The terrain PNGs ship without mipmaps, so fade the texel detail out
		// once one screen pixel covers a good part of a texel. This is what
		// stops the far field from shimmering.
		float detail = 1.0 - smoothstep(0.06, 0.40, length(fwidth(guv)));
		col = mix(ground_avg, tex, detail) * ground_tint;
		// Broad patches of light and shade, so a large flat biome (a meadow,
		// a salt flat) does not read as one solid slab of colour. One noise
		// octave — this branch covers most of the screen.
		col *= 0.80 + 0.40 * vnoise(guv * 0.10);

		// Distance haze at the skyline, and a darker foreground so the
		// player's hand reads against it.
		col = mix(col, mix(sky_horizon, ridge_near, 0.60),
			1.0 - smoothstep(0.0, 0.08, g));
		col *= mix(1.0, 0.60, smoothstep(0.10, 1.0, g));
	}

	// ── Board lighting ─────────────────────────────────────────────────────
	// A soft pool of light centred on the board (left of the side panel) plus
	// a warm seam along the skyline, which doubles as the divider.
	vec2 p = (uv - vec2(0.43, horizon)) * vec2(1.0, 2.0);
	col += glow_tint * smoothstep(0.60, 0.0, length(p)) * 0.09;
	col += glow_tint * smoothstep(0.010, 0.0, abs(uv.y - horizon))
		* (0.10 + 0.05 * sin(t * 1.1));

	// Vignette, then the global hold-back that keeps card text legible. The
	// left and right edges are pulled down hard on purpose: the side panel's
	// turn/mana labels have no background of their own, and the darkened
	// margins are what they read against.
	float vig = smoothstep(0.22, 0.78, length((uv - vec2(0.5)) * vec2(0.90, 1.0)));
	col *= 1.0 - vig * 0.60;
	col = mix(col, dim_color, dim);

	COLOR = vec4(col, 1.0);
}
