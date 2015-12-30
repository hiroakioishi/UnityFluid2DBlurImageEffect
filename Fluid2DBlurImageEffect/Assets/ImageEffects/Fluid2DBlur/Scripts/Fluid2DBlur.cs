using UnityEngine;
using System.Collections;

namespace irishoak.ImageEffects {

	public class Fluid2DBlur : MonoBehaviour {

		[SerializeField]
		int _bufferSizeWidth  = 512;
		[SerializeField]
		int _bufferSizeHeight = 512;

		[SerializeField]
		int _fluidSimSizeWidth  = 512;
		[SerializeField]
		int _fluidSimSizeHeight = 512;

		const int _fluidSimMaxSize = 512;

		[SerializeField]
		[Range (0, 50)]
		int _solverIterations = 50;

		[SerializeField]
		Shader _advectShader;
		[SerializeField]
		Shader _divergenceShader;
		[SerializeField]
		Shader _pressureSolveShader;
		[SerializeField]
		Shader _pressureGradientSubstractShader;
		[SerializeField]
		Shader _applyForceShader;
		[SerializeField]
		Shader _applyForceByScreenBrightnessShader;
		[SerializeField]
		Shader _fluidBlurShader;
		
		Material _advectMat;
		Material _divergenceMat;
		Material _pressureSolveMat;
		Material _pressureGradientSubtractMat;
		Material _applyForceMat;
		Material _applyForceByScreenBrightnessMat;
		Material _fluidBlurMat;
		
		RenderTexture[] _velocityBuffer;
		RenderTexture[] _pressureBuffer;
		RenderTexture   _divergenceBuffer;

		RenderTexture[] _screenBuffer;
		
		Vector2 _invResolution;
		float   _RDX;

		[SerializeField]
		[Range (0.01f, 1.0f)]
		float _accum = 0.01f;
		
		[SerializeField]
		[Range (0.0f, 1.0f)]
		float _atten = 0.001f;
		
		[SerializeField]
		float _blurSigma = 0.85f;

		[SerializeField]
		float _velocityScale = 0.002f;
		
		[SerializeField]
		[Range (1, 10)]
		int _blurIter = 3;
		
		Matrix4x4 _blurMat;

		const int PASS_ACCUM = 0;
		const int PASS_BLUR  = 1;
		const int PASS_ATTEN = 2;
		const int PASS_FLUID = 3;

		[Range (0, 1024)]
		public int GUITextureSize = 320;

		[SerializeField]
		bool _isLeftMouseButtonDown = false;
		Vector2 _currentMousePosition;
		Vector2 _previousMousePosition;

		[SerializeField]
		bool _isEnableMouseToApplyForce = true;

		[SerializeField]
		bool _isDebug = true;

		public RenderTexture GetFlowVelocityFieldTex () {
			if (_velocityBuffer != null && _velocityBuffer.Length > 0) {
				return _velocityBuffer [0];
			} else {
				return null;
			}
		}
		
		void Start () {
			
			Setup ();
			
		}
		
		void Update () {

			if (_bufferSizeWidth != Screen.width || _bufferSizeHeight != Screen.height) {
				Reset ();
			}
			
			if (Input.GetMouseButtonDown (0)) {
				_isLeftMouseButtonDown = true;
			}
			
			if (Input.GetMouseButtonUp (0)) {
				_isLeftMouseButtonDown = false;
			}
			
			if (Input.GetKeyUp ("r")) {
				_resetBuffers ();
			}
			
			Step (Time.deltaTime * 0.5f);
			
		}

