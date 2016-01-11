Shader "Hidden/GPGPU/Fluid2D/ApplyForceByScreenBrightness" {
	Properties {
		_MainTex   ("-", 2D) = "" {}
		_ScreenTex ("-", 2D) = "" {}
		_Velocity  ("-", 2D) = "" {}
	}
	
	CGINCLUDE
	
	#include "UnityCG.cginc"

	sampler2D _Velocity;
	
	sampler2D _MainTex;
	float2 _MainTex_TexelSize;
	
	sampler2D _ScreenTex;
	float4 _ScreenTex_TexelSize;
	
	float _TexelSizeScale;
	float _BumpHeightScale;

	
	float4 frag (v2f_img i) : SV_Target
	{
	
		float2 v = tex2D(_Velocity, i.uv).xy;

		float2 uv = i.uv;
		float2 uvE = uv + fixed2(_ScreenTex_TexelSize.x * _TexelSizeScale, 0.0);
		float2 uvN = uv + fixed2(0.0, _ScreenTex_TexelSize.y * _TexelSizeScale);

		float3 st  = tex2D(_ScreenTex, uv ).xyz;
		float3 stE = tex2D(_ScreenTex, uvE).xyz;
		float3 stU = tex2D(_ScreenTex, uvN).xyz;

		st  = st  / length(st  == 0 ? 0.0001 : st );
		stE = stE / length(stE == 0 ? 0.0001 : stE);
		stU = stU / length(stU == 0 ? 0.0001 : stU);

		fixed height  = (st.x  + st.y  + st.z ) * 0.3333333 * _BumpHeightScale;
		fixed heightE = (stE.x + stE.y + stE.z) * 0.3333333 * _BumpHeightScale;
		fixed heightN = (stU.x + stU.y + stU.z) * 0.3333333 * _BumpHeightScale;
		
		// BiNormal Vector
		fixed3 bv = fixed3(uvN.x, uvN.y, heightN) - fixed3(uv.x, uv.y, height);
		fixed3 tv = fixed3(uvE.x, uvE.y, heightE) - fixed3(uv.x, uv.y, height);
		
		bv = normalize(bv);
		tv = normalize(tv);
		
		fixed3 norm = normalize(cross(tv, bv));
		//norm.xyz *= 0.0001;
		float4 result = float4(v.x + norm.x, v.y + norm.y, 0, 1);
		//float4 result = float4(v.x, v.y, 0, 1);
		return result;
	}
	
	ENDCG
	
	
	SubShader {
		
		Pass {
			Fog { Mode off }
			CGPROGRAM
			#pragma target 3.0
			//#pragma glsl
			#pragma vertex   vert_img
			#pragma fragment frag
			ENDCG
		} 
	}
	FallBack "Diffuse"
}