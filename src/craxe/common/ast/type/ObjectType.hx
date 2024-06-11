package craxe.common.ast.type;

import haxe.macro.Type;
import haxe.macro.Type.ClassType;
import haxe.macro.Type.ClassField;
import craxe.generators.nim.type.TypeResolver;

/**
 * Base object info
 */
class ObjectType {

	public static var allTypes = new Map<String, ObjectType>();

	static var allUsed = new Array<ObjectType>();

	/**
	 * Real AST type
	 */
	public final classType:ClassType;

	/**
	 * Params of class type
	 */
	public final params:Array<Type>;

	/**
	 * Fields of instance
	 */
	public final fields:Array<ClassField>;

	/**
	 * Methods of instance
	 */
	public final methods:Array<ClassField>;

	/**
	 * Object has hashCode method
	 */
	public final isHashable:Bool;

	public final basicName: String;

	public final className: String;

	public final hxFullName: String;

	public var used(default, set) = false;

		function set_used(v) {
			if (v && ! used) {
				allUsed.push(this);
			}	
			used = v;
			return v;
		}
	
	public var build = false;
	public var buildConstructor = false;
	public var usedFromDynamic = false;
	public var usedWrapped = false;

	/**
	 * Constructor
	 */
	public function new(classType:ClassType, 
			params:Array<Type>, 
			fields:Array<ClassField>, 
			methods:Array<ClassField>,
			isHashable = false) {
		this.classType = classType;
		this.params = params;
		this.fields = fields;
		this.methods = methods;
		this.isHashable = isHashable;
		var sb = new StringBuf();
		TypeResolver.generateTypeName(sb, classType);
		this.basicName = sb.toString();
		TypeResolver.appendTypeParams(sb, params);
		this.className = sb.toString();
		this.hxFullName = fullHaxeName(classType);
		allTypes.set('${classType.pos}', this);
	}

	public static function fullHaxeName(cls: BaseType) {
		final modul = cls.module;
		if (cls.pack.length == 0) 
			return cls.name;
		else {
			final p = modul.lastIndexOf(".");
			return (modul.substr(p + 1) == cls.name ? modul : '${modul.substr(0, p)}.${cls.name}');
		}
	}

	public static function isUsed(cls: ClassType) {
		final o = allTypes.get('${cls.pos}');
		return o != null && o.used;
	}

	public static function use(cls: ClassType) {
		final o = allTypes.get('${cls.pos}');
		if (o != null && ! o.used) {
			o.used = true;
			//allUsed.push(o);
			if (cls.superClass != null) 
				use(cls.superClass.t.get());
		}
	}

	public static inline function get(cls: ClassType) {
		return allTypes.get('${cls.pos}');
	}

	public static function hasUnbuild(): Bool {
		return allUsed.length > 0;
	}

	public static function getUnbuild(): Array<ObjectType> {
		final res = allUsed.copy();
		allUsed.resize(0);
		return res;
	}

	public static function calledFromDynamic(cls: ClassType) {
		final o = get(cls);
		if (o != null) o.usedFromDynamic = true;
	}
}
