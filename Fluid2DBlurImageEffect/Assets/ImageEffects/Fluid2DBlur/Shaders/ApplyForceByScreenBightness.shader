Shader "Hidden/GPGPU/Fluid2D/ApplyForceByScreenBrightness" {
	Properties {
		_MainTex   ("-", 2D) = "" {}
		_ScreenTex ("-", 2D) = "" {}
		_Velocity  ("-", 2D) = "" {}
	}
	
	CGINCLUDE
	
	#include "UnityCG.cginc"

	uniform sampler2D _Velocity;
	
	uniform sampler2D _MainTex;
	float2 _MainTex_TexelSize;
	
	uniform sampler2D _ScreenTex;
	float4 _ScreenTex_TexelSize;
	
	uniform float _TexelSizeScale;
	uniform float _BumpHeightScale;

	
	float4 frag (v2f_img i) : SV_Target
	{
	
		float2 v = tex2D(_Velocity, i.uv).xy;

		float2 uv = i.uv;
		float2 uvE = uv + fixed2(_ScreenTex_TexelSize.x * _TexelSizeScale, 0.0);
		float2 uvN = uv + fixed2(0.0, _ScreenTex_TexelSize.y * _TexelSizeScale);
		
		fixed height  = normalize(tex2D(_ScreenTex, uv ).xyz) * _BumpHeightScale;
		fixed heightE = normalize(tex2D(_ScreenTex, uvE).xyz) * _BumpHeightScale;
		fixed heightN = normalize(tex2D(_ScreenTex, uvN).xyz) * _BumpHeightScale;
		
		// BiNormal Vector
		fixed3 bv = fixed3(uvN.x, uvN.y, heightN) - fixed3(uv.x, uv.y, height);
		fixed3 tv = fixed3(uvE.x, uvE.y, heightE) - fixed3(uv.x, uv.y, height);
		
		bv = normalize(bv);
		tv = normalize(tv);
		
		fixed3 norm = normalize(cross(tv, bv));
		
		float4 result = float4(v.x + norm.x, v.y + norm.y, 0, 1);
		return result;
	}
	
	ENDCG
	
	
	SubShader {
		
		Pass {
			Fog { Mode off }
			CGPROGRAM
			#pragma target 3.0
			#pragma glsl
			#pragma vertex   vert_img
			#pragma fragment frag
			ENDCG
		} 
	}
	FallBack "Diffuse"
}