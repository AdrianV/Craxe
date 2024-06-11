package craxe.common.ast;

import craxe.generators.nim.NimNames;
import haxe.macro.Expr;
import craxe.common.ast.EntryPointInfo;
import craxe.common.ast.type.*;
import haxe.ds.StringMap;
import haxe.macro.Type;
import craxe.common.ast.type.ClassInfo;
using StringTools;

/**
 * Build class result
 */
typedef BuildClassResult = {
	/**
	 * Class info
	 */
	var classInfo(default, null):ClassInfo;

	/**
	 * Entry point if exists
	 */
	var entryPoint:EntryPointInfo;
}

/**
 * Common preprocessor for AST tree
 */
class CommonAstPreprocessor {
	/**
	 * Name of entry point
	 */
	public static inline final MAIN_METHOD = "main";

	/**
	 * Excluded types
	 */
	static final excludedTypes:StringMap<Bool> = [
		"Std" => true, "Array" => true, "Reflect" => true, "EReg" => true, "ArrayAccess" => true, "String" => true,
		"IntIterator" => true, "StringTools" => true, "Type" => true, "_EnumValue.EnumValue_Impl_" => true, "ValueType" => true,
		"Encoding" => true, "Error" => true, "EnumValue_Impl_" => true, "File" => true, "FileInput" => true, "FileOutput" => true, "FileSeek" => true,
		"Map" => true, "Xml" => true, "IMap" => true, "Nim" => true,
		//"StringBuf" => false, 
	];

	/**
	 * Excluded modules
	 */
	static final excludedModules:Array<String> = ["haxe.CallStack", "haxe.Constraints", "haxe.Int32-", "haxe.Int64", "haxe.Log", 
		"haxe.MainLoop", "MainLoop", "haxe.EntryPoint", "EntryPoint",
		"haxe.io.Bytes",
		"haxe.NativeStackTrace", "haxe.StackItem", "haxe.SysTools", "Any", "Array", "StdTypes", "haxe.ds.Map", "haxe.exceptions."];

	static inline function hasOwnName(c: ClassType, f: ClassField) {
		return c.isExtern || f.isExtern || f.meta.has(":native");
	}

	/**
	 * Filter not needed type. Return true if filtered
	 */
	function filterTypeByName(name:String, module:String):Bool {
		//trace('$name from $module');
		for (excl in excludedModules) {
			if (module.startsWith(excl)) {
				//trace('excluded $excl');
				return true;
			}
		}

		if (excludedTypes.get(name))
			return true;
		//trace('     accepted  ----------------------');
		return false;
	}

	/**
	 * Filter type
	 */
	function filterType(t:Type):Bool {
		switch (t) {
			case TEnum(t, _):
				var en = t.get();
				return filterTypeByName(en.name, en.module);
			case TInst(t, _):
				var ins = t.get();
				return filterTypeByName(ins.name, ins.module);
			case TAbstract(_, _):
				return true;
			case TType(t, _):
				var tp = t.get();
				return filterTypeByName(tp.name, tp.module);
			case _:
		}
		return false;
	}

	/**
	 * Get fields and methods of instance
	 */
	function getFieldsAndMethods(c:ClassType, ? methodInfo: MethodInfo):{
		fields:Array<ClassField>,
		methods:Array<ClassField>,
		isHashable:Bool
	} {
		var classFields = c.fields.get();

		final fields = [];
		final methods = [];
		var isHashable = false;
		var hasOverrides = false;
		var overMap = new Array<String>();
		if (methodInfo != null) for (o in c.overrides) {
			hasOverrides = true;
			final om = o.get();
			methodInfo.set('${om.pos}', Override);
			overMap.push(om.name);
		}
		if (hasOverrides) {
			var sup = c.superClass;
			while (sup != null && overMap.length > 0) {
				final supi = sup.t.get();
				for (f in supi.fields.get()) if (f.kind.match(FMethod(MethNormal))) {
					final idx = overMap.indexOf(f.name);
					if (idx >= 0) {
						final s = '${f.pos}';
						if (! methodInfo.exists(s)) {
							methodInfo.set(s, Base);
						}
						overMap.splice(idx, 1);
					}
				}
				sup = supi.superClass;
			}
		}
		for (ifield in classFields) {
			var used = false;
			switch (ifield.kind) {
				case FVar(_, _):
					fields.push(ifield);
					used = true;					
				case FMethod(m):
					switch (m) {
						case MethNormal | MethInline:
							if (ifield.name == "hashCode") {
								isHashable = true;
							}
							methods.push(ifield);
							used = true;
						case MethMacro:
						case v:
							throw 'Unsupported ${v}';
					}
			}
			if (used) 
				if (! hasOwnName(c, ifield)) 
					NimNames.normalize(ifield.name);
				else
					NimNames.fixOnly(ifield.name);
		}
		return {
			fields: fields,
			methods: methods,
			isHashable: isHashable
		}
	}

