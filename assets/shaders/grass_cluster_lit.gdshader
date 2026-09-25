shader_type spatial;
// Lit grass cluster (GID-131 / TID-508): High tier only, where sun shadows are on.
// Diffuse only, no specular; receives shadows. Everything else is shared with
// the unshaded grass_cluster.gdshader via the include.
render_mode cull_disabled, alpha_to_coverage, diffuse_lambert_wrap, specular_disabled;
#define GRASS_LIT

#include "res://assets/shaders/grass_cluster.gdshaderinc"
