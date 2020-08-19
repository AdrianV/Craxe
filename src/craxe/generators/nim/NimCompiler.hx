package craxe.generators.nim;

#if macro
import haxe.macro.Context;
#end

import sys.io.Process;
import craxe.common.compiler.BaseCompiler;

/**
 * Compiles nim code
 */
class NimCompiler extends BaseCompiler {
	/**
	 * Constructor
	 */
	public function new() {}

	/**
	 * Compile code
	 */
	override function compile() {
		#if macro
		var defines = haxe.macro.Context.getDefines();
		var out = defines.get("nim-out");
		if (out == null) out = NimGenerator.DEFAULT_OUT;
		if (!sys.FileSystem.exists(out))
			Context.fatalError("Error: output file does not exists", Context.currentPos());
		var params = [];
		params.push(switch defines.get("nim-cmd") {
			case null: "c";
			case v: v;
		});
		switch defines.get("nim-speed") {
			case null | "release": params.push("-d:release");
			case "fastest": params.push("-d:danger");
			case "debug": 
				params.push("-d:debug");
				params.push("--lineDir:on");
				params.push("--debuginfo:on");
			case _: 
		}
		params.push(switch defines.get("nim-gc") {
			case null: "--gc:orc";
			case v: '--gc:$v';
		});
		params = params.concat(switch defines.get("nim-extra") {
			case null: [];
			case v: v.split(" ");
		});
		params.push("--stdout:on");
		params.push(out);
		var proc = new Process("nim", params);
		var errText = proc.stderr.readAll();
		if (errText != null && errText.length > 0) {
			trace(errText);
		} else {
			Sys.println(proc.stdout.readAll());
		}
		proc.close();
		#end
	}
}
