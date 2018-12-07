$input v_fgColor, v_bgColor, v_uv // in...

#include "common.sh"

SAMPLER2D(s_texCharmap, 2);

void main()
{
	float alpha = texture2D(s_texCharmap, v_uv).x;
	gl_FragColor = v_bgColor*alpha + v_fgColor*(1.0 - alpha);
}
