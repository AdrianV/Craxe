package craxe.generators.nim;

import haxe.ds.StringMap;
import craxe.common.ast.ArgumentInfo;
import craxe.common.ast.PreprocessedTypes;
import craxe.common.ast.EntryPointInfo;
import craxe.common.ContextMacro;
import haxe.macro.Type;
import haxe.io.Path;
import sys.io.File;
import sys.FileSystem;
import craxe.common.ast.type.*;
import craxe.common.IndentStringBuilder;
import craxe.common.generator.BaseGenerator;
import craxe.generators.nim.type.*;
import craxe.generators.nim.*;

using craxe.common.ast.MetaHelper;

/**
 * Builder for nim code
 */
class NimGenerator extends BaseGenerator {
	/**
	 * Default out file
	 */
	static public inline final DEFAULT_OUT = "main.nim";

	/**
	 * Type context
	 */
	final typeContext:TypeContext;

	/**
	 * Type resolver
	 */
	final typeResolver:TypeResolver;

	/**
	 * Code generator for expressions
	 */
	final methodBodyGenerator:MethodExpressionGenerator;

	/**
	 * Add code helpers to header
	 */
	function addCodeHelpers(sb:IndentStringBuilder) {
		var header = ContextMacro.getDefines().get("source-header");

		sb.add('# ${header}');
		sb.addNewLine();
		sb.add('# Hail to Mighty CRAXE!!!');
		sb.addNewLine();
		sb.addNewLine(None, true);
		sb.add('{.experimental: "codeReordering".}');
		sb.addBreak();

		sb.add('import craxecore');
		sb.addNewLine();

		var reqHash = new StringMap<String>();
		for (item in types.classes) {
			var req = item.classType.meta.getMetaValue(":require");
			if (req != null)
				reqHash.set(req, req);
		}
		for (key => _ in reqHash) {
			sb.add('import ${key}');
			sb.addNewLine();
		}

		sb.addBreak();
	}

	/**
	 * Generate fields for type
	 * Example:
	 *
	 *	MyType = ref object of RootObject
	 *		field1 : int
	 * 		field2 : float
	 */
	function generateTypeFields(sb:IndentStringBuilder, args:Array<ArgumentInfo>) {
		for (arg in args) {
			sb.add(NimNames.fixFieldVarName(arg.name));
			sb.add(" : ");
			sb.add(typeResolver.resolve(arg.t));
			sb.addNewLine(Same);
		}
	}

	function generateEnumArgumentsImpl(sb:IndentStringBuilder, args:Array<ArgumentInfo>) {
		for (i in 0...args.length) {
			var arg = args[i];
			sb.add(arg.name);
			sb.add(":");
			sb.add(typeResolver.resolve(arg.t));
			if (i + 1 < args.length)
				sb.add(", ");
		}
	}

	/**
	 * Generate function arguments
	 * Example:
	 *
	 * 	proc someproc(arg1:int, arg2:float) =
	 */
	function generateFuncArguments(sb:IndentStringBuilder, args:Array<{v:TVar, value:Null<TypedExpr>}>) : Array<{i: Int, name: String}>
	{
		var anons = [];
		for (i => arg in args) {
			final name = MethodExpressionGenerator.scopes.createVar(arg.v, true);
			final tn = typeResolver.resolve(arg.v.t);
			sb.add('$name: $tn');
			switch arg.v.t {
				case TAnonymous(a):
					anons.push({i: i, name: name});
				case _:
			}
			if (arg.value != null) switch arg.value.expr {
				case null:
				case TConst(c): 
					sb.add(" = ");
					methodBodyGenerator.generateTConst(sb, c);
				case v: throw 'unsupported $v';
			}
			if (i + 1 < args.length)
				sb.add(", ");
		}
		return anons;
	}

	/**
	 * Generate function arguments for Abstract type
	 */
	function generateFuncArgumentsAbstract(sb:IndentStringBuilder, abstr:AbstractType, args:Array<{v: TVar}>, isStatic: Bool) {
		for (i in 0...args.length) {
			var arg = args[i].v;
			final name = MethodExpressionGenerator.scopes.createVar(arg, true);
			sb.add(name);
			sb.add(":");
			if ( !isStatic && i == 0) {
				sb.add('${abstr.name}Abstr');
			} else {
				sb.add(typeResolver.resolve(arg.t));
			}
			if (i + 1 < args.length)
				sb.add(", ");
		}
	}

