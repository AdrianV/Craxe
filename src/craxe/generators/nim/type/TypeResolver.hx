package craxe.generators.nim.type;

import craxe.common.ast.ArgumentInfo;
import craxe.common.ast.ResolvedArgumentInfo;
import haxe.macro.Type;
import haxe.macro.Type.EnumType;
import haxe.macro.Type.AbstractType;
import haxe.macro.Type.ClassType;
import haxe.macro.TypeTools;

using craxe.common.ast.MetaHelper;

/**
 * AST type resolver
 */
class TypeResolver {
	/**
	 * Simple type map
	 */
	static final simpleTypes = [
		"Bool" => "bool",
		"Int" => "int32",
		"Float" => "float",
		//"String" => "HaxeString",
		"Void" => "void"
	];

	/**
	 * Context with all types
	 */
	static final context = TypeContext;

	/**
	 * Check type is simple by type name
	 */
	static inline function isSimpleType(name:String):Bool {
		return simpleTypes.exists(name);
	}

	static public function isBool(t: Type) 
		return switch TypeTools.followWithAbstracts(t) {
			case TInst(_.get().name => "Bool", _) | TAbstract(_.get().name => "Bool", _): true;
			case _: false;
		}

	static public function isInt(t: Type) 
		return switch TypeTools.followWithAbstracts(t) {
			case TInst(_.get().name => "Int", _) | TAbstract(_.get().name => "Int", _): true;
			case _: false;
		}

	static public function isFloat(t: Type) {
		final t = TypeTools.followWithAbstracts(t);
		return switch t {
			case TInst(_.get().name => "Float", _) | TAbstract(_.get().name => "Float", _) : true;
			case _: false;
		}
	}

	static public inline function isString(t: Type) 
		return switch TypeTools.followWithAbstracts(t) {
			case TInst(_.get().name => "String", _) | TAbstract(_.get().name => "String", _) : true;
			case _: false;
		}

	static public inline function isDynamic(t: Type) 
		return switch TypeTools.followWithAbstracts(t) {
			case TDynamic(_) : true;
			case TMono(t): true;
				//final tt = t.get();
				//tt.match(TDynamic(_));
			case _: false;
		}
	static public function isInst(t: Type) {
		return switch TypeTools.followWithAbstracts(t) {
			case TInst(t, _) : 
				switch t.get().name {
					case "Bool", "Int", "Float", "String" : false;
					default : true;
				};
			case _: false;
		}
	}

	static public function isVoid(t:Type): Bool {
		//trace(TypeTools.follow(t));
		return switch TypeTools.follow(t) {
			case TAbstract(t, _), TFun(_, TAbstract(t,_)) :
				final tt = t.get();
				if (tt.module == "StdTypes") 
					switch (tt.name) {
						case "Void": true;
						case "Null": 
							isVoid(tt.params[0].t);
							//final nt: Type = tt.params[0].t
						case _: false;
					}
				else false;
			case TType(t, _):
				isVoid(t.get().type);
			case TFun(_, ret):
				isVoid(ret);
			case _: 
				false;
		}
	}

	static public function isIterator(type: Type): Bool {
		switch TypeTools.followWithAbstracts(type) {
			case TAnonymous(a):
				final object = context.getObjectTypeByFields(a.get().fields);
				return object.iterRet != null;
			default:
		}
		return false;
	}

	
	/**
	 * Generate simple type
	 */
	static function generateSimpleType(sb:StringBuf, type:String):Bool {
		var res = simpleTypes.get(type);
		if (res != null) {
			sb.add(res);
			return true;
		}

		return false;
	}

	/**
	 * Generate code for pass modificator
	 */
	static function generatePassModificator(sb:StringBuf, t:AbstractType, params:Array<Type>):Bool {
		if (t.name == "Var") {
			sb.add("var ");
			for (par in params) {
				sb.add(resolve(par));
			}
			return true;
		}
		return false;
	}

