package openfl.display;


import haxe.Timer;
import lime.graphics.opengl.GL;
import openfl._internal.stage3D.opengl.GLStage3D;
import openfl.display3D.Context3D;
import openfl.display3D.Context3DBlendFactor;
import openfl.display3D.Context3DProfile;
import openfl.display3D.Context3DRenderMode;
import openfl.events.ErrorEvent;
import openfl.events.Event;
import openfl.events.EventDispatcher;
import openfl.Vector;

#if (lime >= "7.0.0")
import lime.graphics.RenderContext;
#else
import lime.graphics.GLRenderContext;
#end

#if (js && html5)
import js.html.webgl.RenderingContext;
import js.html.CanvasElement;
import js.html.CSSStyleDeclaration;
import js.Browser;
#end

#if !openfl_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end

@:access(lime.graphics.opengl.GL)
@:access(lime._backend.html5.HTML5GLRenderContext)
@:access(lime._backend.native.NativeGLRenderContext)
@:access(openfl.display3D.Context3D)


class Stage3D extends EventDispatcher {
	
	
	private static var __active:Bool;
	
	public var context3D (default, null):Context3D;
	public var visible:Bool;
	public var x (get, set):Float;
	public var y (get, set):Float;
	
	private var __contextRequested:Bool;
	private var __stage:Stage;
	private var __x:Float;
	private var __y:Float;
	
	#if (js && html5)
	private var __canvas:CanvasElement;
	private var __renderContext:#if (lime >= "7.0.0") RenderContext #else GLRenderContext #end;
	private var __style:CSSStyleDeclaration;
	private var __webgl:RenderingContext;
	
	#if patch_context3d
	private var __renderer3d:OpenGLRenderer; // fallback for canvas
	private var __canvasResizeMethod:Void->Void;
	#end
	
	#end
	
	
	#if openfljs
	private static function __init__ () {
		
		untyped Object.defineProperties (Stage3D.prototype, {
			"x": { get: untyped __js__ ("function () { return this.get_x (); }"), set: untyped __js__ ("function (v) { return this.set_x (v); }") },
			"y": { get: untyped __js__ ("function () { return this.get_y (); }"), set: untyped __js__ ("function (v) { return this.set_y (v); }") },
		});
		
	}
	#end
	
	
	private function new () {
		
		super ();
		
		__x = 0;
		__y = 0;
		
		visible = true;
		
	}
	
	
	public function requestContext3D (context3DRenderMode:Context3DRenderMode = AUTO, profile:Context3DProfile = BASELINE):Void {
		
		__contextRequested = true;
		
		if (context3D != null) {
			
			Timer.delay (__dispatchCreate, 1);
			
		}
		
	}
	
	
	public function requestContext3DMatchingProfiles (profiles:Vector<Context3DProfile>):Void {
		
		requestContext3D ();
		
	}
	
	
	private function __createContext (stage:Stage, renderer:DisplayObjectRenderer):Void {
		
		#if patch_context3d
		
		if (__stage == null)
		{
			stage.addEventListener(Event.RESIZE, onStageResized);
		}
		
		#end
		
		__stage = stage;
		
		if (renderer.__type == OPENGL) {
			
			context3D = new Context3D (this, renderer);
			__dispatchCreate ();
			
		} else if (renderer.__type == DOM) {
			
			#if (js && html5)
			__canvas = cast Browser.document.createElement ("canvas");
			__canvas.width = stage.stageWidth;
			__canvas.height = stage.stageHeight;
			
			var window = stage.window;
			
			#if (lime >= "7.0.0")
			var attributes = renderer.__context.attributes;
			#else
			var attributes = window.config;
			#end
			
			var transparentBackground = Reflect.hasField (attributes, "background") && attributes.background == null;
			var colorDepth = Reflect.hasField (attributes, "colorDepth") ? attributes.colorDepth : 32;
			
			var options = {
				
				alpha: (transparentBackground || colorDepth > 16) ? true : false,
				antialias: Reflect.hasField (attributes, "antialiasing") ? attributes.antialiasing > 0 : false,
				depth: #if (lime < "7.0.0") Reflect.hasField (attributes, "depthBuffer") ? attributes.depthBuffer : #end true,
				premultipliedAlpha: true,
				stencil: #if (lime < "7.0.0") Reflect.hasField (attributes, "stencilBuffer") ? attributes.stencilBuffer : #end false,
				preserveDrawingBuffer: false
				
			};
			
			__webgl = cast __canvas.getContextWebGL (options);
			
			if (__webgl != null) {
				
				#if webgl_debug
				__webgl = untyped WebGLDebugUtils.makeDebugContext (__webgl);
				#end
				
				// TODO: Need to handle renderer/context better
				
				#if (lime >= "7.0.0")
				// TODO
				#else
				__renderContext = new GLRenderContext (cast __webgl);
				GL.context = __renderContext;
				
				context3D = new Context3D (this, renderer);
				
				var renderer:DOMRenderer = cast renderer;
				renderer.element.appendChild (__canvas);
				
				__style = __canvas.style;
				__style.setProperty ("position", "absolute", null);
				__style.setProperty ("top", "0", null);
				__style.setProperty ("left", "0", null);
				__style.setProperty (renderer.__transformOriginProperty, "0 0 0", null);
				__style.setProperty ("z-index", "-1", null);
				
				__dispatchCreate ();
				#end
				
			} else {
				
				__dispatchError ();
				
			}
			
			#end
			
		} else if (renderer.__type == CANVAS) {
			
			#if (js && html5 && patch_context3d)
			
			if (__canvas == null)
			{
				if (!createFallbackGLCanvas())
					return;
			}
			
			__canvas.width = stage.stageWidth;
			__canvas.height = stage.stageHeight;
			__renderContext = cast GL.context;
			
			__renderer3d = new OpenGLRenderer(__renderContext);
			cast(renderer, CanvasGLHybridRenderer).renderer3d = __renderer3d;
			cast(renderer, CanvasGLHybridRenderer).canvasResizeMethod = adjustCanvas3dTransforms;
			
			context3D = new Context3D (this, __renderer3d);
			__dispatchCreate ();
			
			#end
		}
		
	}
	