		void OnRenderImage (RenderTexture src, RenderTexture dest) {

			Material m = _fluidBlurMat;

			_accum     = Mathf.Clamp01 (_accum);
			_atten     = Mathf.Clamp01 (_atten);
			_blurSigma = Mathf.Clamp01 (_blurSigma);
			_blurIter  = Mathf.Clamp (_blurIter, 1, 10);
			
			var coeff = -1.0f / (2.0f * _blurSigma * _blurSigma);
			var f11 = 1.0f;
			var f12 = Mathf.Exp (coeff);
			var f22 = Mathf.Exp (2.0f * coeff);
			var invSum = 1.0f / (f11 + 4 * f12 + 4 * f22);
			_blurMat[1, 1] = invSum * f11;
			_blurMat[0, 1] = _blurMat[1, 0] = _blurMat[2, 1] = _blurMat[1, 2] = invSum * f12;
			_blurMat[0, 0] = _blurMat[2, 0] = _blurMat[0, 2] = _blurMat[2, 2] = invSum * f22;

			m.SetFloat ("_Accum", _accum);
			m.SetFloat ("_Atten", _atten);
			m.SetMatrix ("_BlurMat", _blurMat);
			
			_screenBuffer [0].DiscardContents ();
			Graphics.Blit(_screenBuffer [0], _screenBuffer [1], m, PASS_BLUR);
			_swapBuffer (_screenBuffer);

			m.SetTexture ("_VelocityMap", GetFlowVelocityFieldTex ());
			m.SetFloat ("_VelocityScale", _velocityScale);
			_screenBuffer [1].DiscardContents ();
			Graphics.Blit(_screenBuffer [0], _screenBuffer [1], m, PASS_FLUID);
			_swapBuffer (_screenBuffer);
			
			for (var i = 0; i < _blurIter; i++) {
				_screenBuffer [1].DiscardContents ();
				Graphics.Blit (_screenBuffer [0], _screenBuffer [1], m, PASS_BLUR);
				_swapBuffer (_screenBuffer);
			}
			
			Graphics.Blit (src, _screenBuffer [0], m, PASS_ACCUM);
			
			Graphics.Blit (_screenBuffer [0], dest);

		}
		
		void OnDestroy () {
			
			_destroyBuffers ();
			_destroyMaterials ();
			
		}
		
		
		public void Setup () {

			_createMaterials ();

			Reset ();

		}

		public void Reset () {

			_destroyBuffers ();

			_bufferSizeWidth  = Screen.width;
			_bufferSizeHeight = Screen.height;

			_fluidSimSizeWidth  = _bufferSizeWidth < _fluidSimMaxSize ? _bufferSizeWidth : _fluidSimMaxSize;
			_fluidSimSizeHeight = Mathf.FloorToInt (_fluidSimSizeWidth * (_bufferSizeHeight / (_bufferSizeWidth * 1.0f)));

			_RDX = 1.0f / (_fluidSimSizeWidth * 1.0f);
			_invResolution = new Vector2 (1.0f / (_fluidSimSizeWidth * 1.0f), 1.0f / (_fluidSimSizeHeight * 1.0f));

			_createBuffers ();
			_resetBuffers ();

		}
		
		public void Step (float dt_) {
			
			float aspectRatio = _fluidSimSizeWidth / (_fluidSimSizeHeight * 1.0f);
			Shader.SetGlobalFloat ("_Fluid2D_AspectRatio", aspectRatio);
			
			Vector3 mp = Input.mousePosition;
			//mp.x *= _aspectRatio;
			_currentMousePosition = Camera.main.ScreenToViewportPoint (mp);
			
			_advect (ref _velocityBuffer, dt_);
			
			_applyForces (dt_);
			_applyForcesByScreen (dt_);
			
			_computeDivergence ();
			_solvePressure ();
			_subtractPressureGradient ();

			_previousMousePosition = _currentMousePosition;
		}
		
		void _advect (ref RenderTexture[] targetBuffer_, float dt_) {
			
			_advectMat.SetFloat ("_Dt", dt_);
			_advectMat.SetFloat ("_RDX", _RDX);
			_advectMat.SetVector  ("_Invresolution", _invResolution);
			_advectMat.SetTexture ("_Target", targetBuffer_ [0]);
			_advectMat.SetTexture ("_Velocity", _velocityBuffer [0]);
			Graphics.Blit (null, targetBuffer_ [1], _advectMat);
			_swapBuffer (targetBuffer_);
		}
		
