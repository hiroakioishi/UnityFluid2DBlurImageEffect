Shader "Hidden/GPGPU/Fluid2D/PressureSolve" {
	Properties {
		_MainTex ("-", 2D) = "" {}
	}
	
	CGINCLUDE
	
	#include "UnityCG.cginc"
	
	#define PRESSURE_BOUNDARY
	
	uniform float2 _Invresolution;
	
	uniform sampler2D _MainTex;
	
	uniform sampler2D _Pressure;
	uniform sampler2D _Divergence;
	uniform float     _Alpha;		// alpha = -(dx)^2, where dx = grid cell size
	
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
		
		// left, right, bottom, and top x samples
		//texelSize = 1./resolution;
		float L = samplePressue (_Pressure, i.uv.xy - float2 (_Invresolution.x, 0));
		float R = samplePressue (_Pressure, i.uv.xy + float2 (_Invresolution.x, 0));
		float B = samplePressue (_Pressure, i.uv.xy - float2 (0, _Invresolution.y));
		float T = samplePressue (_Pressure, i.uv.xy + float2 (0, _Invresolution.y));

		float bC = tex2D (_Divergence, i.uv.xy).x;

		float4 finalColor = float4( (L + R + B + T + _Alpha * bC) * 0.25, 0, 0, 1 );//rBeta = .25
	
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