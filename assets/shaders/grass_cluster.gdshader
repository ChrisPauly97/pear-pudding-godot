shader_type spatial;
// Billboard grass cluster shader.
// Each MultiMesh instance is a flat quad that rotates around Y to face the
// camera (billboard_fixed_y).  The fragment shader draws five tapered blade
// silhouettes across the UV space so a single quad looks like a small tuft of
// grass.  This gives cheap apparent density without individual blade geometry.
render_mode cull_disabled, alpha_to_coverage, unshaded;

#include "res://assets/shaders/grass_cluster.gdshaderinc"
