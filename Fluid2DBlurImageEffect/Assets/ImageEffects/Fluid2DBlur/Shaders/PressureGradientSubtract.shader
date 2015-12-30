Shader "Hidden/GPGPU/Fluid2D/PressureGradientSubtract" {
	Properties {
		_MainTex ("-", 2D) = "" {}
	}
	
	CGINCLUDE
	
	#include "UnityCG.cginc"
	
	#define PRESSURE_BOUDARY
	
	uniform float2 _Invresolution;
	
	uniform sampler2D _MainTex;
	float2 _MainTex_TexelSize;
	
	uniform sampler2D _Pressure;
	uniform sampler2D _Velocity;
	
	uniform float _HalfRDX;
	
	//sampling pressure texture factoring in boundary conditions
	float samplePressue(sampler2D pressure, float2 coord){
	    
	    float2 cellOffset = float2(0.0, 0.0);

	    //pure Neumann boundary conditions: 0 pressure gradient across the boundary
	    //dP/dx = 0
	    //walls
	    #ifdef PRESSURE_BOUNDARY
	    if(coord.x < 0.0)      cellOffset.x = 1.0;
	    else if(coord.x > 1.0) cellOffset.x = -1.0;
	    if(coord.y < 0.0)      cellOffset.y = 1.0;
	    else if(coord.y > 1.0) cellOffset.y = -1.0;
	    #endif

	    return tex2D(pressure, coord + cellOffset * _Invresolution).x;
	}

	
	float4 frag (v2f_img i) : SV_Target
	{
		float L = samplePressue(_Pressure, i.uv.xy - float2(_Invresolution.x, 0));
		float R = samplePressue(_Pressure, i.uv.xy + float2(_Invresolution.x, 0));
		float B = samplePressue(_Pressure, i.uv.xy - float2(0, _Invresolution.y));
		float T = samplePressue(_Pressure, i.uv.xy + float2(0, _Invresolution.y));

		float2 v = tex2D (_Velocity, i.uv.xy).xy;

		float4 finalColor = float4 (v - _HalfRDX * float2 (R-L, T-B), 0.0, 1.0);
	
		return finalColor;
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