
Shader "ShaderMan/Voronoise"
	{

	Properties{
	_iMouse ("iMouse", Vector) = (0,0,0,0)
	}

	SubShader
	{
	Tags { "RenderType" = "Transparent" "Queue" = "Transparent" }

	Pass
	{
	ZWrite Off
	Blend SrcAlpha OneMinusSrcAlpha

	CGPROGRAM
	#pragma vertex vert
	#pragma fragment frag
	#include "UnityCG.cginc"

	struct VertexInput {
    fixed4 vertex : POSITION;
	fixed2 uv:TEXCOORD0;
    fixed4 tangent : TANGENT;
    fixed3 normal : NORMAL;
	//VertexInput
	};


	struct VertexOutput {
	fixed4 pos : SV_POSITION;
	fixed2 uv:TEXCOORD0;
	//VertexOutput
	};

	//Variables
float4 _iMouse;

	fixed3 hash3( fixed2 p )
{
    fixed3 q = fixed3( dot(p,fixed2(127.1,311.7)), 
				   dot(p,fixed2(269.5,183.3)), 
				   dot(p,fixed2(419.2,371.9)) );
	return frac(sin(q)*43758.5453);
}

fixed voronoise( in fixed2 p, fixed u, fixed v )
{
	fixed k = 1.0+63.0*pow(1.0-v,6.0);

    fixed2 i = floor(p);
    fixed2 f = frac(p);
    
	fixed2 a = fixed2(0.0,0.0);
    [unroll(100)]
for( int y=-2; y<=2; y++ )
    [unroll(100)]
for( int x=-2; x<=2; x++ )
    {
        fixed2  g = fixed2( x, y );
		fixed3  o = hash3( i + g )*fixed3(u,u,1.0);
		fixed2  d = g - f + o.xy;
		fixed w = pow( 1.0-smoothstep(0.0,1.414,length(d)), k );
		a += fixed2(o.z*w,w);
    }
	
    return a.x/a.y;
}





	VertexOutput vert (VertexInput v)
	{
	VertexOutput o;
	o.pos = UnityObjectToClipPos (v.vertex);
	o.uv = v.uv;
	//VertexFactory
	return o;
	}
	fixed4 frag(VertexOutput i) : SV_Target
	{
	
	fixed2 uv = i.uv / 1;

    fixed2 p = 0.5 - 0.5*cos( _Time.y*fixed2(1.0,0.5) );
    
	if( _iMouse.w>0.001 ) p = fixed2(0.0,1.0) + fixed2(1.0,-1.0)*_iMouse.xy/1;
	
	p = p*p*(3.0-2.0*p);
	p = p*p*(3.0-2.0*p);
	p = p*p*(3.0-2.0*p);
	
	fixed f = voronoise( 24.0*uv, p.x, p.y );
	
	return fixed4( f, f, f, 1.0 );

	}
	ENDCG
	}
  }
}