	/**
	 * Generate types for enum
	 */
	function generateEnumFields(sb:IndentStringBuilder, type:Type):Void {
		switch (type) {
			case TEnum(_, _):
			// skip
			case TFun(args, _):
				generateTypeFields(sb, args);
			case v:
				sb.add(typeResolver.resolve(v));
		}
	}

	/**
	 * Generate arguments for enum
	 */
	function generateEnumArguments(sb:IndentStringBuilder, type:Type):Void {
		switch (type) {
			case TEnum(_, _):
			// skip
			case TFun(args, _):
				generateEnumArgumentsImpl(sb, args);
			case v:
				sb.add(typeResolver.resolve(v));
		}
	}

	/**
	 * Generate constructor block for enum
	 */
	function generateEnumConstructor(sb:IndentStringBuilder, enumInfo:EnumInfo, constr:EnumField):Void {
		var index = constr.index;
		var type = constr.type;
		var enumName = '${enumInfo.enumType.name}${constr.name}';

		switch (type) {
			case TEnum(_, _):
				sb.add('proc new${enumName}(');
				sb.add(') : ${enumName} {.inline.} =');
				sb.addNewLine(Inc);
				sb.add('${enumName}(index: ${index}');
			case TFun(args, _):
				var params = typeResolver.resolveParameters(enumInfo.params);
				sb.add('proc new${enumName}${params}(');
				generateEnumArguments(sb, type);
				sb.add(') : ${enumName}${params} {.inline.} =');
				sb.addNewLine(Inc);
				sb.add('${enumName}${params}(index: ${index}');

				sb.add(", ");
				for (i in 0...args.length) {
					var arg = args[i];
					sb.add('${arg.name}: ${arg.name}');
					if (i + 1 < args.length)
						sb.add(", ");
				}
			case v:
				throw 'Unsupported paramter ${v}';
		}

		sb.add(')');
		sb.addBreak();
	}

	/**
	 * Generate enum helpers
	 */
	function generateEnumHelpers(sb:IndentStringBuilder, enumInfo:EnumInfo, constr:EnumField) {
		var enumName = '${enumInfo.enumType.name}${constr.name}';
		sb.add('proc `$`(this: ${enumName}) : system.string {.inline.} =');
		sb.addNewLine(Inc);
		sb.add("result = $this[]");
		sb.addBreak();

		sb.add('proc `==`(e1:${enumName}, e2:${enumName}) : bool {.inline.} =');
		sb.addNewLine(Inc);
		sb.add("result = e1[] == e2[]");
		sb.addBreak();
	}

	/**
	 * Generate code for enums
	 */
	function buildEnums(sb:IndentStringBuilder) {
		var enums = types.enums;
		if (enums.length < 1)
			return;

		// Generate types for enums
		sb.add("type ");
		sb.addNewLine(Inc);

		for (en in enums) {
			var enumName = en.enumType.name;
			sb.add('${enumName} = ref object of HaxeEnum');
			sb.addNewLine(Same);
			sb.addNewLine(Same, true);

			var params = typeResolver.resolveParameters(en.params);
			for (constr in en.enumType.constructs) {
				switch constr.type {
					case TEnum(_, _):
						sb.add('${enumName}${constr.name} = ref object of ${enumName}');
					case TFun(_, _):
						sb.add('${enumName}${constr.name}${params} = ref object of ${enumName}');
						sb.addNewLine(Inc);
						generateEnumFields(sb, constr.type);
						sb.addNewLine(Dec);
					case v:
						throw 'Unsupported ${v}';
				}

				sb.addNewLine(Same, true);
			}
		}

		sb.addNewLine();
		sb.addNewLine(None, true);

		// Generate enums constructors
		for (en in enums) {
			for (constr in en.enumType.constructs) {
				generateEnumConstructor(sb, en, constr);
				generateEnumHelpers(sb, en, constr);
			}
		}
	}