	#if (html5 && patch_context3d)
	
	@:access(lime.ui.Window)
	@:access(lime._backend.html5.HTML5Window)
	private function createFallbackGLCanvas():Bool
	{
		// retrieve context (with logic from HTML5Renderer)
		var webgl:RenderingContext = null;
		
		var window = __stage.window;
		var renderType = window.backend.renderType;
		var forceCanvas = #if (canvas || munit) true #else (renderType == "canvas") #end;
		var forceWebGL = #if webgl true #else (renderType == "opengl" || renderType == "webgl" || renderType == "webgl1" || renderType == "webgl2") #end;
		var allowWebGL2 = #if webgl1 false #else (renderType != "webgl1") #end;
		
		var transparentBackground = Reflect.hasField (window.config, "background") && window.config.background == null;
		var colorDepth = Reflect.hasField (window.config, "colorDepth") ? window.config.colorDepth : 16;
		
		var options = {
			
			alpha: (transparentBackground || colorDepth > 16) ? true : false,
			antialias: Reflect.hasField (window.config, "antialiasing") ? window.config.antialiasing > 0 : false,
			depth: Reflect.hasField (window.config, "depthBuffer") ? window.config.depthBuffer : true,
			premultipliedAlpha: true,
			stencil: Reflect.hasField (window.config, "stencilBuffer") ? window.config.stencilBuffer : false,
			preserveDrawingBuffer: false
			
		};
		
		var canvas:CanvasElement = cast Browser.document.createElement ("canvas");
		webgl = cast canvas.getContextWebGL (options);
		
		/*
		var glContextType = [ "webgl", "experimental-webgl" ];
		
		if (allowWebGL2) {
			
			glContextType.unshift ("webgl2");
			
		}
		
		for (name in glContextType) {
			
			webgl = cast canvas.getContext (name, options);
			
			if (webgl != null) break;
			
		}
		*/
		
		if (webgl == null)
			return false;
		
		canvas.id = "context3DCanvas"; // since we are currently using only the first Stage3D-instance.
		canvas.style.setProperty("z-index", "1");
		canvas.style.setProperty("position", "absolute");
		js.Browser.document.body.appendChild(canvas);
		//window.backend.canvas.parentNode.appendChild(canvas);
		
		__canvas = canvas;
		GL.context = new GLRenderContext (cast webgl);
		
		window.backend.canvas.style.setProperty("z-index", "2");
		if (__stage.color != null)
			__stage.color = null; // make bg of canvas above transparent
		
		return true;
	}
	
