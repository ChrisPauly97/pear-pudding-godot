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

// Multiplier (≤ 1) for a surface at world position `p`.
float contact_shadow(vec3 p) {
	return _contact_one(contact_shadow_0, p) * _contact_one(contact_shadow_1, p)
			* _contact_one(contact_shadow_2, p) * _contact_one(contact_shadow_3, p)
			* _contact_one(contact_shadow_4, p) * _contact_one(contact_shadow_5, p);
}