	/**
	 * Generate code for interfaces
	 */
	function buildInterfaces(sb:IndentStringBuilder) {
		if (!typeContext.hasInterfaces)
			return;

		// Generate types for enums
		sb.add("type ");
		sb.addNewLine(Inc);

		var interGenerateor = new InterfaceGenerator();
		for (inter in typeContext.interfaceIterator()) {
			interGenerateor.generateInterfaceObject(sb, inter, typeResolver);
		}

		sb.addBreak();

		for (cls in typeContext.classIterator()) {
			for (inter in cls.classType.interfaces) {
				var cinter = typeContext.getInterfaceByName(inter.t.get().name);
				interGenerateor.generateInterfaceConverter(sb, cls, cinter, typeResolver);
			}
		}

		sb.addBreak();
	}

	/**
	 * Build typedefs
	 */
	function buildTypedefs(sb:IndentStringBuilder) {
		var typedefs = types.typedefs;
		var anons = typeContext.allAnonymous();
		if (typedefs.length < 1 && anons.length < 1)
			return;

		sb.add("### Typedefs");
		sb.addNewLine();
		sb.add("type ");
		sb.addNewLine(Inc);

		for (td in typedefs) {
			switch (td.typedefInfo.type) {
				case TInst(t, _):
					sb.add('${td.typedefInfo.name} = ${t.get().name}');
					sb.addNewLine(Same);
				case TFun(_, _):
					var tpname = typeResolver.resolve(td.typedefInfo.type);
					sb.add('${td.typedefInfo.name} = ${tpname}');
					sb.addNewLine(Same);
				case TAbstract(_, _):
					var tpname = typeResolver.resolve(td.typedefInfo.type);
					sb.add('${td.typedefInfo.name} = ${tpname}');
					sb.addNewLine(Same);
				case TAnonymous(a):
				case v:
					throw 'Unsupported ${v}';
			}
		}

		for (an in anons) {
			sb.add('${an.name} = ref object of DynamicHaxeObject');
			sb.addNewLine(Inc);
			for (fld in an.fields) {
				var ftp = typeResolver.resolve(fld.type);
				sb.add('${fld.name}:${ftp}');
				sb.addNewLine(Same);
			}
			sb.addNewLine(Dec);
			sb.addNewLine(Same, true);
		}

		sb.addNewLine();
	}

	/**
	 * Generate anon converters to dynamic
	 */
	function buildAnonMakeDynamic(sb:IndentStringBuilder) {
		var anons = typeContext.allAnonymous();
		if (anons.length < 1)
			return;

		for (an in anons) {
			var anonName = an.name;

			sb.add('proc getFields(this:${anonName}):HaxeArray[system.string] {.inline.} =');
			sb.addNewLine(Inc);
			var fldNames = an.fields.map(x -> '"${x.name}"').join(", ");
			sb.add('return HaxeArray[system.string](data: @[${fldNames}])');

			sb.addBreak();

			sb.add('proc getFieldByNameInternal(this:${anonName}, name:system.string):Dynamic =');
			sb.addNewLine(Inc);
			if (an.fields.length > 0) {
				sb.add("case name");
				sb.addNewLine(Same);
				for (i in 0...an.fields.length) {
					var fld = an.fields[i];
					sb.add('of "${fld.name}": return toDynamic(this.${fld.name})');
					sb.addNewLine(Same);
				}
			}

			sb.addBreak();

			sb.add('proc setFieldByNameInternal(this:${anonName}, name:system.string, value:Dynamic):void =');
			sb.addNewLine(Inc);
			if (an.fields.length > 0) {
				sb.add("case name");
				sb.addNewLine(Same);
				for (i in 0...an.fields.length) {
					var fld = an.fields[i];
					sb.add('of "${fld.name}": this.${fld.name} = fromDynamic(value, typeof(this.${fld.name}))');
					sb.addNewLine(Same);
				}
			}

			sb.addBreak();

			sb.add('proc makeDynamic(this:${anonName}):Dynamic {.inline.} =');
			sb.addNewLine(Inc);

			sb.add("this.getFields = proc():HaxeArray[system.string] = getFields(this)");
			sb.addNewLine(Same);
			sb.add("this.getFieldByName = proc(name:system.string):Dynamic = getFieldByNameInternal(this, name)");
			sb.addNewLine(Same);
			sb.add("this.setFieldByName = proc(name:system.string, value:Dynamic):void = setFieldByNameInternal(this, name, value)");
			sb.addNewLine(Same);
			sb.add("return toDynamic(this)");
			sb.addBreak();
		}

		sb.addNewLine();
	}