		void _applyForces (float dt_) {
			if (_applyForceMat == null)
				return;
			//set uniforms
			_applyForceMat.SetTexture ("_Velocity", _velocityBuffer [0]);
			_applyForceMat.SetFloat ("_Dt", dt_);
			_applyForceMat.SetFloat ("_Dx", _fluidSimSizeWidth);
			if (_isEnableMouseToApplyForce) {
				_applyForceMat.SetInt    ("_IsMouseDown",       _isLeftMouseButtonDown ? 1 : 0);
				_applyForceMat.SetVector ("_MouseClipSpace",     _currentMousePosition);
				_applyForceMat.SetVector ("_LastMouseClipSpace", _previousMousePosition);
			}
			//render
			Graphics.Blit (null, _velocityBuffer [1], _applyForceMat);
			_swapBuffer (_velocityBuffer);
			
		}

		void _applyForcesByScreen (float dt_) {
			if (_applyForceByScreenBrightnessMat == null)
				return;
			//set uniforms
			_applyForceByScreenBrightnessMat.SetTexture ("_Velocity",  _velocityBuffer [0]);
			_applyForceByScreenBrightnessMat.SetTexture ("_ScreenTex", _screenBuffer [1]);
			_applyForceByScreenBrightnessMat.SetFloat ("_Dt", dt_);
			_applyForceByScreenBrightnessMat.SetFloat ("_Dx", _fluidSimSizeWidth);
			_applyForceByScreenBrightnessMat.SetFloat ("_TexelSizeScale",  0.1f);
			_applyForceByScreenBrightnessMat.SetFloat ("_BumpHeightScale",  0.1f);

			//render
			Graphics.Blit (null, _velocityBuffer [1], _applyForceByScreenBrightnessMat);
			_swapBuffer (_velocityBuffer);
			
		}
		
		void _computeDivergence () {
			
			_divergenceMat.SetTexture ("_Velocity", _velocityBuffer [0]);
			
			_divergenceMat.SetFloat   ("_HalfRDX", 0.5f * _RDX);
			_divergenceMat.SetVector  ("_Invresolution", _invResolution);
			Graphics.Blit (null, _divergenceBuffer, _divergenceMat);
		}
		
		void _solvePressure () {
			
			_pressureSolveMat.SetTexture ("_Divergence", _divergenceBuffer);
			_pressureSolveMat.SetFloat   ("_Alpha", -(_fluidSimSizeWidth * _fluidSimSizeWidth));
			_pressureSolveMat.SetVector  ("_Invresolution", _invResolution);
			
			for (int i = 0; i < _solverIterations; i++) {
				_pressureSolveMat.SetTexture ("_Pressure", _pressureBuffer [0]);
				Graphics.Blit (null, _pressureBuffer [1], _pressureSolveMat);
				_swapBuffer (_pressureBuffer);
			}
		}
		
		void _subtractPressureGradient () {
			
			_pressureGradientSubtractMat.SetTexture ("_Pressure", _pressureBuffer [0]);
			_pressureGradientSubtractMat.SetTexture ("_Velocity", _velocityBuffer [0]);
			_pressureGradientSubtractMat.SetFloat   ("_HalfRDX", 0.5f * _RDX);
			_pressureGradientSubtractMat.SetVector  ("_Invresolution", _invResolution);
			Graphics.Blit (null, _velocityBuffer [1], _pressureGradientSubtractMat);
			
			_swapBuffer (_velocityBuffer);
		}

