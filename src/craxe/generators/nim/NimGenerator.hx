package craxe.generators.nim;

import haxe.Unserializer.TypeResolver;
import haxe.ds.StringMap;
import craxe.common.ast.ArgumentInfo;
import craxe.common.ast.PreprocessedTypes;
import craxe.common.ast.EntryPointInfo;
import craxe.common.ContextMacro;
import haxe.macro.Type;
import haxe.macro.TypeTools;
import haxe.io.Path;
import sys.io.File;
import sys.FileSystem;
import craxe.common.ast.type.*;
import craxe.common.IndentStringBuilder;
import craxe.common.generator.BaseGenerator;
import craxe.generators.nim.type.*;
import craxe.generators.nim.*;
import craxe.generators.nim.type.TypeResolver;

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
	 * Code generator for expressions
	 */
	final methodBodyGenerator:MethodExpressionGenerator;
	final allMethods = new Array<String>();

	/**
	 * Add code helpers to header
	 */
	var reqHash = new StringMap<Bool>();
	function addCodeHelpers(sb:IndentStringBuilder) {
		var header = ContextMacro.getDefines().get("source-header");

		sb.add('# ${header}');
		sb.addNewLine();
		sb.add('# compiled by xnim');
		sb.addNewLine();
		sb.addNewLine(None, true);
		sb.add('{.experimental: "codeReordering".}');
		sb.addBreak();

		sb.add('import craxecore');
		sb.addNewLine();

		for (item in types.classes) {
			var req = item.classType.meta.getMetaValue(":require");
			if (req != null)
				reqHash.set(req, true);
		}
		function importRequired(ind) {
			var s = "";
			for (key => _ in reqHash) {
				if (ind != null) s += sb.calcIndent(ind);
				s += 'import ${key}\n';
			}
			return Str(s);
		}
		sb.addCallback(importRequired);
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
			sb.add(NimNames.fixed(arg.name));
			sb.add(" : ");
			var tname = TypeResolver.resolve(arg.t);
			final tt = TypeTools.followWithAbstracts(arg.t);
			switch tt {
				case TAnonymous(a): tname += "Wrapper";
				default:
			}
			sb.add(tname);
			sb.addNewLine(Same);
		}
	}

	function generateEnumArgumentsImpl(sb:IndentStringBuilder, args:Array<ArgumentInfo>) {
		for (i in 0...args.length) {
			var arg = args[i];
			sb.add(arg.name);
			sb.add(":");
			sb.add(TypeResolver.resolve(arg.t));
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
			final tn = TypeResolver.resolve(arg.v.t);
			switch arg.v.t {
				case TAnonymous(a), TType(_.get().type => TAnonymous(a),_):
					anons.push({i: i, name: name});
					sb.add('$name: ${tn} | ${tn}Wrapper');
				case var tt: 
					sb.add('$name: $tn');
			}
			if (arg.value != null) switch arg.value.expr {
				case null:
				case TConst(c): 
					sb.add(" = ");
					methodBodyGenerator.generateTConst(sb, c, arg.value.t);
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
	function generateFuncArgumentsAbstract(sb:IndentStringBuilder, abstr:AbstractType, args:Array<{v: TVar, value:Null<TypedExpr>}>, isStatic: Bool) {
		for (i in 0...args.length) {
			var arg = args[i];
			final name = MethodExpressionGenerator.scopes.createVar(arg.v, true);
			sb.add(name);
			sb.add(":");
			if ( !isStatic && i == 0) {
				sb.add('${abstr.name}Abstr');
			} else {
				sb.add(TypeResolver.resolve(arg.v.t));
			}
			if (arg.value != null) switch arg.value.expr {
				case null:
				case TConst(c): 
					sb.add(" = ");
					methodBodyGenerator.generateTConst(sb, c, arg.value.t);
				case v: throw 'unsupported $v';
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
				sb.add(TypeResolver.resolve(v));
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
				sb.add(TypeResolver.resolve(v));
		}
	}

	/**
	 * Generate constructor block for enum
	 */
	function generateEnumConstructor(sb:IndentStringBuilder, enumInfo:EnumInfo, constr:EnumField):Void {
		final index = constr.index;
		final type = constr.type;
		final cname = NimNames.fixed(constr.name);
		final enumName = '${enumInfo.enumName}${cname}';

		switch (type) {
			case TEnum(_, _):
				sb.add('template new${enumName}*(');
				sb.add(') : ${enumName} =');
				sb.addNewLine(Inc);
				sb.add('bind ${enumInfo.enumName}EnumInfo');
				sb.addNewLine(Same);
				sb.add('${enumName}(qindex: ${index}, qinfo: addr ${enumInfo.enumName}EnumInfo');
			case TFun(args, _):
				var params = TypeResolver.resolveParameters(enumInfo.params);
				sb.add('proc new${enumName}${params}*(');
				generateEnumArguments(sb, type);
				sb.add(') : ${enumName}${params} {.inline.} =');
				sb.addNewLine(Inc);
				sb.add('${enumName}${params}(qindex: ${index}, qinfo: addr ${enumInfo.enumName}EnumInfo,');

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
		final cname = NimNames.fixed(constr.name);
		final enumName = '${enumInfo.enumName}${cname}';
		sb.add('proc `$`(this: ${enumName}) : String {.inline.} =');
		sb.addNewLine(Inc);
		sb.add("return $this[]");
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
		var enums = types.enums.filter(e -> ! e.isBuild);
		if (enums.length < 1)
			return;

		// Generate types for enums
		sb.add("type ");
		sb.addNewLine(Inc);

		for (en in enums) {
			en.isBuild = true;
			final enumName = en.enumName;
			sb.add('${enumName} = ref object of HaxeEnum');
			sb.addNewLine(Same);
			sb.addNewLine(Same, true);

			var params = TypeResolver.resolveParameters(en.params);
			for (constr in en.enumType.constructs) {
				final cname = NimNames.fixed(constr.name);
				switch constr.type {
					case TEnum(_, _):
						sb.add('${enumName}${cname} = ref object of ${enumName}');
					case TFun(_, _):
						sb.add('${enumName}${cname}${params} = ref object of ${enumName}');
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
			final enumName = en.enumName;
			final hxName = ObjectType.fullHaxeName(en.enumType);
			final constructs = [for (c in en.enumType.constructs) c];
			constructs.sort((a,b) -> Reflect.compare(a.index, b.index));
			sb.add('var ${enumName}EnumInfo: HaxeEnumInfo');
			sb.addNewLine(Same);
			for (constr in constructs)
				generateEnumConstructor(sb, en, constr);
			sb.add('${enumName}EnumInfo = HaxeEnumInfo(qname: "${hxName}", qvalues: @[');
			sb.addNewLine(Inc);
			var first = true;
			for (constr in constructs) {
				final cname = NimNames.fixed(constr.name);
				if ( ! first) {
					sb.add(",");
					sb.addNewLine(Same);
				} else first = false;
				sb.add('HaxeEnumValueInfo(qname: "${constr.name}", qidx: ${constr.index}${"'"}i32');
				switch constr.type {
					case TFun(args, ret) if (args.length > 0):
						
						sb.add(", qparams: @[");
						sb.addNewLine(Inc);
						for (i => p in args) {
							if (i > 0) {
								sb.add(",");
								sb.addNewLine(Same);
							}
							final pname = NimNames.fixed(p.name);
							sb.add('HaxeEnumParamInfo(qname: "${p.name}", qoffset: addr cast[${enumName}${cname}](0)[].${pname},');
							switch p.t {
								case TFun(_, _):
								default:
									final styp = TypeResolver.resolve(p.t);
									sb.addNewLine(Inc);
									sb.add('qget: proc(this: pointer): Dynamic = toDynamic(cast[ptr ${styp}](this)[]),');
									sb.addNewLine(Same);
									sb.add('qset: proc(this: pointer, v: Dynamic) = cast[ptr ${styp}](this)[] = fromDynamic(v, ${styp})');
									sb.addNewLine(Dec);		
							}
							sb.add(")");
						}
						sb.add("]");
						sb.add(', qcfun: proc(params: seq[Dynamic]): HaxeEnum = ');
						sb.addNewLine(Inc);
						final sparams = [for (i => a in args) 'fromDynamic(params[$i], ${TypeResolver.resolve(a.t)})'].join(", ");
						sb.add('if params.len == ${args.length}: return new${enumName}${cname}($sparams)');
						sb.addNewLine(Dec);
						sb.addNewLine(Dec);
		
					case _:
						sb.add(', qcval: proc(): HaxeEnum = new${enumName}${cname}()');
						sb.addNewLine(Same);
				}
				sb.add(")");
			}
			sb.add('])');
			sb.addNewLine(Dec);

			sb.addNewLine(Same);
			sb.add('register(${enumName}, addr ${enumName}EnumInfo)');
			sb.addNewLine(Same);
			for (constr in constructs) {
				generateEnumHelpers(sb, en, constr);
			}
		}
	}

	/**
	 * Generate code for interfaces
	 */
	function buildInterfaces(sb:IndentStringBuilder) {
		if (!TypeContext.hasInterfaces)
			return;

		// Generate types for interfaces
		sb.add("type ");
		sb.addNewLine(Inc);

		var interGenerateor = new InterfaceGenerator();
		for (inter in TypeContext.interfaceIterator()) {
			interGenerateor.generateInterfaceObject(sb, inter);
		}

		sb.addBreak();

		for (cls in TypeContext.classIterator()) {
			for (inter in cls.classType.interfaces) {
				var cinter = TypeContext.getInterfaceByName(inter.t.get());
				interGenerateor.generateInterfaceConverter(sb, cls, cinter);
			}
		}

		sb.addBreak();
	}

	/**
	 * Build typedefs
	 */
	function buildTypedefs(sb:IndentStringBuilder) {
		var typedefs = types.typedefs;
		var anons = TypeContext.allAnonymous();
		if (typedefs.length < 1 && anons.length < 1)
			return;

		sb.add("### Typedefs");
		sb.addNewLine();
		sb.add("type ");
		sb.addNewLine(Inc);

		for (td in typedefs) {
			switch (td.typedefInfo.type) {
				case TInst(t, params):
					final sparm = TypeResolver.resolveParameters(params);
					final sto = TypeResolver.resolveClassType(t.get(), params);
					sb.add('${td.typedefInfo.name}${sparm} = ${sto}'); //{t.get().name}
					sb.addNewLine(Same);
				case TFun(_, _):
					var tpname = TypeResolver.resolve(td.typedefInfo.type);
					sb.add('${td.typedefInfo.name} = ${tpname}');
					sb.addNewLine(Same);
				case TAbstract(_, _):
					var tpname = TypeResolver.resolve(td.typedefInfo.type);
					sb.add('${td.typedefInfo.name} = ${tpname}');
					sb.addNewLine(Same);
				case TAnonymous(a):
				case v:
					throw 'Unsupported ${v}';
			}
		}

		for (an in anons) {
			if (an.iterRet != null) {
				continue;
			}
			sb.add('${an.name} = ref object of DynamicHaxeObject');
			sb.addNewLine(Inc);
			for (fld in an.fields) {
				final ftp = TypeResolver.resolve(fld.type);
				final fname = NimNames.fixFieldVarName(fld.name);
				sb.add('${fname}:${ftp}');
				sb.addNewLine(Same);
			}
			sb.addNewLine(Dec);
			sb.addNewLine(Same, true);
			sb.add('${an.name}Wrapper = ref object of DynamicHaxeWrapper');
			sb.addNewLine(Inc);
			//sb.add('instance: DynamicHaxeObjectRef');
			sb.addNewLine(Same);
			for (fld in an.fields) {
				final ftp = TypeResolver.resolve(fld.type);
				final fname = NimNames.fixFieldVarName(fld.name);
				switch TypeTools.followWithAbstracts(fld.type) {
					case TFun(args, ret):
						sb.add('${fname}: ${ftp}');
					default:
						sb.add('${fname}: ptr ${ftp}');
				}
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
		var anons = TypeContext.allAnonymous();
		if (anons.length < 1)
			return;

		for (an in anons) {
			if (an.iterRet != null) {
				continue;
			}
			var anonName = an.name;

			sb.add('converter to$anonName* [T:DynamicHaxeObjectRef | HaxeObjectRef](q: T): ${anonName}Wrapper {.inline} =');
			//sb.add('converter to$anonName* [T: ${anonName}](v: T): ${anonName}Wrapper {.inline} =');
			sb.addNewLine(Inc);
			sb.add('${anonName}Wrapper(qkind: TAnonWrapper');
			sb.addNewLine(Inc);
			sb.add(', qfields: when T is DynamicHaxeObjectRef : q.qfields else: FieldTable.default');
			sb.addNewLine(Same);
			sb.add(', qinstance: q');
			for (f in an.fields) {
				sb.addNewLine(Same);
				final fname = NimNames.fixFieldVarName(f.name);
				switch TypeTools.followWithAbstracts(f.type) {
					case TFun(args, ret):
						sb.add(', ${fname}: when T is DynamicHaxeObjectRef:');
						sb.addNewLine(Inc);
						sb.add('q.${fname}');
						sb.addNewLine(Dec);
						sb.add('else:');
						sb.addNewLine(Inc);
						final sproc = TypeResolver.resolve(f.type);
						final params = args.map(a -> NimNames.fixed(a.name)).join(", ");
						sb.add('$sproc = q.$fname($params)');
						sb.addNewLine(Dec);
					default:
						sb.add(', ${fname}: addr q.${fname}');
				}
			}
			sb.addNewLine(Dec);
			sb.add(")");

			sb.addBreak();

			sb.add('converter to$anonName* (v: Dynamic): ${anonName}Wrapper =');
			sb.addNewLine(Inc);
			sb.add('case v.kind:');
			sb.addNewLine(Same);
			sb.add('of TAnon:');
			sb.addNewLine(Inc);
			sb.add('${anonName}Wrapper(qkind: TAnonWrapper, qfields: v.dyn.fanon.qfields, qinstance: v.dyn.fanon');
			var first = true;
			for (f in an.fields) {
				if (first)
					sb.addNewLine(Inc);
				else
					sb.addNewLine(Same);
				final tn = TypeResolver.resolve(f.type);
				final fname = NimNames.fixFieldVarName(f.name);
				switch TypeTools.followWithAbstracts(f.type) {
					case TFun(args, ret):
						sb.add(', ${fname}: adr[$tn](v.dyn.fanon, "${fname}")[]');
					default:
						sb.add(', ${fname}: adr[$tn](v.dyn.fanon, "${fname}")');
				}
				first = false;
			}
			if (!first) sb.addNewLine(Dec);
			sb.add(")");
			sb.addNewLine(Dec);
			sb.add('else: raise newException(ValueError, "not an anon")');		
			sb.addBreak();

			if (an.fields.length > 0) {
				sb.add('proc makeDynamic(this:${anonName}) =');
				sb.addNewLine(Inc);
				for (fld in an.fields) {
					final fname = NimNames.fixFieldVarName(fld.name);
					sb.add('this.qfields.insert("${fname}", fromField(this.${fname}))');
					sb.addNewLine(Same);
				}
				sb.addBreak();
			}
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
	function generateClassInfo(sb:IndentStringBuilder, cls:ClassInfo, clsName: String) {
		//var params = TypeResolver.resolveParameters(cls.params);

		#if (false)
		var baseTypeName = if (TypeContext.isDynamicSupported(clsName)) {
			"DynamicHaxeObject";
		} else {
			"HaxeObject";
		}
		#else
		var baseTypeName = "HaxeObject";
		#end
		final superCls = cls.classType.superClass;
		var superName = if (superCls != null) {
			var superType = superCls.t.get();
			TypeResolver.resolveClassType(superType, superCls.params);
			//var spname = superType.name;
			//var spParams = TypeResolver.resolveParameters(cls.classType.superClass.params);
			//'${spname}${spParams}';
		} else {
			baseTypeName;
		}

		if (true || cls.fields.length > 0 || cls.methods.length > 0) {
			var line = '${clsName} = ref object of ${superName}';
			sb.add(line);
			sb.addNewLine(Same);
			generateInstanceFields(sb, cls.fields, cls.isHashable);	
		}
		function addStatic(name: String): String {
			final pos = name.indexOf("[");
			if (pos < 0)
				return name + 'Static';
			else
				return name.substr(0, pos) + 'Static' + name.substr(pos);
			
		}
		if (superName == baseTypeName) 
			superName = 'HaxeStaticObject';
		else {
			superName = addStatic(superName);
		}
		var staticFields = cls.classType.statics.get();
		//if (staticFields.length > 0) {
		if (true || (superCls == null || superCls.params.length == 0) #if (false) && cls.params.length == 0 #end ) {
			var line = '${cls.basicName}Static = ref object of ${superName}';
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
		var name = cls.className;
		var typeName = TypeResolver.resolve(abstr.type);
		var params = TypeResolver.resolveParameters(abstr.params.map(x -> x.t));

		var line = '${name}${params} = ${typeName}';
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

	function generateStaticAbstr(sb:IndentStringBuilder, cls:ClassInfo, a: Ref<AbstractType>, 
		header: Bool) 
	{
		var staticFields = cls.classType.statics.get();
		for (field in staticFields) {
			if (field.isExtern) continue;
			final name = NimNames.fixFieldVarName(field.name);
			final totalName = '${name}${cls.className}';
			switch (field.kind) {
				case FMethod(k):
					if (! header) generateClassMethod(sb, cls, field, false);
				case FVar(read, write):
					final info = methodBodyGenerator.getStaticTFieldData(cls.classType, field);
					final ft = TypeResolver.resolve(field.type);
					if (header) {
						sb.add('var ${info.totalName}: $ft');
						sb.addNewLine(Same);
					} else {
						sb.add('${info.totalName}');
						final expr = field.expr != null ? field.expr() : null;
						if (expr != null) {
							sb.add(" = ");
							methodBodyGenerator.generateExpression(sb, expr);
						}
					}
					sb.addBreak();
				case v:
					throw 'Unsupported paramter ${v}';
			}
		}
	}

	/**
	 * Build static class initialization
	 */
	function generateStaticClassInit(sb:IndentStringBuilder, cls:ClassInfo, clsName: String, header: Bool) 
	{
		if (clsName == "DefaultResolverXhaxe_Unserializer") {
			trace("here <=====================");
		}
		if (header) {
			sb.add('var ${clsName}StaticInst: ${clsName}Static');
			sb.addBreak();
			return;
		}
		var staticFields = cls.classType.statics.get();
		//if (staticFields.length < 1)
		//	return;

		var hasStaticMethod = false;
		var hasStaticVar = false;
		for (field in staticFields) {
			switch (field.kind) {
				case FMethod(k):
					hasStaticMethod = true;
					//break;
				case FVar(read, write):
					hasStaticVar = true;
					break;
				case v:
					throw 'Unsupported paramter ${v}';
			}
		}

		if (true || cls.params.length == 0) { // TODO: handle staticInst for generic classes
			sb.add('${clsName}StaticInst = ${clsName}Static(qkind: TStatic, qname: "${cls.hxFullName}"');
			if (TypeContext.isDynamicSupported() && cls.params.length == 0) {
				function genFieldInfos(fields: Array<ClassField>, extraInc: Bool, aclsName: String) {
					sb.add("@[");
					var indented = false;
					var first = true;
					for (f in fields) {
						var finfo = '(name: "${f.name}", field: ';
						final fixname = NimNames.fixFieldVarName(f.name);
						switch f.kind {
							case FVar(AccNormal, AccNormal):
								final dt = TypeResolver.asDynamicType(f.type);
								finfo += 'FieldType(kind: TField, faddress: addr cast[${aclsName}](0)[].${fixname}, fkind: $dt)';
							case FMethod(k):
								finfo = "";
							case _:
								finfo = "";
						}
						if (finfo != "") {
							if ( ! first) {
								sb.addNewLine(Same);
								sb.add(', ');
							} else {
								first = false;
								sb.addNewLine(Inc);
								if (extraInc) sb.addNewLine(Inc);
								indented = true;
							}
							sb.add('$finfo)');
						}
					}
					sb.add("]");
					if (indented) sb.addNewLine(Dec);
					else sb.addNewLine(Same);
				}
				sb.add(", qfields: ");
				genFieldInfos(cls.classType.fields.get(), true, clsName);
				sb.add(", qstaticFields: ");
				genFieldInfos(cls.classType.statics.get(), false, '${clsName}Static');
				sb.add(", qgetFields: ");
				var fields = cls.classType.fields.get().map(f -> {name: NimNames.fixFieldVarName(f.name), isVar: f.kind.match(FVar(_,_))});


				sb.addNewLine(Inc);
				sb.add('proc ():seq[string] =');
				sb.addNewLine(Inc);
				var fldNames = fields.filter(x-> x.isVar).map(x -> '"${x.name}"').join(", ");
				sb.add('return @[${fldNames}]');
				sb.addNewLine(Dec);
				sb.addNewLine(Dec);
				final pureEmptyConstr = '${clsName}(qkind: TClass, qstatic: cl)';
				sb.add(', qcempty: proc(cl: HaxeStaticObjectRef): HaxeObjectRef = ${pureEmptyConstr}');
				sb.addNewLine(Same);
				sb.add(', qcfun: proc(cl: HaxeStaticObjectRef, params: seq[Dynamic]): HaxeObjectRef = ');
				sb.addNewLine(Inc);
				if (cls.classType.constructor != null) {
					final constructor = cls.classType.constructor.get();
					final constrExp = constructor.expr();
					switch constrExp.t {
						case TFun(args, ret):
							if (args.length == 0) {
								sb.add('new$clsName()');
							} else {
								final sparams = [for (i => a in args) 'fromDynamic(params[$i], ${TypeResolver.resolve(a.t)})'].join(", ");
								sb.add('if params.len == ${args.length}: return new${clsName}($sparams)');
							}
						case var v:
							throw 'Unsupported paramter ${v}';
					}
				} else {
					sb.add('${pureEmptyConstr}');
				}
				sb.addNewLine(Dec);
			}
			final superCls = cls.classType.superClass;
			if (superCls != null) {
				final superName = TypeResolver.resolveClassType(superCls.t.get(), superCls.params);
				sb.add(', qparent: ${superName}StaticInst');
			}
			if (hasStaticVar) {
				for (f in staticFields) switch f.kind {
					case FVar(read, write):
						final fexpr = f.expr != null ? f.expr() : null;
						if (fexpr != null) {
							sb.addNewLine(Same);
							final fname = NimNames.fixFieldVarName(f.name);
							sb.add(', ${fname} : ');
							//final ovd = methodBodyGenerator.pushVoid(false);
							methodBodyGenerator.generateExpression(sb, fexpr, true);
							//methodBodyGenerator.popVoid(ovd);
						}
					case _:
				}
			}
			sb.add(")");
			sb.addBreak();
			var sparams = "";
			for (i in 0 ... cls.params.length) {
				if (i == 0) sparams = "[Dynamic";
				else sparams += ",Dynamic";
			}
			if (sparams != "") sparams += "]";
			sb.add('register(${clsName}${sparams}, ${clsName}StaticInst)');
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


	function buildPureConstructor(sb: IndentStringBuilder, constrExpr: TypedExpr) 
	{
		switch constrExpr.expr {
			case TFunction(_.expr.expr => TBlock(el)):
				var first = true;
				for (e in el) {
					switch e.expr {
						case TBinop(OpAssign, _.expr => TField(_.expr => TConst(TThis), FInstance(_, _, cf)) , e2):
							final fname = NimNames.fixFieldVarName(cf.get().name);
							if ( ! first) sb.add(",");
							sb.add('$fname: ');
							methodBodyGenerator.generateExpression(sb, e2, true);
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
		final clsName = ClassInfo.getClassName(cls);
		if (clsName == "DefaultResolverXhaxe_Unserializer") {
			trace("here <=====================");
		}
		if (cls.isPure) {
			if (cls.constrParams.length > 0) {
				final constructor = cls.classType.constructor.get();
				final constrExp = constructor.expr();
				switch constrExp.expr {
					case TFunction(tfunc):
						var sbArgs = new IndentStringBuilder();
						generateFuncArguments(sbArgs, tfunc.args);
						sb.add('template new${clsName}(');						
						sb.add(sbArgs.toString());
						sb.add(') : ${clsName} =');
						sb.addNewLine(Inc);
						sb.add('${clsName}(qkind: TClass, qstatic: ${cls.basicName}StaticInst, ');
						buildPureConstructor(sb, constrExp);
						sb.add(")");
						sb.addNewLine(Dec);
					default:
				}
			} else {
				sb.add('template new${clsName}(): ${clsName} =');
				sb.addNewLine(Inc);
				sb.add('${clsName}(qkind: TClass, qstatic: ${cls.basicName}StaticInst)');
				sb.addNewLine(Dec);
			}
			sb.addBreak();
			return;
		}
		final constructor = cls.classType.constructor.get();
		final constrExp = constructor.expr();

		var superName:String = null;
		var superConstructor:ClassField = null;

		if (cls.classType.superClass != null) {
			var superCls = cls.classType.superClass.t.get();
			superName = superCls.name;
			if (superCls.constructor != null)
				superConstructor = superCls.constructor.get();
		}
		switch [constrExp.t, constrExp.expr] {
			case [TFun(_, _), TFunction(tfunc)]:
				MethodExpressionGenerator.scopes.newScope();
				var params = TypeResolver.resolveParameters(cls.params);
				final supportsDynamic = TypeContext.isDynamicSupported();
				// Generate procedures for dynamic support
				if (supportsDynamic) {
					var fields = cls.classType.fields.get().map(f -> {name: NimNames.fixFieldVarName(f.name), isVar: f.kind.match(FVar(_,_))});
					final methods = fields.filter(f -> !f.isVar);
					#if (false)
					sb.add('proc getFields(this:${clsName}):HaxeArray[String] {.inline.} =');
					sb.addNewLine(Inc);
					var fldNames = fields.filter(x-> x.isVar).map(x -> '"${x.name}"').join(", ");
					sb.add('return HaxeArray[String](data: @[${fldNames}])');
					sb.addBreak();
					#end
					
					sb.add('proc getFieldByNameInternal${params}(this:${clsName}, name: string):Dynamic =');
					sb.addNewLine(Inc);
					if (fields.length > methods.length) {
						sb.add("case name :");
						sb.addNewLine(Same);
						for (fld in fields.filter(f -> f.isVar)) {
							sb.add('of "${fld.name}": return toDynamic(this.${fld.name})');
							sb.addNewLine(Same);
						}
					} else {
						sb.add("discard");
					}
					sb.addBreak();

					#if (false)
					sb.add('proc fromDynamic${params}(this:Dynamic):${clsName} =');
					sb.addNewLine(Inc);
					sb.add('cast[${clsName}](this.dyn.fanon)');
					sb.addBreak();
					#end
				}
				var sbCon = new IndentStringBuilder();
				var sbArgs = new IndentStringBuilder();
				var anons = generateFuncArguments(sbArgs, tfunc.args);
				if (supportsDynamic) {
					// Generate constructor
					MethodExpressionGenerator.scopes.newScope();
					sbCon.add('proc new${clsName} (');
					sbCon.add(sbArgs.toString());
					sbCon.add(') : ${clsName} {.inline.}');
					sb.add(sbCon.toString());
				} else {
					sb.add('proc new${clsName}(');
					sb.add(sbArgs.toString());
					sb.add(') : ${clsName} =');
					sb.addNewLine(Inc);
					//sb.add('${clsName}(kind: TAnon, ');
					sb.add('${clsName}(qkind: TClass, qstatic: ${cls.basicName}StaticInst, ');
					buildPureConstructor(sb, constrExp);
					sb.add(")");
					sb.addNewLine(Dec);
				}
				sb.addBreak();

				// Generate init proc for haxe "super(params)"
				MethodExpressionGenerator.scopes.newScope();
				sb.add('proc init${clsName}(this:${clsName}');
				if (tfunc.args.length > 0) {
					sb.add(", ");
					sb.add(sbArgs.toString());
				}
				sb.add('): ${clsName} {.discardable.} =');
				sb.addNewLine(Inc);

				if (cls.isHashable) {
					sb.add("this.hash = proc():int = this.hashCode()");
					sb.addNewLine(Same);
				}
				methodBodyGenerator.generateShadowAnons(sb, anons);
				methodBodyGenerator.generateShadowVars(sb, tfunc.args);
				methodBodyGenerator.generateMethodBody(sb, cls, constrExp, null);
				sb.addNewLine(Same);
				sb.add("return this");
				sb.addNewLine();
				sb.addNewLine(None, true);
				sb.addNewLine(Dec);	
				MethodExpressionGenerator.scopes.popScope();
				if (supportsDynamic) {
					// Generate constructor
					sbCon.add(" =");
					sb.add(sbCon.toString());
					sb.addNewLine(Inc);
					sb.add('var this = ${clsName}(qkind: TClass, qstatic: ${cls.basicName}StaticInst)');
					sb.addNewLine(Same);
					sb.add('init${clsName}(this');
					if (tfunc.args.length > 0) {
						sb.add(", ");
						sb.add(tfunc.args.map(x -> MethodExpressionGenerator.scopes.getVarName(x.v.name, x.v.id)).join(", "));
					}
					sb.add(')');

					#if (false)
					if (supportsDynamic) {
						sb.addNewLine(Same);
						sb.add("this.getFields = proc():HaxeArray[String] = getFields(this)");
						sb.addNewLine(Same);
						sb.add("this.getFieldByName = proc(name:String):Dynamic = getFieldByNameInternal(this, name)");
					}
					#end
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
				var sbl = new IndentStringBuilder();
				MethodExpressionGenerator.scopes.newScope();
				final mi = ClassInfo.methodInfo.get('${method.pos}');
				var clsName = ClassInfo.getClassName(cls) + (!isStatic ? '' : 'Static_');
				final smethod = mi != null ? 'method' : 'proc';
				final mparams = method.params.map(p -> p.t);
				final sparm = if (! isStatic) TypeResolver.resolveParameters(cls.params.concat(mparams)); else TypeResolver.resolveParameters(mparams);
				final mname = NimNames.fixed(method.name);
				var needForward = true;
				var isFirst = true;
				if (cls.classType.kind.match(KAbstractImpl(_))) {
					sbl.add('${smethod} ${mname}${clsName} ${sparm}(');
					needForward = false;
				} else if (isStatic)
					sbl.add('${smethod} ${clsName}${mname} ${sparm}(');
				else {
					sbl.add('${smethod} ${mname} ${sparm}(this:${clsName}');
					isFirst = false;
				}
				var anons = null;
				if (tfunc.args.length > 0) {
					if ( ! isFirst) sbl.add(", ");
					anons = generateFuncArguments(sbl, tfunc.args);
				}
				sbl.add(") : ");
				sbl.add(TypeResolver.resolve(ret));
				if (mi != null && mi == Base)
					sbl.add(" {.base.}");
				final pheader = sbl.toString();
				if (needForward)
					allMethods.push(pheader);
				sb.add(pheader);
				sb.add(" =");
				sb.addNewLine(Inc);
				if (anons != null && anons.length > 0) 
					methodBodyGenerator.generateShadowAnons(sb, anons);
				methodBodyGenerator.generateShadowVars(sb, tfunc.args);
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
				final sbl = new IndentStringBuilder();
				MethodExpressionGenerator.scopes.newScope();
				var name = abstr.name;
				var methname = NimNames.fixed(method.name);
				final params = abstr.params.concat(method.params);
				var parstr = TypeResolver.resolveParameters(params.map(x -> x.t));

				sbl.add('proc ${methname}${name}Abstr${parstr}(');
				if (tfunc.args.length > 0) {
					generateFuncArgumentsAbstract(sbl, abstr, tfunc.args, isStatic);
				}
				sbl.add(") : ");
				sbl.add(TypeResolver.resolve(ret));
				final pheader = sbl.toString();
				allMethods.push(pheader);
				sb.add(pheader);
				sb.add(" =");
				sb.addNewLine(Inc);

				methodBodyGenerator.generateShadowVars(sb, tfunc.args);
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
		trace(cls.basicName);
		for (method in cls.methods) {
			generateClassMethod(sb, cls, method, false);
		}

		switch cls.classType.kind {
			case KAbstractImpl(a):
				// we need to create the vars earlier
				#if (false)
				for (f in cls.staticFields) {
					if (f.isExtern) continue;
					final info = methodBodyGenerator.getStaticTFieldData(cls.classType, f);
					final ft = TypeResolver.resolve(f.type);
					sb.add('var ${info.totalName}: $ft');
					final expr = f.expr();
					if (expr != null) {
						sb.add(" = ");
						methodBodyGenerator.generateExpression(sb, expr, true);
					}
					sb.addBreak();
				}
				#end
			case _:
		}

		for (method in cls.staticMethods) {
			switch (cls.classType.kind) {
				case KNormal | KModuleFields(_):
					generateClassMethod(sb, cls, method, true);
				case KAbstractImpl(a):
					generateMethodAbstract(sb, cls, a.get(), method, true);
				case v:
					throw 'Unsupported ${v}';
			}
		}

		// Generate helpers
		switch cls.classType.kind {
			case KNormal | KModuleFields(_):
				#if (false)
				final clsName = ClassInfo.getClassName(cls);
				var params = TypeResolver.resolveParameters(cls.params);
				sb.add('proc `$`$params(this:${clsName}) : String {.inline.} = ');
				sb.addNewLine(Inc);
				sb.add('return "${clsName}"' + " & $this[]");
				sb.addBreak();
				#end
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

		var allMeth = [];

		for (c in classes) {
			if (c.classType.isExtern) {

			}
		}
		// Generate class methods
		function buildMethods() {
			while (ObjectType.hasUnbuild()) {
				final methBuilder = new IndentStringBuilder();
				allMeth.unshift(methBuilder);
				for (uc in ObjectType.getUnbuild()) {
					if (uc is ClassInfo) {
						final c: ClassInfo = cast uc;
						trace(c.basicName);
						if (c.used && c.classType.isExtern == false) {
							if (!c.classType.isInterface) {
								generateClassMethods(methBuilder, c);
								c.build = true;
							}
						}
					}
				}
			}
		}
		buildMethods();

		// Generate class constructors
		var constrBuilder = new IndentStringBuilder();
		function buildConstructors() {
			for (c in classes) {
				if (c.used && c.classType.isExtern == false && ! c.buildConstructor) {
					if (!c.classType.isInterface) {
						generateClassConstructor(constrBuilder, c);
						c.buildConstructor = true;
					}
				}
			}
		}
		buildConstructors();

		sb.add("### Classes and structures");
		sb.addNewLine();
		sb.add("type ");
		sb.addNewLine(Inc);
		buildMethods();

		for (c in classes) {
			if (c.used && ! c.build) 
				trace(c.basicName);
			if (c.used && c.classType.isExtern == false) {
				if (!c.classType.isInterface) {
					switch (c.classType.kind) {
						case KNormal:
							generateClassInfo(sb, c, c.className);
						case KAbstractImpl(a):
							generateAbstractImpl(sb, c, a.get());
						case KModuleFields(module):
							generateClassInfo(sb, c, module);
						case v:
							throw 'Unsupported ${v}';
					}
				}
			}
		}

		sb.addNewLine();

		// Init static classes
		function buildStatic(header: Bool) {
			for (c in classes) {
				if (c.used && c.classType.isExtern == false) {
					if (!c.classType.isInterface) {
						switch (c.classType.kind) {
							case KNormal:
								generateStaticClassInit(sb, c, c.basicName, header);
							case KAbstractImpl(a):
								generateStaticAbstr(sb, c, a, header);
							case KModuleFields(module):
								generateStaticClassInit(sb, c, module, header);
							case v:
								throw 'Unsupported ${v}';
						}
					}
				}
			}
		}
		buildConstructors();
		buildStatic(true);
		sb.add(constrBuilder.toString());
		buildStatic(false);
		for (h in allMethods) {
			sb.add(h);
			sb.addNewLine();
		}
		sb.addNewLine(true);
		for (mb in allMeth)
			sb.add(mb.toString());
		sb.addNewLine(None, true);
	}

	/**
	 * Generate entry point
	 */
	function buildEntryPointMain(sb:IndentStringBuilder, entryPoint:EntryPointInfo) {
		sb.addNewLine(None);
		var clsName = ClassInfo.getClassName(entryPoint.classInfo);
		var methodName = entryPoint.method.name;
		sb.add('${clsName}Static_${methodName}()'); // was StaticInst
	}

	public function new(processed:PreprocessedTypes) {
		super(processed);
		TypeContext.init(processed);
		methodBodyGenerator = new MethodExpressionGenerator();
	}

	/**
	 * Initialze data before start
	 * @param sb 
	 */
	function buildInit(sb:IndentStringBuilder) {
		sb.addNewLine(None);
		sb.add('proc initBeforeRun() = ');
		sb.addNewLine(Inc);
		for (fix in NimNames.allFixed()) {
			sb.add('core.fix "${fix.key}", "${fix.value}"');
			sb.addNewLine(Same);
			sb.add('core.fix ":${fix.value}", "${fix.key}"');
			sb.addNewLine(Same);
		}
		sb.addNewLine(Dec);
		sb.addNewLine(None, true);
	}

	function callInit(sb:IndentStringBuilder) {
		sb.addNewLine(None);
		sb.add('initBeforeRun()');
		sb.addNewLine(None);
		//sb.addNewLine(None, true);
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
		var enumSb = new IndentStringBuilder();

		addCodeHelpers(headerSb);
		buildEnums(headerSb);
		headerSb.addSub(enumSb);
		buildTypedefs(headerSb);
		buildAnonMakeDynamic(headerSb);
		buildInterfaces(headerSb);
		buildEnums(enumSb);
		buildInit(codeSb);
		callInit(codeSb);


		if (types.entryPoint != null) {
			codeSb.addNewLine();
			buildEntryPointMain(codeSb, types.entryPoint);
		}

		var buff = new StringBuf();

		for (m in methodBodyGenerator.requiredModules()) reqHash.set(m, true);
		buff.add(headerSb.toString());
		buff.add(codeSb.toString());

		File.saveContent(filename, buff.toString());
	}
}