	/**
	 * Generate code for instance fields
	 */
	function generateInstanceFields(sb:IndentStringBuilder, fields:Array<ClassField>, isHashable:Bool) {
		var iargs = [];
		for (ifield in fields) {
			switch (ifield.kind) {
				case FVar(_, _):
					iargs.push({
						name: ifield.name,
						opt: false,
						t: ifield.type
					});
				case FMethod(_):
				case v:
					throw 'Unsupported ${v}';
			}
		}
		sb.addNewLine(Inc);
		generateTypeFields(sb, iargs);
		if (isHashable)
			sb.add("hash : proc():int");
		sb.addNewLine(Dec);
		sb.addNewLine(Same, true);
	}

	/**
	 * Build class fields
	 */
	function generateClassInfo(sb:IndentStringBuilder, cls:ClassInfo) {
		var clsName = cls.classType.name;
		var params = typeResolver.resolveParameters(cls.params);

		var baseTypeName = if (typeContext.isDynamicSupported(clsName)) {
			"DynamicHaxeObject";
		} else {
			"HaxeObject";
		}

		var superName = if (cls.classType.superClass != null) {
			var superType = cls.classType.superClass.t.get();
			var spname = superType.name;
			var spParams = typeResolver.resolveParameters(cls.classType.superClass.params);
			'${spname}${spParams}';
		} else {
			baseTypeName;
		}

		if (true || cls.fields.length > 0 || cls.methods.length > 0) {
			var line = '${clsName}${params} = ref object of ${superName}';
			sb.add(line);
			sb.addNewLine(Same);
			generateInstanceFields(sb, cls.fields, cls.isHashable);	
		}

		var staticFields = cls.classType.statics.get();
		if (staticFields.length > 0) {
			var line = '${cls.classType.name}Static = object of HaxeObject';
			sb.add(line);
			sb.addNewLine(Same);
			//sb.addNewLine(Same, true);
			generateInstanceFields(sb, staticFields, false);	
		}
	}

	/**
	 * Generate abstract impl code
	 */
	function generateAbstractImpl(sb:IndentStringBuilder, cls:ClassInfo, abstr:AbstractType) {
		var name = abstr.name;
		var typeName = typeResolver.resolve(abstr.type);
		var params = typeResolver.resolveParameters(abstr.params.map(x -> x.t));

		var line = '${name}Abstr${params} = ${typeName}';
		sb.add(line);
		sb.addNewLine(Same);
	}

	/**
	 * Generate structure info
	 */
	function generateStructureInfo(sb:IndentStringBuilder, cls:StructInfo) {
		var structName = cls.classType.name;
		var line = '${structName} = object of Struct';
		sb.add(line);
		sb.addNewLine(Same);

		generateInstanceFields(sb, cls.fields, cls.isHashable);
	}

	/**
	 * Build static class initialization
	 */
	function generateStaticClassInit(sb:IndentStringBuilder, cls:ClassInfo) {
		var staticFields = cls.classType.statics.get();
		if (staticFields.length < 1)
			return;

		var clsName = typeResolver.getFixedTypeName(cls.classType.name);
		var hasStaticMethod = false;
		var hasStaticVar = false;
		for (field in staticFields) {
			switch (field.kind) {
				case FMethod(k):
					hasStaticMethod = true;
					break;
				case FVar(read, write):
					hasStaticVar = true;
					break;
				case v:
					throw 'Unsupported paramter ${v}';
			}
		}

		if (hasStaticMethod || hasStaticVar) {
			sb.add('let ${clsName}StaticInst = ${clsName}Static(');
			if (hasStaticVar) {
				var first = true;
				for (f in staticFields) switch f.kind {
					case FVar(read, write):
						if (f.expr != null) {
							if (!first) sb.add(", ");
							sb.add('${f.name} :');
							methodBodyGenerator.generateTBlockSingleExpression(sb, f.expr(), false);
							first = false;
						}
					case _:
				}
			}
			sb.add(")");
			sb.addBreak();
		}
	}

	/**
	 * Generate method body
	 */
	function generateMethodBody(sb:IndentStringBuilder, classContext:ClassInfo, expression:TypedExpr, returnType:Type = null) {
		methodBodyGenerator.generateMethodBody(sb, classContext, expression, returnType);

		sb.addNewLine();
		sb.addNewLine(None, true);
	}

