Shader "Hidden/GPGPU/Fluid2D/VelocityDivergence" {
	Properties {
		_MainTex ("-", 2D) = "" {}
	}
	
	CGINCLUDE
	
	#include "UnityCG.cginc"
	
	#define VELOCITY_BOUNDARY
	
	uniform float2    _Invresolution;
	
	uniform sampler2D _MainTex;
	float2 _MainTex_TexelSize;
	
	uniform sampler2D _Velocity;	//vector fields
	uniform float     _HalfRDX;	// .5*1/gridscale
	
	//sampling velocity texture factoring in boundary conditions
	float2 sampleVelocity(sampler2D velocity, float2 coord){
	    float2 cellOffset = float2 (0.0, 0.0);
	    float2 multiplier = float2 (1.0, 1.0);

	    //free-slip boundary: the average flow across the boundary is restricted to 0
	    //avg(uA.xy, uB.xy) dot (boundary normal).xy = 0
	    //walls
	    #ifdef VELOCITY_BOUNDARY
	    if(coord.x < 0.0){
	        cellOffset.x = 1.0;
	        multiplier.x = -1.0;
	    }else if(coord.x > 1.0){
	        cellOffset.x = -1.0;
	        multiplier.x = -1.0;
	    }
	    if(coord.y < 0.0){
	        cellOffset.y = 1.0;
	        multiplier.y = -1.0;
	    }else if(coord.y > 1.0){
	        cellOffset.y = -1.0;
	        multiplier.y = -1.0;
	    }
	    #endif

	    return multiplier * tex2D (velocity, coord + cellOffset * _Invresolution).xy;
	}
	
	float4 frag (v2f_img i) : SV_Target
	{
		//compute the divergence according to the finite difference formula
		//texelSize = 1/resolution
		float2 L = sampleVelocity (_Velocity, i.uv.xy - float2 (_Invresolution.x, 0));
		float2 R = sampleVelocity (_Velocity, i.uv.xy + float2 (_Invresolution.x, 0));
		float2 B = sampleVelocity (_Velocity, i.uv.xy - float2 (0, _Invresolution.y));
		float2 T = sampleVelocity (_Velocity, i.uv.xy + float2 (0, _Invresolution.y));

		float4 result = float4 (_HalfRDX * ((R.x - L.x) + (T.y - B.y)), 0, 0, 1);
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