// Puddles in low areas (GID-133 / TID-515) — shared by terrain and grass so
// both agree exactly where water stands.
//
// Flat ground carries a vertex jitter (terrain.gdshader: +hash(xz × 0.08) ×
// 0.12). Low jitter = a dip, so puddles collect where the dip value and a slow
// noise field agree. `terrain_wetness` (ground wetness, dries slowly) sizes
// them; `terrain_rain` (is it raining now, 0..1) drives the pixel rain glints.
global uniform float terrain_wetness;
global uniform float terrain_rain;

float _pud_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float _pud_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(_pud_hash(i), _pud_hash(i + vec2(1.0, 0.0)), f.x),
			mix(_pud_hash(i + vec2(0.0, 1.0)), _pud_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// 0 (low) .. 1 (high) — the same value terrain.gdshader's flat-ground jitter uses.
float puddle_dip(vec2 xz) {
	return _pud_hash(xz * 0.08);
}

// 0..1 standing water at world `xz`; `level_ground` = 1 on level walkable ground.
float puddle_mask(vec2 xz, float dip, float level_ground) {
	if (terrain_wetness < 0.05 || level_ground < 0.01) {
		return 0.0;
	}
	float field = _pud_noise(xz * 0.16) * 0.55 + (1.0 - dip) * 0.45;
	// Wetter ground → the waterline rises and puddles spread.
	float line = mix(0.8, 0.68, terrain_wetness);
	return smoothstep(line, line + 0.05, field) * level_ground * smoothstep(0.3, 0.8, terrain_wetness);
}
