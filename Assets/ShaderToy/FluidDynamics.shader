//original source: https://www.shadertoy.com/view/MsGSRd
//translated from GLSL to CG by P.Z.
Shader "Fluid dynamics"
{
    Properties
    {
        MainTex ("Texture", 2D) = "black" {}
    }
    Subshader
    {  
        Pass
        {
            CGPROGRAM
            #pragma vertex vertex_shader
            #pragma fragment pixel_shader
            #pragma target 3.0
 
            struct type
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
            };
               
            sampler2D MainTex;
           
            type vertex_shader (float4 vertex:POSITION, float2 uv:TEXCOORD0)
            {
                type vs;
                vs.vertex = UnityObjectToClipPos (vertex);
                vs.uv = uv;
                return vs;
            }
 
            float4 pixel_shader (type ps) : SV_TARGET
            {
                float2 iResolution=float2(1024,1024); //texture resolution
                float2 f = ps.uv*iResolution;  //fragCoord
                float2 b = float2(0.31,0.95);
                float2 v = float2(0.0,0.0);
                float4 c = float4(0,0,0,1);   //initial color
                for(int l=0;l<20;l++)
                {
                    if ( dot(b,b) > pow(iResolution.y,2.0) ) break;
                    float2 p = b;
                    for(int i=0;i<5;i++)
                    {        
                        float2 pos = f+p;
                        float rot=0.0;
                        for(int i=0;i<5;i++)
                        {
                            rot+=dot(tex2Dlod(MainTex,float4(frac((pos+p)/iResolution.xy),0,0)  ).xy-float2(0.5,0.5),mul(float2(1,-1),p.yx));
                            p=float2(0.31*p.x+0.95*p.y,-0.95*p.x+0.31*p.y);
                        }
                        v+=p.yx* rot/5.0/dot(b,b);    
                        p=float2(0.31*p.x+0.95*p.y,-0.95*p.x+0.31*p.y);
                    }
                    b*=2.0;
                }  
                float4 color=tex2Dlod(MainTex,float4(frac((f+v*float2(-2,2))/iResolution.xy),0,0));
                float2 s=(f.xy/iResolution.xy)*2.0-float2(1.0,1.0);
                color.xy += (0.01*s.xy / (dot(s,s)/0.1+0.3));
                c = color;
                return c;
            }
            ENDCG
        }
    }
}