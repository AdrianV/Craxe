package craxe.generators.nim;

import craxe.common.ast.type.*;
import craxe.common.IndentStringBuilder;
import craxe.generators.nim.type.TypeResolver;

/**
 * Code generator for interface
 */
class InterfaceGenerator {
	/**
	 * Constructor
	 */
	public function new() {}

	/**
	 * Generate tuple object with interface fields
	 */
	public function generateInterfaceObject(sb:IndentStringBuilder, interfaceInfo:InterfaceInfo) {
		var iname = interfaceInfo.classType.name;
		sb.add('${iname} = tuple[');
		sb.addNewLine(Inc);
		sb.add("obj : ref RootObj");
		for (field in interfaceInfo.fields) {
			sb.add(", ");
			sb.addNewLine(Same);
			sb.add(NimNames.normalize(field.name));
			sb.add(" : ptr ");
			sb.add(TypeResolver.resolve(field.type));
		}

		for (meth in interfaceInfo.methods) {
			sb.add(", ");
			sb.addNewLine(Same);
			sb.add(meth.name);
			sb.add(" : ");
			sb.add("proc (");
			switch (meth.type) {
				case TFun(args, ret):
					var resolved = TypeResolver.resolveArguments(args);
					if (resolved.length > 0) {
						var sargs = resolved.map(x -> {
							return '${x.name}:${x.t}';
						}).join(", ");
						sb.add(sargs);
					}
					sb.add(") : ");
					sb.add(TypeResolver.resolve(ret));
				case v:
					throw 'Unsupported ${v}';
			}
		}

		sb.addNewLine(Dec);
		sb.add("]");
	}

	/**
	 * Generate converter to interface for class
	 */
	public function generateInterfaceConverter(sb:IndentStringBuilder, classInfo:ClassInfo, interfaceInfo:InterfaceInfo) {
		var iname = interfaceInfo.classType.name;
		var cname = classInfo.classType.name;
		sb.add('proc to${iname}(this:${cname}) : ${iname} = ');
		sb.addNewLine(Inc);
		sb.add("return (");
		sb.addNewLine(Inc);

		sb.add("obj: this");

		for (field in interfaceInfo.fields) {
			final fname = NimNames.fixed(field.name);
			sb.add(", ");
			sb.addNewLine(Same);
			sb.add(fname);
			sb.add(" : addr this.");
			sb.add(fname);
		}

		for (meth in interfaceInfo.methods) {
			sb.add(", ");
			sb.addNewLine(Same);
			sb.add(meth.name);
			sb.add(" : ");
			sb.add("proc (");
			switch (meth.type) {
				case TFun(args, ret):
					var resolved = TypeResolver.resolveArguments(args);
					if (resolved.length > 0) {
						var sargs = resolved.map(x -> {
							return '${x.name}:${x.t}';
						}).join(", ");
						sb.add(sargs);
					}

					sb.add(") : ");
					sb.add(TypeResolver.resolve(ret));
					sb.add(' = this.${meth.name}(');
					if (resolved.length > 0) {
						var sargs = resolved.map(x -> x.name).join(", ");
						sb.add(sargs);
					}
					sb.add(")");
				case v:
					throw 'Unsupported ${v}';
			}
		}

		sb.addNewLine(Dec);
		sb.add(")");
		sb.addBreak();
	}

	/**
	 * Generate type checking for interface
	 */
	public function generateTypeCheck(sb:IndentStringBuilder, interfaceInfo:ClassInfo) {}
}
