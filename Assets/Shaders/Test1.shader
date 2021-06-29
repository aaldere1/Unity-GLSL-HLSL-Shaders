Shader "Unlit/Test1"
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

            //SHADERTOY SHADER

            float2 r2D(float2 p)
{
    return float2(frac(sin(dot(p, float2(92.51, 65.19)))*4981.32),
                frac(sin(dot(p, float2(23.34, 15.28)))*6981.32));
}

#define PI 3.141592

float polygon(float2 p, float s)
{
    float a = ceil(s*(atan2(-p.y, -p.x)/PI+1.)*.5);
    float n = 2.*PI/s;
    float t = n*a-n*.5;
    return lerp(dot(p, float2(cos(t), sin(t))), length(p), .3);
}

float voronoi(float2 p, float s)
{
    float2 i = floor(p*s);
    float2 current = i + frac(p*s);
    float min_dist = 1.;
    for (int y = -1; y <= 1; y++)
    {
        for (int x = -1; x <= 1; x++)
        {
            float2 neighbor = i + float2(x, y);
            float2 vPoint = r2D(neighbor);
            vPoint = 0.5 + 0.5*sin(_Time.y*.5 + 6.*vPoint);
            float dist = polygon(neighbor+vPoint - current, 3.);
            min_dist = min(min_dist, dist);
        }
    }
    return min_dist;
}



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
               float2 uv = i.uv*2.-1.;
    float2 e = float2(.01, .0);
    
    float s = 2.;
    float vor = 1.-voronoi(uv, s);
    float dx = 1.-voronoi(uv-e.xy, s);
    float dy = 1.-voronoi(uv-e.yx, s);
    dx = (dx-vor)/e.x;
    dy = (dy-vor)/e.x;
    
    float t = _Time.y;
    float3 n = normalize(float3(dx, dy, 1.));
    float3 lp = float3(cos(t), sin(t), .5)*2.;
    float3 ld = normalize(lp-float3(uv, 0.));
    float3 ed = normalize(float3(0., .0, 1.)-float3(uv, 0.));
    float3 hd = normalize(ld + ed);
    float sl = pow(max(dot(hd,n), 0.),4.);
    float oc = clamp(pow((vor), 2.), 0., 1.);
    float amb = (1.-vor)*.5;
    float diff = max(dot(n, ld), 0.)*.75;
    float l = oc*diff+amb+sl;
    
    float3 col = float3(0,0,0);
    
    col += l*tex2D(_MainTex, normalize(reflect(float3(0., .0, 1.), n))).rgb;

    return float4(col,1.0);
            }
            ENDCG
        }
    }
}