	/**
	 * Get fields and methods of instance
	 */
	function getStaticFieldsAndMethods(c:ClassType):{
		fields:Array<ClassField>,
		methods:Array<ClassField>,
		entryMethod:ClassField
	} {
		var classFields = c.statics.get();

		var fields = [];
		var methods = [];
		var entryMethod:ClassField = null;

		for (ifield in classFields) {
			var used = false;
			switch (ifield.kind) {
				case FVar(_, _):
					fields.push(ifield);
					used = true;
				case FMethod(m):
					switch (m) {
						case MethNormal | MethInline:
							methods.push(ifield);
							used = true;
							if (ifield.name == MAIN_METHOD) {
								entryMethod = ifield;
							}
						case MethDynamic:
							methods.push(ifield);
							used = true;
						case MethMacro:
						
						case v:
							throw 'Unsupported ${v}';
					}
			}
			if (used && ! hasOwnName(c, ifield))
				NimNames.normalize(ifield.name);

		}

		return {
			fields: fields,
			methods: methods,
			entryMethod: entryMethod
		}
	}

	/**
	 * Build interface info
	 */
	function buildInterface(c:ClassType, params:Array<Type>):InterfaceInfo {
		var res = getFieldsAndMethods(c);
		return new InterfaceInfo(c, params, res.fields, res.methods);
	}

	/**
	 * Check if classtype is struct
	 */
	function isStruct(c:ClassType):Bool {
		if (c.superClass == null)
			return false;

		var sup = c.superClass.t.get();
		// TODO: check inheritance and throw exception
		while (sup != null) {
			if (sup.name == "Struct")
				return true;

			if (sup.superClass == null)
				return false;

			sup = sup.superClass.t.get();
		}

		return false;
	}

	/**
	 * Build structure info
	 */
	function buildStruct(c:ClassType, params:Array<Type>):StructInfo {
		var res = getFieldsAndMethods(c);
		return new StructInfo(c, params, res.fields, res.methods);
	}

	/**
	 * Build class info
	 */
	function buildClass(c:ClassType, params:Array<Type>):BuildClassResult {
		var instanceRes = getFieldsAndMethods(c, ClassInfo.methodInfo);
		var staticRes = getStaticFieldsAndMethods(c);

		var classInfo = new ClassInfo(c, 
							params, 
							instanceRes.fields, 
							instanceRes.methods, 
							staticRes.fields, 
							staticRes.methods,
							instanceRes.isHashable);

		var entryPoint:EntryPointInfo = if (staticRes.entryMethod != null) {
			classInfo.used = true;
			{
				classInfo: classInfo,
				method: staticRes.entryMethod
			}
		} else null;

		return {
			classInfo: classInfo,
			entryPoint: entryPoint
		}
	}

	/**
	 * Build enum info
	 */
	function buildEnum(c:EnumType, params:Array<Type>):EnumInfo {
		for (f in c.constructs) {
			NimNames.normalize(f.name);
		}
		return {
			enumType: c,
			params: params,
			enumName: NimNames.normalize(c.name),
			isBuild: false,
		}
	}

	/**
	 * Build typedef info
	 */
	function buildTypedef(def:DefType, params:Array<Type>):TypedefInfo {
		if (!def.isExtern) NimNames.normalize(def.name);
		switch def.type {
			case TAnonymous(a):
				final an = a.get();
				for (f in an.fields)
					if (! f.isExtern && ! f.meta.has(":native")) NimNames.normalize(f.name);
			default:
		}
		return new TypedefInfo(def, params);
	}

	/**
	 * Constructor
	 */
	public function new() {}

	/**
	 * Process class, interface, struct and return ObjectType info
	 */
	function processTInst(c:ClassType, params:Array<Type>):{
		?objectInfo:ObjectType,
		?entryPoint:EntryPointInfo
	} {
		if (c.isInterface) {
			return {
				objectInfo: buildInterface(c, params)
			}
		} else {
			if (isStruct(c)) {
				return {
					objectInfo: buildStruct(c, params)
				}
			}

			var res = buildClass(c, params);
			if (res != null)
				return {
					objectInfo: res.classInfo,
					entryPoint: res.entryPoint
				}
		}

		return null;
	}

	/**
	 * Process AST and get types
	 */
	public function process(types:Array<Type>):PreprocessedTypes {
		var classes = new Array<ClassInfo>();
		var structures = new Array<StructInfo>();
		var typedefs = new Array<TypedefInfo>();
		var interfaces = new Array<InterfaceInfo>();
		var enums = new Array<EnumInfo>();
		var entryPoint:EntryPointInfo = null;

		for (t in types) {
			if (filterType(t))
				continue;

			switch (t) {
				case TInst(c, params):
					var res = processTInst(c.get(), params);
					if (res != null) {
						if ((res.objectInfo is ClassInfo)) {
							classes.push(cast(res.objectInfo, ClassInfo));
							if (res.entryPoint != null)
								entryPoint = res.entryPoint;
						} else if ((res.objectInfo is InterfaceInfo)) {
							interfaces.push(cast(res.objectInfo, InterfaceInfo));
						} else if ((res.objectInfo is StructInfo)) {
							structures.push(cast(res.objectInfo, StructInfo));
						}
					}
				case TEnum(t, params):
					var enu = buildEnum(t.get(), params);
					if (enu != null)
						enums.push(enu);
				case TType(t, params):
					var td = buildTypedef(t.get(), params);
					if (td != null)
						typedefs.push(td);
				case var v:
					trace('$v');
			}
		}

		var types:PreprocessedTypes = {
			interfaces: interfaces,
			classes: classes,
			typedefs: typedefs,
			structures: structures,
			enums: enums,
			entryPoint: entryPoint
		}

		return types;
	}
}