	/**
	 * Generate TEnum
	 */
	static function generateTEnum(sb:StringBuf, enumType:EnumType, params:Array<Type>) {
		final info = context.getEnumByType(enumType); //
		final sp = resolveParameters(info.params);
		sb.add(info.enumName + (sp != "" ? 'Enum${sp}' : ""));
	}

	/**
	 * Generate TAbstract
	 */
	static public function generateTAbstract(sb:StringBuf, t:AbstractType, params:Array<Type>) {
		if (generateSimpleType(sb, t.name))
			return;

		if (generatePassModificator(sb, t, params))
			return;
		var name = t.name;

		if (name == "Null" && params.length == 1) {
			final p0 = resolve(params[0]);
			switch p0 {
				case "bool" | "int32" | "float" : name = 'Null[$p0]';
				case _: name = p0;
			}
		} else {
			var parstr = resolveParameters(params);
			switch name {
				case "Async":
					name = 'Future${parstr} {.async.}';
				case "Enum" if (parstr == "[Dynamic]"):
					name = 'EnumAbstr[HaxeEnum]';// "core.TypeIndex";
				case "Class" if (parstr == "[Dynamic]"):
					name = 'ClassAbstr[HaxeObjectRef]';// "core.TypeIndex";
				case "Enum" | "Class" if (params.length == 1):
					//name = name.substr(1, name.length -2); 
					name = '${name}Abstr${parstr}';	
				default:
					name = '${name}Abstr${parstr}';	
			}
		}
		sb.add('${name}');
	}

	/**
	 * get basic type name without params
	 */
	static public function generateTypeName(sb:StringBuf, t:ClassType) {
		if (generateSimpleType(sb, t.name))
			return;

		var nativeName = t.meta.getMetaValue(":native");
		var typeName = nativeName != null ? nativeName : { 
			switch t.pack {
				case [] | ["haxe"]: getFixedTypeName(t.name);
				case _ if (t.kind.match(KTypeParameter(_))): getFixedTypeName(t.name);
				case _: getFixedTypeName(t.name) + 'X' + t.pack.join('');
			}
		};
		sb.add(typeName);
	}

	static public function appendTypeParams(sb:StringBuf, params:Array<Type>) {
		if (params != null && params.length > 0) {						
			sb.add(resolveParameters(params));
		}
	}

	/**
	 * Generate TInst
	 */
	static function generateTInst(sb:StringBuf, t:ClassType, params:Array<Type>) {
		generateTypeName(sb, t);
		appendTypeParams(sb, params);
	}

	/**
	 * Generate TType
	 */
	static function generateTType(sb:StringBuf, t:DefType, params:Array<Type>) {
		if (params.length > 0) {
			final ps = resolveParameters(params);
			sb.add(t.name + ps);
		} else sb.add(t.name);
	}

	/**
	 * Generate TFun
	 */
	static function generateTFun(sb:StringBuf, args:Array<ArgumentInfo>, ret:Type) {
		sb.add("proc(");
		inline function get(x: ArgumentInfo) {
			final tn = resolve(x.t);
			return switch x.t {
				case TAnonymous(a):	tn + 'Wrapper';
				default: tn;
			}
		}
		sb.add(args.map(x -> '${x.name != "" ? x.name : "_"}:${get(x)}').join(", "));
		sb.add("):");
		sb.add(resolve(ret));
		//sb.add(' {.closure.}');
	}

	/**
	 * Generate TAnonymous
	 */
	static function generateTAnonymous(sb:StringBuf, anon:AnonType) {		
		final object = context.getObjectTypeByFields(anon.fields);		
		sb.add(object.name);
	}

	/**
	 * Generate TDynamic
	 */
	static function generateTDynamic(sb:StringBuf, dyn:Type) {
		sb.add("Dynamic");
	}

	/**
	 * 	 Generate TMono
	 */
	static function generateTMono(sb:StringBuf, dyn:Type) {
		sb.add("Dynamic");
	}

	/**
	 * Constructor
	 */
	//public function new(context:TypeContext) {
	//	this.context = context;
	//}

