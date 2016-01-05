Shader "Hidden/ImageEffects/FluidBlur" {
	Properties {
		_MainTex     ("-", 2D) = "" {}
		_VelocityMap ("VelocityMap",  2D) = "" {}
		_VelocityScale ("Velocity Scale", Float) = 0.001
		_Accum       ("Accumulation", Range(0.01, 1.0)) = 0.01
		_Atten       ("Attenuation",  Range(0, 1))      = 0.01
	}
	
	CGINCLUDE
	
	#include "UnityCG.cginc"
	
	uniform sampler2D _MainTex;
	float4 _MainTex_TexelSize;
	uniform sampler2D _VelocityMap;
	uniform float     _VelocityScale;
	uniform float4x4 _BlurMat;
	uniform float  _Accum;
	uniform float  _Atten;
	
	float4 frag (v2f_img i) : SV_Target
	{
		return float4(0,0,0,0);
	}
	
	// Accumulation
	float4 frag_accumulation (v2f_img i) : SV_Target
	{
		fixed4 c = tex2D(_MainTex, i.uv);
		return float4(c.rgb, c.a * _Accum);	
	}
	
	// Blur
	float4 frag_blur (v2f_img i) : SV_Target
	{
		float2 d = _MainTex_TexelSize.xy;
		
		float4 c = float4(0,0,0,0);
		for (int y = 0; y <= 2; y++) {
			for (int x = 0; x <= 2; x++) {
				float2 uv = i.uv + float2 (x-1, y-1) * d;
				c += _BlurMat [y][x] * tex2D(_MainTex,uv);
			}
		}		
		return c;
	}
	
	// Attenuation
	float4 frag_attenuation (v2f_img i) : SV_Target
	{
		return (1.0 - _Atten) * tex2D(_MainTex, i.uv.xy);
	}
	
	// Fluid
	float4 frag_fluid (v2f_img i) : SV_Target
	{
		float2 d   = _MainTex_TexelSize.xy;
		float2 duv = tex2D(_VelocityMap, i.uv);
		
		float4 c = tex2D(_MainTex, i.uv - duv * d * _VelocityScale);
		
		return c;
	}
	
	
	ENDCG
	
	
	SubShader {
		
		Cull Off ZWrite Off ZTest Always
		
		// Pass 0: Accumulation
		Pass {
			Blend SrcAlpha OneMinusSrcAlpha
	
			Fog { Mode off }
			CGPROGRAM
			#pragma target 3.0
			#pragma glsl
			#pragma vertex   vert_img
			#pragma fragment frag_accumulation
			ENDCG
		} 
		
		// Pass 1: Blur
		Pass {
			Fog { Mode off }
			CGPROGRAM
			#pragma target 3.0
			#pragma glsl
			#pragma vertex   vert_img
			#pragma fragment frag_blur
			ENDCG
		} 
		
		// Pass 2: Attenuation
		Pass {
			Fog { Mode off }
			CGPROGRAM
			#pragma target 3.0
			#pragma glsl
			#pragma vertex   vert_img
			#pragma fragment frag_attenuation
			ENDCG
		} 
		
		// Pass 3: Fluid
		Pass {
			Fog { Mode off }
			CGPROGRAM
			#pragma target 3.0
			#pragma glsl
			#pragma vertex   vert_img
			#pragma fragment frag_fluid
			ENDCG
		}
		
	}
	FallBack "Diffuse"
}