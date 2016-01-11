Shader "Hidden/ImageEffects/FluidBlur" {
	Properties {
		_MainTex       ("-", 2D) = "" {}
		_VelocityMap   ("VelocityMap",  2D) = "" {}
		_VelocityScale ("Velocity Scale", Float) = 0.001
		_Accum         ("Accumulation", Range(0.01, 1.0)) = 0.01
		_Atten         ("Attenuation",  Range(0, 1))      = 0.01
	}
	
	CGINCLUDE
	
	#include "UnityCG.cginc"
	
	sampler2D _MainTex;
	float4 _MainTex_TexelSize;
	sampler2D _VelocityMap;
	float     _VelocityScale;
	float4x4  _BlurMat;
	float     _Accum;
	float     _Atten;

	struct appdata
	{
		float4 vertex : POSITION;
		float2 uv : TEXCOORD0;
	};

	struct v2f
	{
		float2 uv : TEXCOORD0;
		float4 vertex : SV_POSITION;
	};

	v2f vert (appdata v)
	{
		v2f o;
		o.vertex = mul(UNITY_MATRIX_MVP, v.vertex);
		o.uv = v.uv;
		return o;
	}

	// Accumulation
	fixed4 frag_accumulation (v2f i) : SV_Target
	{
		fixed4 c = tex2D(_MainTex, i.uv);
		return fixed4(c.rgb, c.a * _Accum);	
	}
	
	// Blur
	fixed4 frag_blur (v2f i) : SV_Target
	{
		float2 d = _MainTex_TexelSize.xy;
		
		fixed4 c = fixed4(0,0,0,0);
		for (int y = 0; y <= 2; y++) {
			for (int x = 0; x <= 2; x++) {
				float2 uv = i.uv + float2 (x-1, y-1) * d;
				c += _BlurMat [y][x] * tex2D(_MainTex,uv);
			}
		}		
		return c;
	}
	
	// Attenuation
	fixed4 frag_attenuation (v2f i) : SV_Target
	{
		return (1.0 - _Atten) * tex2D(_MainTex, i.uv.xy);
	}
	
	// Fluid
	fixed4 frag_fluid (v2f i) : SV_Target
	{
		float2 d   = _MainTex_TexelSize.xy;
		float2 duv = tex2D(_VelocityMap, i.uv);
		return tex2D(_MainTex, i.uv - d * duv * _VelocityScale);
	}
	
	
	ENDCG
	
	
	SubShader {
		
		Cull Off ZWrite Off ZTest Always// No culling or depth
		
		// Pass 0: Accumulation
		Pass {
			Blend SrcAlpha OneMinusSrcAlpha
			
			Fog { Mode off }
			CGPROGRAM
			#pragma target 3.0
			//#pragma glsl
			#pragma vertex   vert
			#pragma fragment frag_accumulation
			ENDCG
		} 
		
		// Pass 1: Blur
		Pass {
			Fog { Mode off }
			CGPROGRAM
			#pragma target 3.0
			//#pragma glsl
			#pragma vertex   vert
			#pragma fragment frag_blur
			ENDCG
		} 
		
		// Pass 2: Attenuation
		Pass {
			Fog { Mode off }
			CGPROGRAM
			#pragma target 3.0
			//#pragma glsl
			#pragma vertex   vert
			#pragma fragment frag_attenuation
			ENDCG
		} 
		
		// Pass 3: Fluid
		Pass {
			Fog { Mode off }
			CGPROGRAM
			#pragma target 3.0
			//#pragma glsl
			#pragma vertex   vert
			#pragma fragment frag_fluid
			ENDCG
		}
		
	}
	FallBack "Diffuse"
}