shader_type spatial;
// Lit grass tuft (GID-131 / TID-508): High tier only, where sun shadows are on.
// Diffuse only, no specular; receives shadows. Everything else is shared with
// the unshaded grass_tuft.gdshader via the include.
render_mode world_vertex_coords, cull_disabled, diffuse_lambert_wrap, specular_disabled;
#define GRASS_LIT

#include "res://assets/shaders/grass_tuft.gdshaderinc"