	/**
	 * Return fixed type name
	 * @param name
	 */
	public static function getFixedTypeName(name:String) {
		switch name {
			case "Array":
				return "HaxeArray";
			case "Bytes":
				return "HaxeBytes";
		}
		return name;
	}


	/**
	 * Return type parameters as string
	 */
	public static function resolveParameters(params:Array<Type>):String {
		if (params.length > 0) {
			var sb = new StringBuf();

			sb.add("[");
			var parStr = params.map(x->resolve(x)).join(", ");
			sb.add(parStr);			
			sb.add("]");

			return sb.toString();
		} else {
			return "";
		}
	}

	/**
	 * Resolve arguments to resolved arguments
	 */
	public static function resolveArguments(args:Array<ArgumentInfo>):Array<ResolvedArgumentInfo> {
		return args.map(x -> {
			return {
				name: x.name,
				opt: x.opt,
				t: resolve(x.t)
			}
		});
	}

	static function resolveClassTypeImpl(classType:ClassType, params:Array<Type>) : String
	{
		var sb = new StringBuf();
		generateTInst(sb, classType, params);
		return sb.toString();
	}
	public static extern overload inline function resolveClassType(classType:ClassType, params:Array<Type>) : String
	{
		return resolveClassTypeImpl(classType, params);
	}

	public static extern overload inline function resolveClassType(classType:ClassType) : String {
		return resolveClassTypeImpl(classType, [for(t in classType.params) t.t]);
	}

	/**
	 * Resolve types to string
	 */
	public static function resolve(type:Type):String {
		var sb = new StringBuf();
		switch type {
			case TAbstract(t, _) :
				final tt = t.get();
				if (tt.name != "Null" || tt.module != "StdTypes") 
					type = TypeTools.followWithAbstracts(type);
			default:
				type = TypeTools.followWithAbstracts(type);
		}
		switch type {
			case TEnum(t, params):
				generateTEnum(sb, t.get(), params);
			case TInst(t, params):
				generateTInst(sb, t.get(), params);
			case TAbstract(t, params):
				generateTAbstract(sb, t.get(), params);
			case TType(t, params):
				generateTType(sb, t.get(), params);
			case TFun(args, ret):
				generateTFun(sb, args, ret);
			case TAnonymous(a):
				generateTAnonymous(sb, a.get());
			case TDynamic(t):
				generateTDynamic(sb, t);
			case TMono(t):
				generateTMono(sb, t.get());
			case v:			
				throw 'Unsupported type ${v}';
		}
		return sb.toString();
	}

	public static function asDynamicType(type:Type):String {
		switch type {
			case TAbstract(t, _) :
				final tt = t.get();
				if (tt.name != "Null" || tt.module != "StdTypes") 
					type = TypeTools.followWithAbstracts(type);
			default:
				type = TypeTools.followWithAbstracts(type);
		}
		switch type {
			case TEnum(t, params):
				return "TEnum";
			case TInst(t, params):
				switch resolve(type) {
					case "String" | "Null[String]" : return "TString";
					default: return "TClass";
				}
				
			//case TAbstract(t, params):
			//	var res = simpleTypes.get(type);
			//case TType(t, params):
			//	generateTType(sb, t.get(), params);
			case TFun(args, ret):
				return "TFunc";
			case TAnonymous(a):
				return "TAnonWrapper";
			case TDynamic(t):
				return "TDynamic";
			//case TMono(t):
			//	generateTMono(sb, t.get());
			case var v:	
				final res = resolve(type);
				switch res {
					case "int32" | "Null[int32]" : return "TInt";
					case "float" | "Null[float]" : return "TFloat";
					case "bool" | "Null[bool]" : return "TBool";
					case var s: 
						switch v {
						case TAbstract(_.get().name => "Null", params) :
							return asDynamicType(params[0]);
						default:
							trace(s);
							trace(resolve(v));
						}
						//return res;
				}
				throw 'Unsupported type ${v} of type ${type}';
		}
	}

}