		void _createBuffers () {
			
			_createBuffer (ref _velocityBuffer,   _fluidSimSizeWidth, _fluidSimSizeHeight);
			_createBuffer (ref _pressureBuffer,   _fluidSimSizeWidth, _fluidSimSizeHeight);
			_createBuffer (ref _divergenceBuffer, _fluidSimSizeWidth, _fluidSimSizeHeight);

			_createBuffer (ref _screenBuffer,     _bufferSizeWidth,   _bufferSizeHeight  );
		}
		
		void _resetBuffers () {
			
			_resetBuffer (ref _velocityBuffer);
			_resetBuffer (ref _pressureBuffer);
			_resetBuffer (ref _divergenceBuffer);

			_resetBuffer (ref _screenBuffer);
			
		}
		
		void _destroyBuffers () {
			
			_destroyBuffer (ref _velocityBuffer);
			_destroyBuffer (ref _pressureBuffer);
			_destroyBuffer (ref _divergenceBuffer);

			_destroyBuffer (ref _screenBuffer);
			
		}
		
		void _createMaterials () {
			
			_createMaterial (ref _advectMat,                   _advectShader);
			_createMaterial (ref _divergenceMat,               _divergenceShader);
			_createMaterial (ref _pressureSolveMat,            _pressureSolveShader);
			_createMaterial (ref _pressureGradientSubtractMat, _pressureGradientSubstractShader);
			_createMaterial (ref _applyForceMat,               _applyForceShader);

			_createMaterial (ref _applyForceByScreenBrightnessMat, _applyForceByScreenBrightnessShader);
			_createMaterial (ref _fluidBlurMat,                _fluidBlurShader);
		}
		
		void _destroyMaterials () {
			
			_destroyMaterial (ref _advectMat);
			_destroyMaterial (ref _divergenceMat);
			_destroyMaterial (ref _pressureSolveMat);
			_destroyMaterial (ref _pressureGradientSubtractMat);
			_destroyMaterial (ref _applyForceMat);

			_destroyMaterial (ref _applyForceByScreenBrightnessMat);
			_destroyMaterial (ref _fluidBlurMat);
			
		}
		
		void _createBuffer (ref RenderTexture[] rt_, int bufferWidth_, int bufferHeight_) {
			
			rt_ = new RenderTexture[2];
			rt_ [0] = new RenderTexture (bufferWidth_, bufferHeight_, 0, RenderTextureFormat.ARGBHalf);
			rt_ [0].filterMode = FilterMode.Bilinear;
			rt_ [0].wrapMode   = TextureWrapMode.Clamp;
			rt_ [0].hideFlags  = HideFlags.DontSave;
			rt_ [0].Create ();
			Graphics.SetRenderTarget (rt_ [0]);
			GL.Clear (false, true, new Color (0,0,0,0));
			Graphics.SetRenderTarget (null);
			rt_ [1] = new RenderTexture (bufferWidth_, bufferHeight_, 0, RenderTextureFormat.ARGBHalf);
			rt_ [1].filterMode = FilterMode.Bilinear;
			rt_ [1].wrapMode   = TextureWrapMode.Clamp;
			rt_ [1].hideFlags  = HideFlags.DontSave;
			rt_ [1].Create ();
			Graphics.SetRenderTarget (rt_ [1]);
			GL.Clear (false, true, new Color (0,0,0,0));
			Graphics.SetRenderTarget (null);
		}
		
		void _createBuffer (ref RenderTexture rt_, int bufferWidth_, int bufferHeight_) {
			
			rt_ = new RenderTexture (bufferWidth_, bufferHeight_, 0, RenderTextureFormat.ARGBHalf);
			rt_.filterMode = FilterMode.Bilinear;
			rt_.wrapMode   = TextureWrapMode.Clamp;
			rt_.hideFlags  = HideFlags.DontSave;
			rt_.Create ();
			Graphics.SetRenderTarget (rt_);
			GL.Clear (false, true, new Color (0,0,0,0));
			Graphics.SetRenderTarget (null);
		}
		
