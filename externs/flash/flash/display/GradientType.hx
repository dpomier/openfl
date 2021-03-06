package flash.display; #if flash


@:enum abstract GradientType(String) from String to String {
	
	public var LINEAR = "linear";
	public var RADIAL = "radial";
	
}

#else
typedef GradientType = openfl.display.GradientType;
#end