	function constructorIsPure(constrExpr: TypedExpr): Bool {
		switch constrExpr.expr {
			case TFunction(_.expr.expr => TBlock(el)):
				for (e in el) {
					switch e.expr {
						case TBinop(OpAssign, _.expr => TField(_.expr => TConst(TThis), FInstance(_, _, _)) , _):
						case _: return false;
					}
				}
				return true;
			case _:
		}
		return false;
	}

	function buildPureConstructor(sb: IndentStringBuilder, constrExpr: TypedExpr) {
		switch constrExpr.expr {
			case TFunction(_.expr.expr => TBlock(el)):
				var first = true;
				for (e in el) {
					switch e.expr {
						case TBinop(OpAssign, _.expr => TField(_.expr => TConst(TThis), FInstance(_, _, cf)) , e2):
							final fname = NimNames.fixFieldVarName(cf.get().name);
							if ( ! first) sb.add(",");
							sb.add('$fname: ');
							methodBodyGenerator.generateTBlockSingleExpression(sb, e2, false);
							first = false;
						case _:
					}
				}
			case _:
		}
	}

	/**
	 * Build class constructor
	 */
	function generateClassConstructor(sb:IndentStringBuilder, cls:ClassInfo) {
		if (cls.classType.constructor == null)
			return;

		var constructor = cls.classType.constructor.get();
		var className = cls.classType.name;
		var superName:String = null;
		var superConstructor:ClassField = null;

		if (cls.classType.superClass != null) {
			var superCls = cls.classType.superClass.t.get();
			superName = superCls.name;
			if (superCls.constructor != null)
				superConstructor = superCls.constructor.get();
		}
		final constrExp = constructor.expr();
		switch [constrExp.t, constrExp.expr] {
			case [TFun(_, _), TFunction(tfunc)]:
				MethodExpressionGenerator.scopes.newScope();
				var params = typeResolver.resolveParameters(cls.params);

				final supportsDynamic = typeContext.isDynamicSupported(className);
				// Generate procedures for dynamic support
				if (supportsDynamic) {
					var fields = cls.classType.fields.get();

					sb.add('proc getFields(this:${className}):HaxeArray[system.string] {.inline.} =');
					sb.addNewLine(Inc);
					var fldNames = fields.map(x -> '"${x.name}"').join(", ");
					sb.add('return HaxeArray[system.string](data: @[${fldNames}])');

					sb.addBreak();
					
					sb.add('proc getFieldByNameInternal${params}(this:${className}${params}, name:system.string):Dynamic =');
					sb.addNewLine(Inc);
					if (fields.length > 0) {
						sb.add("case name");
						sb.addNewLine(Same);
						for (i in 0...fields.length) {
							var fld = fields[i];
							sb.add('of "${fld.name}": return toDynamic(this.${fld.name})');
							sb.addNewLine(Same);
						}
					} else {
						sb.add("discard");
					}
					sb.addBreak();

					sb.add('proc fromDynamic${params}(this:Dynamic):${className}${params} =');
					sb.addNewLine(Inc);
					sb.add('cast[${className}${params}](this.fclass)');
					sb.addBreak();
				}
				final isPure = constructorIsPure(constrExp);
				var sbCon = new IndentStringBuilder();
				var sbArgs = new IndentStringBuilder();
				var anons = generateFuncArguments(sbArgs, tfunc.args);
				if (! isPure || supportsDynamic) {
					// Generate constructor
					MethodExpressionGenerator.scopes.newScope();
					sbCon.add('proc new${className}${params}(');
					sbCon.add(sbArgs.toString());
					sbCon.add(') : ${className}${params} {.inline.}');
					sb.add(sbCon.toString());
				} else {
					sb.add('template new${className}${params}(');
					sb.add(sbArgs.toString());
					sb.add(') : ${className}${params} =');
					sb.addNewLine(Inc);
					sb.add('${className}${params}(');
					buildPureConstructor(sb, constrExp);
					sb.add(")");
					sb.addNewLine(Dec);
				}
				sb.addBreak();

				// Generate init proc for haxe "super(params)"
				MethodExpressionGenerator.scopes.newScope();
				sb.add('proc init${className}${params}(this:${className}${params}');
				if (tfunc.args.length > 0) {
					sb.add(", ");
					sb.add(sbArgs.toString());
				}
				sb.add(') =');
				sb.addNewLine(Inc);

				if (cls.isHashable) {
					sb.add("this.hash = proc():int = this.hashCode()");
					sb.addNewLine(Same);
				}
				methodBodyGenerator.generateShadowAnons(sb, anons);

				generateMethodBody(sb, cls, constrExp);
				sb.addNewLine(Dec);	
				MethodExpressionGenerator.scopes.popScope();
				if (! isPure || supportsDynamic) {
					// Generate constructor
					sbCon.add(" =");
					sb.add(sbCon.toString());
					sb.addNewLine(Inc);
					sb.add('var this = ${className}${params}()');
					sb.addNewLine(Same);
					sb.add('init${className}(this');
					if (tfunc.args.length > 0) {
						sb.add(", ");
						sb.add(tfunc.args.map(x -> MethodExpressionGenerator.scopes.getVarName(x.v.name, x.v.id)).join(", "));
					}
					sb.add(')');

					if (supportsDynamic) {
						sb.addNewLine(Same);
						sb.add("this.getFields = proc():HaxeArray[system.string] = getFields(this)");
						sb.addNewLine(Same);
						sb.add("this.getFieldByName = proc(name:system.string):Dynamic = getFieldByNameInternal(this, name)");
					}

					sb.addNewLine(Same);
					sb.add("return this");
					sb.addBreak();
					MethodExpressionGenerator.scopes.popScope();
				}

				MethodExpressionGenerator.scopes.popScope();
			case [v, _]:
				throw 'Unsupported paramter ${v}';
		}
	}

