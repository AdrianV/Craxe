package craxe.generators.nim.type;

import craxe.common.ast.ArgumentInfo;
import craxe.common.ast.ResolvedArgumentInfo;
import haxe.macro.Type;
import haxe.macro.Type.EnumType;
import haxe.macro.Type.AbstractType;
import haxe.macro.Type.ClassType;

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
		"String" => "HaxeString",
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

	static public inline function isInt(t: Type) 
		return switch t {
			case TInst(_.get().name => "Int", _) | TAbstract(_.get().name => "Int", _): true;
			case _: false;
		}

	static public inline function isFloat(t: Type) 
		return switch t {
			case TInst(_.get().name => "Float", _) | TAbstract(_.get().name => "Float", _): true;
			case _: false;
		}

	static public inline function isString(t: Type) 
		return switch t {
			case TInst(_.get().name => "String", _) | TAbstract(_.get().name => "String", _): true;
			case _: false;
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
		sb.add(getFixedTypeName(enumType.name));
	}

	/**
	 * Generate TAbstract
	 */
	static function generateTAbstract(sb:StringBuf, t:AbstractType, params:Array<Type>) {
		if (generateSimpleType(sb, t.name))
			return;

		if (generatePassModificator(sb, t, params))
			return;
		var name = t.name;

		if (name == "Null" && params.length == 1) {
			final p0 = resolve(params[0]);
			switch p0 {
				case "bool" | "int32" | "float" | "HaxeString" : name = 'Null[$p0]';
				case _: name = p0;
			}
		} else {
			var parstr = resolveParameters(params);
			switch name {
				case "Async":
					name = 'Future${parstr} {.async.}';
				default:
					name = '${name}Abstr${parstr}';	
			}
		}
		sb.add('${name}');
	}

	/**
	 * Generate TInst
	 */
	static function generateTInst(sb:StringBuf, t:ClassType, params:Array<Type>) {
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
		if (params != null && params.length > 0) {						
			sb.add(resolveParameters(params));
		}
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
		sb.add(args.map(x -> '${x.name}:${resolve(x.t)}').join(", "));
		sb.add("):");
		sb.add(resolve(ret));
		sb.add(' {.closure.}');
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
	 * Return fixed field name that can be a keyword in nim
	 */
	public static function getFixedFieldName(name:String) {
		switch name {
			case "iterator":
				return "fixedIterator";
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

	public static function resolveClassType(classType:ClassType, params:Array<Type>) : String
	{
		var sb = new StringBuf();
		generateTInst(sb, classType, params);
		return sb.toString();
	}

	/**
	 * Resolve types to string
	 */
	public static function resolve(type:Type):String {
		var sb = new StringBuf();
		switch (type) {
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
}
