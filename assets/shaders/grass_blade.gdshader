shader_type spatial;
// unshaded: blades cover a large share of screen pixels in grass biomes and
// per-pixel lighting (3 directional lights + shadow taps) was a dominant
// mobile GPU cost. Day/night response comes from grass_day_tint instead,
// written at 2 Hz by DayNightCycle.
render_mode cull_disabled, alpha_to_coverage, unshaded;

#include "res://assets/shaders/grass_blade.gdshaderinc"
