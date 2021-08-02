// Original from: https://www.shadertoy.com/view/MdfGRr
Shader "Juliabulb"
{
    SubShader
    {
        Pass
        {
            CGPROGRAM
            #pragma vertex vertex_shader
            #pragma fragment pixel_shader
 
            typedef vector <float, 2> vec2;
            typedef vector <float, 3> vec3;
            typedef vector <float, 4> vec4;
            #define mix lerp
            #define iTime _Time.g
         
            vec2 isphere( in vec4 sph, in vec3 ro, in vec3 rd )
            {
                vec3 oc = ro - sph.xyz;
                float b = dot(oc,rd);
                float c = dot(oc,oc) - sph.w*sph.w;
                float h = b*b - c;
                if( h<0.0 ) return vec2(-1.0,-1.0);
                h = sqrt( h );
                return -b + vec2(-h,h);
            }
 
            float map( in vec3 p, in vec3 c, out vec4 resColor )
            {
                vec3 z = p;
                float m = dot(z,z);
                vec4 trap = vec4(abs(z),m);
                float dz = 1.0;
                for( int i=0; i<4; i++ )
                {
                    dz = 8.0*pow(m,3.5)*dz;
                    float r = length(z);
                    float b = 8.0*acos( clamp(z.y/r, -1.0, 1.0));
                    float a = 8.0*atan2( z.x, z.z );
                    z = c + pow(r,8.0) * vec3( sin(b)*sin(a), cos(b), sin(b)*cos(a) );
                    trap = min( trap, vec4(abs(z),m) );
                    m = dot(z,z);
                    if( m > 2.0 ) break;
                }
                resColor = trap;
                return 0.25*log(m)*sqrt(m)/dz;
            }
 
            float intersect( in vec3 ro, in vec3 rd, out vec4 rescol, float fov, vec3 c )
            {
                float res = -1.0;
                rescol = 0.0;
                vec2 dis = isphere( vec4( 0.0, 0.0, 0.0, 1.25 ), ro, rd );
                if( dis.y<0.0 ) return -1.0;
                dis.x = max( dis.x, 0.0 );
                vec4 trap;
                float fovfactor = 1.0/sqrt(1.0+fov*fov);
                float t = dis.x;
                for( int i=0; i<128; i++  )
                {
                    vec3 p = ro + rd*t;
                    float surface = clamp( 0.0015*t*fovfactor, 0.0001, 0.1 );
                    float dt = map( p, c, trap );
                    if( t>dis.y || dt<surface ) break;
                    t += dt;
                }
                if( t<dis.y )
                {
                    rescol = trap;
                    res = t;
                }
                return res;
            }
 
            float softshadow( in vec3 ro, in vec3 rd, float mint, float k, vec3 c )
            {
                float res = 1.0;
                float t = mint;
                for( int i=0; i<80; i++ )
                {
                    vec4 kk;
                    float h = map(ro + rd*t, c, kk);
                    res = min( res, k*h/t );
                    if( res<0.001 ) break;
                    t += clamp( h, 0.002, 0.1 );
                }
                return clamp( res, 0.0, 1.0 );
            }
 
            vec3 calcNormal( in vec3 pos, in float t, in float fovfactor, vec3 c )
            {
                vec4 tmp;
                float surface = clamp( 0.3 * 0.0015*t*fovfactor, 0.0001, 0.1 );
                vec2 eps = vec2( surface, 0.0 );
                return normalize( vec3(
                    map(pos+eps.xyy,c,tmp) - map(pos-eps.xyy,c,tmp),
                    map(pos+eps.yxy,c,tmp) - map(pos-eps.yxy,c,tmp),
                    map(pos+eps.yyx,c,tmp) - map(pos-eps.yyx,c,tmp) ) );
            }
         
            void vertex_shader (inout float4 vertex:POSITION,inout float2 uv:TEXCOORD0)
            {
                vertex = UnityObjectToClipPos(vertex);
            }
         
            float4 pixel_shader (float4 vertex:POSITION,float2 uv:TEXCOORD0) : SV_TARGET
            {
                vec2 p = 2.0*float2(2.0*uv.xy-1.0);
                float time = iTime*.15;
                vec3 light1 = vec3(  0.577, 0.577, -0.577 );
                vec3 light2 = vec3( -0.707, 0.000,  0.707 );
                float r = 1.3+0.1*cos(.29*time);
                vec3  ro = vec3( r*cos(.33*time), 0.8*r*sin(.37*time), r*sin(.31*time) );
                vec3  ta = vec3(0.0,0.1,0.0);
                float cr = 0.5*cos(0.1*time);
                float fov = 1.5;
                vec3 cw = normalize(ta-ro);
                vec3 cp = vec3(sin(cr), cos(cr),0.0);
                vec3 cu = normalize(cross(cw,cp));
                vec3 cv = normalize(cross(cu,cw));
                vec3 rd = normalize( p.x*cu + p.y*cv + fov*cw );
                vec3 cc = vec3( 0.9*cos(3.9+1.2*time)-.3, 0.8*cos(2.5+1.1*time), 0.8*cos(3.4+1.3*time) );
                if( length(cc)<0.50 ) cc=0.50*normalize(cc);
                if( length(cc)>0.95 ) cc=0.95*normalize(cc);
                vec3 col;
                vec4 tra;
                float t = intersect( ro, rd, tra, fov, cc );
                if( t<0.0 )
                {
                    col = 1.3*vec3(0.8,.95,1.0)*(0.7+0.3*rd.y);
                    col += vec3(0.8,0.7,0.5)*pow( clamp(dot(rd,light1),0.0,1.0), 32.0 );
                }
                else
                {
                    vec3 pos = ro + t*rd;
                    vec3 nor = calcNormal( pos, t, fov, cc );
                    vec3 hal = normalize( light1-rd);
                    vec3 ref = reflect( rd, nor );  
                    col = vec3(1.0,1.0,1.0)*0.3;
                    col = mix( col, vec3(0.7,0.3,0.3), sqrt(tra.x) );
                    col = mix( col, vec3(1.0,0.5,0.2), sqrt(tra.y) );
                    col = mix( col, vec3(1.0,1.0,1.0), tra.z );
                    col *= 0.4;  
                    float dif1 = clamp( dot( light1, nor ), 0.0, 1.0 );
                    float dif2 = clamp( 0.5 + 0.5*dot( light2, nor ), 0.0, 1.0 );
                    float occ = clamp(1.2*tra.w-0.6,0.0,1.0);
                    float sha = softshadow( pos,light1, 0.0001, 32.0, cc );
                    float fre = 0.04 + 0.96*pow( clamp(1.0-dot(-rd,nor),0.0,1.0), 5.0 );
                    float spe = pow( clamp(dot(nor,hal),0.0,1.0), 12.0 ) * dif1 * fre*8.0;  
                    vec3 lin  = 1.0*vec3(0.15,0.20,0.23)*(0.6+0.4*nor.y)*(0.1+0.9*occ);
                        lin += 4.0*vec3(1.00,0.90,0.60)*dif1*sha;
                        lin += 4.0*vec3(0.14,0.14,0.14)*dif2*occ;
                        lin += 2.0*vec3(1.00,1.00,1.00)*spe*sha * occ;
                        lin += 0.3*vec3(0.20,0.30,0.40)*(0.02+0.98*occ);
                    col *= lin;
                    col += spe*1.0*occ*sha;
                }
                col = sqrt( col );
                return vec4( col, 1.0 );
            }
            ENDCG
        }
    }
}