		void _resetBuffer (ref RenderTexture[] rt_) {
			
			Graphics.SetRenderTarget (rt_ [0]);
			GL.Clear (false, true, Color.black);
			Graphics.SetRenderTarget (null);
			
			Graphics.SetRenderTarget (rt_ [1]);
			GL.Clear (false, true, Color.black);
			Graphics.SetRenderTarget (null);
			
		}
		
		void _resetBuffer (ref RenderTexture rt_) {
			
			Graphics.SetRenderTarget (rt_);
			GL.Clear (false, true, Color.black);
			Graphics.SetRenderTarget (null);
			
		}
		
		void _destroyBuffer (ref RenderTexture[] buffer_) {
			
			if (buffer_ != null && buffer_.Length > 0) {
				for (int i = 0; i < buffer_.Length; i++) {
					DestroyImmediate (buffer_ [i]);
				}
			}
			
		}
		
		void _destroyBuffer (ref RenderTexture buffer_) {
			
			if (buffer_ != null) {
				DestroyImmediate (buffer_);
			}
			
		}
		
		void _swapBuffer (RenderTexture[] buffer_) {
			
			RenderTexture temp = buffer_ [0];
			buffer_ [0] = buffer_ [1];
			buffer_ [1] = temp;
			
		}
		
		void _createMaterial (ref Material mat_, Shader shader_) {
			
			if (mat_ == null) mat_ = new Material (shader_);
			
		}
		
		void _destroyMaterial (ref Material mat_) {
			
			if (mat_ != null) DestroyImmediate (mat_);
			
		}
		
		void OnGUI () {
			int  size = GUITextureSize;
			Rect r00  = new Rect (size * 0, size * 0, size, size);
			Rect r10  = new Rect (size * 1, size * 0, size, size);
			Rect r01  = new Rect (size * 0, size * 1, size, size);
			Rect r11  = new Rect (size * 1, size * 1, size, size);
			//Rect r02  = new Rect (size * 0, size * 2, size, size);
			//Rect r12  = new Rect (size * 1, size * 2, size, size);
			//Rect r03  = new Rect (size * 0, size * 3, size, size);
			//Rect r13  = new Rect (size * 1, size * 3, size, size);
			//Rect r04  = new Rect (size * 0, size * 4, size, size);
			//Rect r14  = new Rect (size * 1, size * 4, size, size);
			Rect r20  = new Rect (size * 2, size * 0, size, size);
			//Rect r21  = new Rect (size * 2, size * 1, size, size);
			//Rect r30  = new Rect (size * 3, size * 0, size, size);
			//Rect r31  = new Rect (size * 3, size * 1, size, size);
			Rect r40  = new Rect (size * 4, size * 0, size, size);
			Rect r41  = new Rect (size * 4, size * 1, size, size);
			
			//GUI.DrawTexture (new Rect (0, 0, Screen.width, Screen.height), _dyeBuffer [0]);
			
			GUI.DrawTexture (r00, _velocityBuffer [0]);
			GUI.Label (r00, "_velcotiyBuffer [0]");
			GUI.DrawTexture (r01, _velocityBuffer [1]);
			GUI.Label (r01, "_velcotiyBuffer [1]");
			
			GUI.DrawTexture (r10, _pressureBuffer [0]);
			GUI.Label (r10, "_pressureBuffer [0]");
			GUI.DrawTexture (r11, _pressureBuffer [1]);
			GUI.Label (r11, "_pressureBuffer [1]");
			
			GUI.DrawTexture (r20, _divergenceBuffer);
			GUI.Label (r20, "_divergenceBuffer");

			GUI.DrawTexture (r40, _screenBuffer [0]);
			GUI.Label (r40, "_screenBuffer [0]");
			GUI.DrawTexture (r41, _screenBuffer [1]);
			GUI.Label (r41, "_screenBuffer [1]");
			
			
		}	
	}
}