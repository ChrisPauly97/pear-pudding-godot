// Contact shadows (GID-131 / TID-503) — soft dark pools under characters,
// computed inside the terrain and grass shaders instead of as separate decal
// geometry. A floating quad kept losing to terrain vertex jitter and dense
// grass; darkening the surfaces themselves also shades the grass blades
// around a character's feet, which reads as grounded.
//
// ContactShadows.gd writes up to six casters per frame as
// vec4(world x, world y, world z, radius) — radius 0 = unused slot — plus one
// global opacity (lower when real sun shadows already ground the sprites).
global uniform vec4 contact_shadow_0;
global uniform vec4 contact_shadow_1;
global uniform vec4 contact_shadow_2;
global uniform vec4 contact_shadow_3;
global uniform vec4 contact_shadow_4;
global uniform vec4 contact_shadow_5;
global uniform float contact_shadow_opacity;

float _contact_one(vec4 c, vec3 p) {
	if (c.w <= 0.0) {
		return 1.0;
	}
	// A touch wider along world X/Z diagonal than a circle reads under the iso view.
	vec2 d = (p.xz - c.xz) / c.w;
	float fall = 1.0 - smoothstep(0.15, 1.0, dot(d, d));
	float near_y = 1.0 - smoothstep(0.4, 1.4, abs(p.y - c.y));
	return 1.0 - contact_shadow_opacity * fall * near_y;
}

// Drifting cloud shadows (GID-134 / TID-523). DayNightCycle writes the
// strength (0 at night and under full overcast) and a wind-driven offset that
// it accumulates on the CPU, so a wind change never jumps the pattern.
global uniform float cloud_shadow_strength;
global uniform vec2 cloud_offset;

float _cs_hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453);
}

float _cs_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(_cs_hash(i), _cs_hash(i + vec2(1.0, 0.0)), f.x),
			mix(_cs_hash(i + vec2(0.0, 1.0)), _cs_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Multiplier (≤ 1) for ground at world `xz` under the passing clouds.
float cloud_shadow(vec2 xz) {
	if (cloud_shadow_strength <= 0.001) {
		return 1.0;
	}
	vec2 p = (xz - cloud_offset) * 0.05;
	float n = _cs_noise(p) * 0.65 + _cs_noise(p * 2.3 + vec2(7.1, 3.7)) * 0.35;
	return 1.0 - cloud_shadow_strength * smoothstep(0.5, 0.66, n);
}

// Multiplier (≤ 1) for a surface at world position `p`.
float contact_shadow(vec3 p) {
	return _contact_one(contact_shadow_0, p) * _contact_one(contact_shadow_1, p)
			* _contact_one(contact_shadow_2, p) * _contact_one(contact_shadow_3, p)
			* _contact_one(contact_shadow_4, p) * _contact_one(contact_shadow_5, p);
}