	/**
	 * Build class method
	 */
	function generateClassMethod(sb:IndentStringBuilder, cls:ClassInfo, method:ClassField, isStatic:Bool) {
		final expr = method.expr();
		switch [expr.t, expr.expr] {
			case [TFun(_, ret), TFunction(tfunc)]:
				MethodExpressionGenerator.scopes.newScope();
				var clsName = !isStatic ? cls.classType.name : '${cls.classType.name}Static';
				sb.add('proc ${method.name}(this:${clsName}');
				var anons = null;
				if (tfunc.args.length > 0) {
					sb.add(", ");
					anons = generateFuncArguments(sb, tfunc.args);
				}
				sb.add(") : ");
				sb.add(typeResolver.resolve(ret));
				sb.add(" =");
				sb.addNewLine(Inc);
				if (anons != null && anons.length > 0) 
					methodBodyGenerator.generateShadowAnons(sb, anons);
				generateMethodBody(sb, cls, expr, ret);
				MethodExpressionGenerator.scopes.popScope();
			case [v, _]:
				throw 'Unsupported paramter ${v}';
		}
	}

	/**
	 * Build class method for abstract
	 */
	function generateMethodAbstract(sb:IndentStringBuilder, cls:ClassInfo, abstr:AbstractType, method:ClassField, isStatic:Bool) {
		final expr = method.expr();
		switch [expr.t, expr.expr] {
			case [TFun(_, ret), TFunction(tfunc)]:
				MethodExpressionGenerator.scopes.newScope();
				var name = abstr.name;
				var methname = StringTools.replace(method.name, "_", "");
				final params = abstr.params.concat(method.params);
				var parstr = typeResolver.resolveParameters(params.map(x -> x.t));

				sb.add('proc ${methname}${name}Abstr${parstr}(');
				if (tfunc.args.length > 0) {
					generateFuncArgumentsAbstract(sb, abstr, tfunc.args, isStatic);
				}
				sb.add(") : ");
				sb.add(typeResolver.resolve(ret));
				sb.add(" =");
				sb.addNewLine(Inc);

				generateMethodBody(sb, cls, expr, ret);
				MethodExpressionGenerator.scopes.popScope();
			case [v, _]:
				throw 'Unsupported paramter ${v}';
		}
	}

