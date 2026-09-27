shader_type spatial;
// Billboard grass tuft: one camera-facing quad per tuft, drawn from the
// pixel-art atlas grass_tufts.png at the character sprites' pixel density.
// Replaces the old 7-vert 3-D blades + 5-spike cluster quads: 4 verts per tuft.
render_mode world_vertex_coords, cull_disabled, unshaded;

#include "res://assets/shaders/grass_tuft.gdshaderinc"
