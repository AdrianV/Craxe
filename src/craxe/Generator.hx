package craxe;

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
		haxe.macro.Context.onGenerate(onGenerate);
	}
	#end

	/**
	 * Callback on generating code from context
	 */
	public static function onGenerate(types:Array<Type>):Void {
		var preprocessor = new CommonAstPreprocessor();
		var builder:BaseGenerator = null;
		var compiler:BaseCompiler = null;

		var processed = preprocessor.process(types);
		var classes = processed.classes;
		#if (false)
		haxe.macro.Context.onAfterGenerate(() -> {
			if (classes != null) {
				for (c in classes) {
					final m = c.classType.name;
					try {
						final all = haxe.macro.Context.getModule(m);
						trace('module $m data: ${all.length}');
					} catch (e) {
						trace('module $m not found');
					}
				}
	
			}
		});
		#end

		Log.trace = (v:Dynamic, ?infos:PosInfos) -> {			
			var str = Std.string(v);
			if (infos == null)
				return;
			var items = infos.className.split(".");
			var pstr = items[items.length - 1] + ":" + infos.lineNumber;
			var rest = pstr + " " + str;
			Sys.println(rest);
		};

		#if nim
		builder = new craxe.generators.nim.NimGenerator(processed);
		compiler = new craxe.generators.nim.NimCompiler();
		#end

		if (builder == null)
			throw "Not supported builder type";

		builder.build();
		compiler.compile();
	}
}
