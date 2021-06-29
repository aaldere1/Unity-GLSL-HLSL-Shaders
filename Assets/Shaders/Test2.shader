Shader "Unlit/Test2"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            // divergence-free variant of https://shadertoy.com/view/wstyzl
// variant of https://shadertoy.com/view/tsdcRj

// - Introduce transfer function ( i.e. LUT(dens) ) to shape the look (much like doctors do for scan data)
// - Rely on preintegrated density on segment.
//     inspired by preintegrated segment rendering ( see http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.10.3079&rep=rep1&type=pdf )
//     NB: they store a small tex2D(_dens,dens), but here I do it analytically.

#define noise(x) tex2D(iChannel0, x ).xyz
#define SQR(x)   ( (x)*(x) )
#define CUB(x)   ( (x)*(x)*(x) )

float3 divfreenoise( float3 q ) { // fluid-like noise = div-free -> curl
    float2 e = float2(1./16.,0);
 // q += .1*iTime;            // animated flow
    float3 v = noise(q); 
 // return v -.5;             // regular
    return float3( noise(q+e.yxy).z-v.z - v.y+noise(q+e.yyx).y, // curl
                 noise(q+e.yyx).x-v.x - v.z+noise(q+e.xyy).z,
                 noise(q+e.xyy).y-v.y - v.x+noise(q+e.yxy).x
                ) *1.;
}
             
float z, BR = 2.2;   // bounding sphere (0,0,0), 2.
float map(float3 p )
{
    float3 q = p;
 // float3 N = 2.* noise(q/10.) -1.;                // displacement
    float3 N = 2.* divfreenoise(q/10.);
    q += .5*N;
    float f = ( 1.2*noise(q/2.+ .1*iTime).x -.2 ) // source noise
              * smoothstep(1.,.8,length(q)/2.);   // source sphere

    f*= smoothstep(.1,.2,abs(p.x));               // empty slice (derivable ) 
    z = length(q)/2.;                             // depth in sphere
    return f;                        
}

float3 sundir = normalize( float3(0,0,-1) );
float2 coord;

  #define sl  5.                               // transition slope transp/opaque
  #define LUT(d) clamp( .5+sl*(d-.5), 0., 1. ) // transfer function

                                               // integral of transfer function
  #define intLUT(d0,d1) ( abs(d1-d0)<1e-5 ? 0. : ( I(d1) - I(d0) ) / (d1-d0) ) 
  #define C(d)    clamp( d, .5-.5/sl, .5+.5/sl )
  #define I0(d) ( .5*d + sl*SQR(d-.5)/2. )
  #define I(d)  ( I0(C(d)) + max(0.,d-(.5+.5/sl)) )

float LUTs( float _d, float d ) { // apply either the simple or integrated transfer function
    return intLUT(_d,d);
/*  return coord.x > 0. 
             ?  LUT(d)        // right: just apply transfert function
             :  intLUT(_d,d); // left: preintegrated transfert function
*/
}

float intersect_sphere( float3 O, float3 D, float3 C, float r )
{
	float b = dot( O-=C, D ),
	      h = b*b - dot( O, O ) + r*r;
	return h < 0. ? -1.             // no intersection
	              : -b - sqrt(h);
}

float4 raymarch( float3 ro, float3 rd, float3 bgcol, ifloat2 px )
{
	float4 sum = 0;
	float dt = .01,
         den = 0., _den, lut,
           t = intersect_sphere( ro, rd, float3(0), BR );
    if ( t == -1. ) return float4(0); // the ray misses the object 
    t += 1e-5;                      // start on bounding sphere
    
    for(int i=0; i<500; i++) {
        float3 pos = ro + t*rd;
        if(   sum.a > .99               // end if opaque or...
           || length(pos) > BR ) break; // ... exit bounding sphere
                                    // --- compute deltaInt-density
        _den = den; den = map(pos); // raw density
        float _z = z;               // depth in object
        lut = LUTs( _den, den );    // shaped through transfer function
        if( lut > .0                // optim
          ) {                       // --- compute shading                  
#if 0                               // finite differences
            float2 e = float2(.3,0);
            float3 n = normalize( float3( map(pos+e.xyy) - den,
                                      map(pos+e.yxy) - den,
                                      map(pos+e.yyx) - den ) );
         // see also: centered tetrahedron difference: https://www.iquilezles.org/www/articles/normalsSDF/normalsSDF.htm
            float dif = clamp( -dot(n, sundir), 0., 1.);
#else                               // directional difference https://www.iquilezles.org/www/articles/derivative/derivative.htm
         // float dif = clamp((lut - LUTs(_den, map(pos+.3*sundir)))/.6, 0., 1. ); // pseudo-diffuse using 1D finite difference in light direction 
            float dif = clamp((den - map(pos+.3*sundir))/.6, 0., 1. );             // variant: use raw density field to evaluate diffuse
#endif
/*
            float3  lin = float3(.65,.7,.75)*1.4 + float3(1,.6,.3)*dif,          // ambiant + diffuse
                  col = float3(.2 + dif);
            col = lerp( col , bgcol, 1.-exp(-.003*t*t) );   // fog
*/            
            float3 col = exp(- float3(3,3,2) *(1.-z));     // dark with shadow
         // float3 col =   exp(- float3(3,3,2) *(.8-_z));  // dark with depth
                   //      *  exp(- 1.5 *(1.-z));
            sum += (1.-sum.a) * float4(col,1)* (lut* dt*5.); // --- blend. Original was improperly just den*.4;
        }
        t += dt;  // stepping
    }

    return sum; 
}

float3x3 setCamera( float3 ro, float3 ta, float cr )
{
	float3 cw = normalize(ta-ro),
	     cp = float3(sin(cr), cos(cr),0),
	     cu = normalize( cross(cw,cp) ),
	     cv = cross(cu,cw);
    return float3x3( cu, cv, cw );
}

float4 render( float3 ro, float3 rd, ifloat2 px )
{
    // background sky  
	float sun = max( dot(sundir,rd), 0. );
	float3 col = // float3(.6,.71,.75) - rd.y*.2*float3(1,.5,1) + .15*.5
	           //  + .2*float3(1,.6,.1)*pow( sun, 8. );
            +  float3( .8 * pow( sun, 8. ) ); // dark variant

    // clouds    
    float4 res = raymarch( ro, rd, col, px );  // render clouds
    col = res.rgb + col*(1.-res.a);          // blend sky
    
    // sun glare    
	col += .2*float3(1,.4,.2) * pow( sun,3.);

    return float4( col, 1. );
}



#define mainVR(O,U,C,D) O = render( C, D, ifloat2(U-.5) )

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                  float2 R = iResolution.xy,
         p = ( 2.*U - R ) / R.y,
         m = iMouse.z>0. ? 2.* iMouse.xy / R.xy
                         : 1.+cos(.3*iTime+float2(0,11));
    coord = p;
 // O = float4( map(float3(4.*p,0)) ); return;
    
    // camera
    float3 ro = 4.*normalize(float3(sin(3.*m.x), .4*m.y, cos(3.*m.x))),
	     ta = float3(0, 0, 0);
    float3x3 ca = setCamera( ro, ta, 0. );
    // ray
    float3 rd = ca * normalize( float3(p,1.5) );
    
    O = render( ro, rd, ifloat2(U-.5) );
 // if (floor(U.x)==floor(R.x/2.)) O = float4(1,0,0,1); // red separator
            }
            ENDCG
        }
    }
}
