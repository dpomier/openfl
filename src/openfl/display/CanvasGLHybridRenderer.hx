package openfl.display;


import lime.graphics.CanvasRenderContext;

#if (js && html5)
import js.Browser;
#end

#if !openfl_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end

@:access(openfl.display.OpenGLRenderer)
@:access(openfl.display.DisplayObject)
@:access(openfl.display.IBitmapDrawable)
@:access(openfl.display.Stage)
@:access(openfl.display.Stage3D)
@:allow(openfl._internal.renderer.canvas)
@:allow(openfl.display)

/**
 * Allows siultaneous rendering to stage3D.
 * Uses an extra webgl context of a separate canvas element.
 */
class CanvasGLHybridRenderer extends CanvasRenderer {
	
	public var renderer3d:OpenGLRenderer;
	public var canvasResizeMethod:Void->Void;
	
	private function new (context:CanvasRenderContext) {
		
		super (context);
		
	}
	
	private override function __clear ():Void {
		
		super.__clear();
		
		// don't know if this is really needed
		if (renderer3d != null)
		{
			renderer3d.__clear();
		}
	}
	
	private override function __resize (width:Int, height:Int):Void {
		
		super.__resize(width, height);
		
		if (renderer3d != null)
		{
			renderer3d.__resize(width, height);
		}
		
		#if (html5 && patch_context3d)
		if (canvasResizeMethod != null)
			Reflect.callMethod(null, canvasResizeMethod, []);
		#end
	}
}