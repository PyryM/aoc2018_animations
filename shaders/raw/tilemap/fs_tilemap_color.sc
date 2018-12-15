$input v_fgColor, v_bgColor, v_uv // in...

#include "common.sh"

SAMPLER2D(s_texCharmap, 2);

void main()
{
	vec4 color = texture2D(s_texCharmap, v_uv);
  if(color.a < 0.75){
    discard;
  }
	gl_FragColor = color;
}
