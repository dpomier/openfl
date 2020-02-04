package;

import hxp.*;
import sys.FileSystem;

class RunScript
{
	/*static private function buildDocumentation ():Void {

		var openFLDirectory = PathHelper.getHaxelib (new Haxelib ("openfl"), true);
		var scriptPath = PathHelper.combine (openFLDirectory, "script");
		var documentationPath = PathHelper.combine (openFLDirectory, "documentation");

		PathHelper.mkdir (documentationPath);

		runCommand (scriptPath, "haxe", [ "documentation.hxml" ]);

		FileHelper.copyFile (PathHelper.combine (openFLDirectory, "haxedoc.xml"), documentationPath + "/openfl.xml");

		runCommand (documentationPath, "haxedoc", [ "openfl.xml", "-f", "openfl", "-f", "flash" ]);

	}*/
	public static function main()
	{
		var args = Sys.args();
		var cacheDirectory = Sys.getCwd();
		var workingDirectory = args.pop();

		try
		{
			Sys.setCwd(workingDirectory);
		}
		catch (e:Dynamic)
		{
			Log.error("Cannot set current working directory to \"" + workingDirectory + "\"");
		}

		Haxelib.workingDirectory = workingDirectory;

		if (args.length > 1 && args[0] == "create")
		{
			// args[1] = "openfl:" + args[1];
		}
		else if (args.length > 0 && args[0] == "setup")
		{
			var limeDirectory = Haxelib.getPath(new Haxelib("lime"));

			if (limeDirectory == null || limeDirectory == "" || limeDirectory.indexOf("is not installed") > -1)
			{
				Sys.command("haxelib install lime");
			}
		}
		else if (args.length > 0 && args[0] == "process")
		{

			var toolsPath = checkTools(workingDirectory);

			Sys.exit(Sys.command("neko", [toolsPath].concat(Sys.args())));
			return;
		}
		else if (args.length > 1 && args[0] == "rebuild")
		{
			checkTools(workingDirectory, args[1] == "tools");
		}
		else if (args.length > 1 && args[0] == "scope")
		{
			switch args[1]
			{
				case "create":
					System.makeDirectory(".openfl");

				case "delete":
					System.removeDirectory(".openfl");

				default:
					Log.error("Incorrect arguments for command 'scope'");
					return;
			}
		}

		Sys.exit(Sys.command("haxelib run lime " + args.join(" ") + " -openfl"));
	}

	private static function directoryExist(path:String):Bool
	{
		return FileSystem.exists(path) && FileSystem.isDirectory(path);
	}

	private static function hasTools(directory:String):Bool
	{
		return FileSystem.exists(directory + "/tools.n");
	}

	private static function checkTools(workingDirectory:String, rebuild:Bool = false):String
	{
		var openflDirectory = Haxelib.getPath(new Haxelib("openfl"), true);
		var scriptsDirectory = Path.combine(openflDirectory, "scripts");

		if (directoryExist(workingDirectory + "/.openfl"))
		{
			if (rebuild || !hasTools(workingDirectory + "/.openfl"))
			{
				rebuildTools(scriptsDirectory, workingDirectory + "/.openfl");
			}

			return workingDirectory + "/.openfl/tools.n";
		}
		else
		{
			if (rebuild || !hasTools(scriptsDirectory))
			{
				rebuildTools(scriptsDirectory);
			}

			return scriptsDirectory + "/tools.n";
		}
	}

	private static function rebuildTools(scriptsDirectory:String, ?targetDirectory:String, rebuildBinaries = true):Void
	{
		if (targetDirectory == null)
		{
			targetDirectory = scriptsDirectory;
		}

		HXML.buildFile(scriptsDirectory + "/tools.hxml", targetDirectory);
	}
}