	public function adjustCanvas3dTransforms():Void
	{
		//__canvas.width = canvas2d.width;
		//__canvas.height = canvas2d.height;
		//__canvas.style.cssText = canvas2d.style.cssText;
		//__canvas.style.setProperty("position", "relative");
		//__canvas.style.setProperty("top", "-100%");
		
		var canvas2d:CanvasElement = untyped __stage.window.backend.canvas;
		var rect = canvas2d.getBoundingClientRect();
		var style:CSSStyleDeclaration = __canvas.style;
		style.setProperty("left", ""+rect.left);
		style.setProperty("top", ""+rect.top);
		
		__canvas.width = Std.int(rect.right - rect.left);
		__canvas.height = Std.int(rect.bottom - rect.top);
		
		// See HTML5Window for original canvas2d-positioning.
		// But this must be different (it must be exactly beneath 2d)
		// Taking it out of flow with "position: absolute;" should be the best we could do here.
		
		/*
		//style.setProperty ("-webkit-transform", "translateZ(0)", null);
		//style.setProperty ("transform", "translateZ(0)", null);
		var parent = Lib.current.stage.window;
		__canvas.width = Math.round (parent.width * parent.scale);
		__canvas.height = Math.round (parent.height * parent.scale);
		
		__canvas.style.width = parent.width + "px";
		__canvas.style.height = parent.height + "px";
		*/
	}
	
	private function onStageResized(e:Event):Void 
	{
		if (__canvas != null) {
			
			adjustCanvas3dTransforms();
			
		}
	}
	
	#end
	
	
	private function __dispatchError ():Void {
		
		__contextRequested = false;
		dispatchEvent (new ErrorEvent (ErrorEvent.ERROR, false, false, "Context3D not available"));
		
	}
	
	
	private function __dispatchCreate ():Void {
		
		if (__contextRequested) {
			
			__contextRequested = false;
			dispatchEvent (new Event (Event.CONTEXT3D_CREATE));
			
		}
		
	}
	
	
	private function __renderCairo (stage:Stage, renderer:CairoRenderer):Void {
		
		if (!visible) return;
		
		if (__contextRequested) {
			
			__dispatchError ();
			__contextRequested = false;
			
		}
		
	}
	
	
	private function __renderCanvas (stage:Stage, renderer:CanvasRenderer):Void {
		
		if (!visible) return;
		
		#if !patch_context3d
		
		if (__contextRequested) {
			
			__dispatchError ();
			__contextRequested = false;
			
		}
		
		#else
		
		if (__contextRequested && context3D == null) {
			
			__createContext (stage, renderer);
			
		}
		
		if (context3D != null) {
			
			__resetContext3DStates ();
			//GLStage3D.render (this, cast(renderer, CanvasGLHybridRenderer).renderer3d);
			GLStage3D.render (this, __renderer3d);
		}
		
		#end
		
	}
	
	
	private function __renderDOM (stage:Stage, renderer:DOMRenderer):Void {
		
		if (!visible) return;
		
		if (__contextRequested && context3D == null) {
			
			__createContext (stage, renderer);
			
		}
		
		if (context3D != null) {
			
			#if (js && html5)
			GL.context = __renderContext;
			#end
			
			__resetContext3DStates ();
			//DOMStage3D.render (this, renderer);
			
		}
		
	}
	
	
	private function __renderGL (stage:Stage, renderer:OpenGLRenderer):Void {
		
		if (!visible) return;
		
		if (__contextRequested && context3D == null) {
			
			__createContext (stage, renderer);
			
		}
		
		if (context3D != null) {
			
			__resetContext3DStates ();
			GLStage3D.render (this, renderer);
			
		}
		
	}
	
	
	private function __resize (width:Int, height:Int):Void {
		
		#if (js && html5)
		if (__canvas != null) {
			
			__canvas.width = width;
			__canvas.height = height;
			
		}
		#end
		
	}
	
	
	private function __resetContext3DStates ():Void {
		
		// TODO: Better blend mode fix
		context3D.__updateBlendFactors ();
		// TODO: Better viewport fix
		context3D.__updateBackbufferViewport ();
		
	}
	
	
	private function get_x ():Float {
		
		return __x;
		
	}
	
	
	private function set_x (value:Float):Float {
		
		if (__x == value) return value;
		
		__x = value;
		
		if (context3D != null) {
			
			context3D.__updateBackbufferViewport ();
			
		}
		
		return value;
		
	}
	
	
	private function get_y ():Float {
		
		return __y;
		
	}
	
	
	private function set_y (value:Float):Float {
		
		if (__y == value) return value;
		
		__y = value;
		
		if (context3D != null) {
			
			context3D.__updateBackbufferViewport ();
			
		}
		
		return value;
		
	}
	
	
}