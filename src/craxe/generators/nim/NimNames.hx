package craxe.generators.nim;
using  StringTools;

class NimNames {

	static var nimReserved = [
		"block" => "vBlock",
		"const" => "vConst",
		"let" => "vLet",
		"yield" => "vYield", 
		"iterator" => "vIterator",
		"converter" => "vConverter",
		"method" => "vMethod",
		"proc" => "vProc",
	];

	static public inline function fixReserved(name: String) {
		final fix = nimReserved.get(name);
		return if (fix != null) fix else name;
	}

	static public inline function fixLocalVarName(name:String):String {
		return if (name.startsWith("__")) "ls_" + name.substr(2) 
			else if (name.startsWith("_")) "l_" + name.substr(1) 
			else fixReserved(name.replace("__", ""));
	}

	static public inline function fixFieldVarName(name:String):String {
		return if (name.startsWith("__")) "fs_" + name.substr(2) 
			else if (name.startsWith("_")) "f_" + name.substr(1) 
			else fixReserved(name.replace("__", ""));
	}
}
