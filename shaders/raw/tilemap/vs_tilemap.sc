$input a_position, a_texcoord0, a_texcoord1
$output v_fgColor, v_bgColor, v_uv

#include "common.sh"

SAMPLER2D(s_texIndex, 0);
SAMPLER2D(s_texColormap, 1);
uniform vec4 u_tileParams; 

void main() {
  ivec2 iDataPos = ivec2(a_texcoord0.xy);
  vec4 tileData = texelFetch(s_texIndex, iDataPos, 0);

  v_fgColor = texture2DLod(s_texColormap, vec2(tileData.z, 0.5), 0);
  v_bgColor = texture2DLod(s_texColormap, vec2(tileData.w, 0.5), 0);
  v_uv = (255.0 * tileData.xy * u_tileParams.xy) + (a_texcoord1 * u_tileParams.xy);

  gl_Position = mul(u_modelViewProj, vec4(a_position, 1.0));
}