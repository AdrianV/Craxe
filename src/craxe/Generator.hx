package craxe;

import haxe.macro.Compiler;
import craxe.common.ast.type.ClassInfo;
import haxe.PosInfos;
import haxe.Log;
import haxe.macro.Type;
import craxe.common.ast.CommonAstPreprocessor;
import craxe.common.generator.BaseGenerator;
import craxe.common.compiler.BaseCompiler;

/**
 * Code generator
 */
class Generator {
	#if macro

	public static function generate() {
		//Compiler.define('cpp', '0');
		//Compiler.define('cppia', '0');
		//Compiler.define('nim');
		haxe.macro.Context.onGenerate(onGenerate);
	}
	#end

	/**
	 * Callback on generating code from context
	 */
	public static function onGenerate(types:Array<Type>):Void {
		haxe.macro.Context.onAfterGenerate(() -> {
			run(types);
		});
	}

	static function run(types:Array<Type>) {
		var preprocessor = new CommonAstPreprocessor();
		var builder:BaseGenerator = null;
		var compiler:BaseCompiler = null;

		var processed = preprocessor.process(types);
		var classes = processed.classes;
		Log.trace = (v:Dynamic, ?infos:PosInfos) -> {			
			var str = Std.string(v);
			if (infos == null)
				return;
			var items = infos.className.split(".");
			var pstr = items[items.length - 1] + ":" + infos.lineNumber;
			var rest = pstr + " " + str;
			Sys.println(rest);
		};

		#if (nim==1)
		builder = new craxe.generators.nim.NimGenerator(processed);
		compiler = new craxe.generators.nim.NimCompiler();
		#end

		if (builder == null)
			throw "Not supported builder type";

		builder.build();
		compiler.compile();		
	}
}
