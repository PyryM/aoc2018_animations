$input v_wpos, v_wnormal, v_viewdir, v_uv

#include "common.sh"
#include "shaderlib.sh"

SAMPLER2D(s_lightMap, 0);
SAMPLER2D(s_noiseMap, 1);

uniform vec4 u_lightHeight; // x: light height
uniform vec4 u_mapScale;    //
uniform vec4 u_time;
uniform vec4 u_ambient;

// a lot of this is cobbled together from iq's "balls and occlusion"
// https://www.shadertoy.com/view/ldX3Ws
#define TRACE_ITERS 10
#define TRACE_DELTA 0.05
#define TRACE_ACCEL 1.1
#define eps 0.001
#define N_SAMPLES 36

vec2 hash2( float n )
{
    return fract(sin(vec2(n,n+1.0))*vec2(43758.5453123,22578.1459123));
}

vec3 hash3( float n )
{
    return fract(sin(vec3(n,n+1.0,n+2.0))*vec3(43758.5453123,22578.1459123,19642.3490423));
}

vec4 sample_plane_light( in vec3 ro, in vec3 rd )
{
    float t = (u_lightHeight.x - ro.y) / rd.y;
    if(t >= 0.0){
        vec2 planepos = (ro.xz + t*rd.xz) * u_mapScale.xy + u_mapScale.zw;
        return texture2D(s_lightMap, planepos);
    } else {
        return vec4(0.0, 0.0, 0.0, 1.0);
    }
}

vec4 sample_lighting(vec2 uv, vec3 pos, vec3 nor)
{
    vec4 total_light = vec4(0.0, 0.0, 0.0, 0.0);

    // see http://orbit.dtu.dk/fedora/objects/orbit:113874/datastreams/file_75b66578-222e-4c7d-abdf-f7e255100209/content
    // (link provided by nimitz)
    vec3 tc = vec3( 1.0+nor.z-nor.xy*nor.xy, -nor.x*nor.y)/(1.0+nor.z);
    vec3 uu = vec3( tc.x, tc.z, -nor.x );
   	vec3 vv = vec3( tc.z, tc.y, -nor.y );

    float off = texture2D(s_noiseMap, uv).x + u_time.x;
    //float off = random(uv);
    for(int j = 0; j < N_SAMPLES; ++j )
    {
        // This is blatantly stolen from iq's thing, so I'm not really sure what distribution
        // of sampling directions this produces
        vec2  aa = hash2( off + float(j)*203.1 ); // what is this multiplier about??
        float ra = sqrt(aa.y);
        float rx = ra*cos(6.2831*aa.x);
        float ry = ra*sin(6.2831*aa.x);
        float rz = sqrt( 1.0-aa.y );
        vec3  rr = vec3( rx*uu*0.5 + ry*vv*0.5 + rz*nor );
        rr /= length(rr);

        // I'm going to go ahead and weight according to dot(normal, rr) = rz on the assumption
        // that the above produces a uniform-ish distribution over the hemisphere
        total_light += sample_plane_light(pos, rr*TRACE_DELTA) * rz;
    }

    // this is not the "physically correct" normalization but :effort:
    total_light /= float(N_SAMPLES);
    return max(total_light * 1.0, 0.0);
}

void main()
{
    vec3 n = normalize(v_wnormal);
    vec4 lighting = sample_lighting(v_uv, v_wpos, n);
    float alpha = lighting.w;
    vec3 with_ambient = (u_ambient.xyz * (1.0 - alpha));
    // (lighting.xyz * alpha) + 

    //vec4 testo = texture2D(s_lightMap, v_uv);

    //gl_FragColor = testo;
    gl_FragColor = vec4(with_ambient, 1.0); //toGamma(vec4(with_ambient, 1.0));
    //gl_FragColor.a = u_time.y;
    //gl_FragColor = vec4(lighting, 1.0);
}