	/**
	 * Build class methods and return entry point if found
	 */
	function generateClassMethods(sb:IndentStringBuilder, cls:ClassInfo) {
		for (method in cls.methods) {
			generateClassMethod(sb, cls, method, false);
		}

		switch cls.classType.kind {
			case KAbstractImpl(a):
				for (f in cls.staticFields) {
					if (f.isExtern) continue;
					final info = methodBodyGenerator.getStaticTFieldData(cls.classType, f);
					final ft = typeResolver.resolve(f.type);
					sb.add('var ${info.totalName}: $ft');
					final expr = f.expr();
					if (expr != null) {
						sb.add(" = ");
						methodBodyGenerator.generateTBlockSingleExpression(sb, expr, false);
					}
					sb.addBreak();
				}
			case _:
		}

		for (method in cls.staticMethods) {
			switch (cls.classType.kind) {
				case KNormal:
					generateClassMethod(sb, cls, method, true);
				case KAbstractImpl(a):
					generateMethodAbstract(sb, cls, a.get(), method, true);
				case v:
					throw 'Unsupported ${v}';
			}
		}

		// Generate heplers
		switch cls.classType.kind {
			case KNormal:
				var clsName = cls.classType.name;
				sb.add('proc `$`(this:${clsName}) : system.string {.inline.} = ');
				sb.addNewLine(Inc);
				sb.add('result = "${clsName}"' + " & $this[]");
				sb.addBreak();
			case KAbstractImpl(_):
			case v:
				throw 'Unsupported ${v}';
		}
	}

	/**
	 * Build classes code
	 */
	function buildClasses(sb:IndentStringBuilder) {
		var classes = types.classes;

		if (classes.length < 1)
			return;

		var constrBuilder = new IndentStringBuilder();
		var methBuilder = new IndentStringBuilder();
		// Generate class methods
		for (c in classes) {
			if (c.classType.isExtern == false) {
				if (!c.classType.isInterface) {
					generateClassMethods(methBuilder, c);
				}
			}
		}

		// Generate class constructors
		for (c in classes) {
			if (c.classType.isExtern == false) {
				if (!c.classType.isInterface) {
					generateClassConstructor(constrBuilder, c);
				}
			}
		}

		sb.add("### Classes and structures");
		sb.addNewLine();
		sb.add("type ");
		sb.addNewLine(Inc);

		for (c in classes) {
			if (c.classType.isExtern == false) {
				if (!c.classType.isInterface) {
					switch (c.classType.kind) {
						case KNormal:
							generateClassInfo(sb, c);
						case KAbstractImpl(a):
							generateAbstractImpl(sb, c, a.get());
						case v:
							throw 'Unsupported ${v}';
					}
				}
			}
		}

		sb.addNewLine();

		// Init static classes
		for (c in classes) {
			if (c.classType.isExtern == false) {
				if (!c.classType.isInterface) {
					switch (c.classType.kind) {
						case KNormal:
							generateStaticClassInit(sb, c);
						case KAbstractImpl(_):
						case v:
							throw 'Unsupported ${v}';
					}
				}
			}
		}

		sb.add(constrBuilder.toString());
		sb.add(methBuilder.toString());
		sb.addNewLine(None, true);
	}

	/**
	 * Generate entry point
	 */
	function buildEntryPointMain(sb:IndentStringBuilder, entryPoint:EntryPointInfo) {
		sb.addNewLine(None);
		var clsName = entryPoint.classInfo.classType.name;
		var methodName = entryPoint.method.name;
		sb.add('${clsName}StaticInst.${methodName}()');
	}

	public function new(processed:PreprocessedTypes) {
		super(processed);
		typeContext = new TypeContext(processed);
		typeResolver = new TypeResolver(typeContext);
		methodBodyGenerator = new MethodExpressionGenerator(typeContext, typeResolver);
	}

	/**
	 * Build sources
	 */
	override function build() {
		var nimOut = ContextMacro.getDefines().get("nim-out");
		if (nimOut == null)
			nimOut = DEFAULT_OUT;

		var filename = Path.normalize(nimOut);
		var outPath = Path.directory(filename);
		FileSystem.createDirectory(outPath);

		var codeSb = new IndentStringBuilder();
		buildClasses(codeSb);

		var headerSb = new IndentStringBuilder();

		addCodeHelpers(headerSb);
		buildEnums(headerSb);
		buildTypedefs(headerSb);
		buildAnonMakeDynamic(headerSb);
		buildInterfaces(headerSb);

		if (types.entryPoint != null) {
			codeSb.addNewLine();
			buildEntryPointMain(codeSb, types.entryPoint);
		}

		var buff = new StringBuf();
		buff.add(headerSb.toString());
		buff.add(codeSb.toString());

		File.saveContent(filename, buff.toString());
	}
}
