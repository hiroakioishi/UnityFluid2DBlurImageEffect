Shader "Hidden/GPGPU/Fluid2D/ApplyForce" {
	Properties {
		_MainTex ("-", 2D) = "" {}
	}
	
	CGINCLUDE
	
	#include "UnityCG.cginc"
	
	uniform float _Fluid2D_AspectRatio;
	
	uniform sampler2D _MainTex;
	float2 _MainTex_TexelSize;
	
	uniform sampler2D _Velocity;
	uniform float     _Dt;
	uniform float     _Dx;
	
	uniform bool   _IsMouseDown;
	uniform float2 _MouseClipSpace;
	uniform float2 _LastMouseClipSpace;
	
	float2 clipToSimSpace(float2 clipSpace){
   		return  float2(clipSpace.x * _Fluid2D_AspectRatio, clipSpace.y);
	}
	
	//Segment
	float distanceToSegment(float2 a, float2 b, float2 p, out float fp){
		float2 d = p - a;
		float2 x = b - a;

		fp = 0.0; //fractional projection, 0 - 1 in the length of vec2(b - a)
		float lx = length(x);
		
		if(lx <= 0.0001) return length(d);//#! needs improving; hot fix for normalization of 0 vector

		float projection = dot(d, x / lx); //projection in pixel units

		fp = projection / lx;

		if(projection < 0.0) {
			return length(d);
		} else if (projection > length(x)) {
			return length(p - b);
		}
		return sqrt(abs(dot(d, d) - projection * projection));
	}
	
	float distanceToSegment(float2 a, float2 b, float2 p){
		float fp;
		return distanceToSegment(a, b, p, fp);
	}
	
	float4 frag (v2f_img i) : SV_Target
	{
	
		float2 v = tex2D(_Velocity, i.uv.xy).xy;

		v.xy *= 0.999;

		if(_IsMouseDown){
			float2 mouse         = clipToSimSpace(_MouseClipSpace);
			float2 lastMouse     = clipToSimSpace(_LastMouseClipSpace);
			float2 mouseVelocity = -(lastMouse - mouse) / _Dt;
				
			//compute tapered distance to mouse line segment
			float fp; //fractional projection
			float l = distanceToSegment(mouse, lastMouse, i.uv.xy, fp);
			float taperFactor = 0.6;//1 => 0 at lastMouse, 0 => no tapering
			float projectedFraction = 1.0 - clamp(fp, 0.0, 1.0) * taperFactor;

			float R = 0.015;
			float m = exp(-l/R); //drag coefficient
			m *= projectedFraction * projectedFraction;

			float2 targetVelocity = mouseVelocity * _Dx;
			v += (targetVelocity - v) * m;
		}
		
		float4 result = float4(v, 0, 1.);
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