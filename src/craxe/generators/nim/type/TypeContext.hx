package craxe.generators.nim.type;

import haxe.macro.Type;
import haxe.macro.Expr;
import haxe.io.Bytes;
import haxe.crypto.Crc32;
import haxe.macro.Type.TypedExpr;
import haxe.ds.StringMap;
import craxe.common.ast.*;
import craxe.common.ast.type.*;
import craxe.common.ContextMacro;

/**
 * Context with all types
 */
class TypeContext {
	/**
	 * Information about interfaces
	 */
	static final interfaces = new StringMap<InterfaceInfo>();

	/**
	 * Information about classes
	 */
	static final classes = new StringMap<ClassInfo>();

	/**
	 * Information about enums
	 */
	static final enums = new StringMap<EnumInfo>();

	/**
	 * All anon objects like typedef anonimous by id
	 */
	static final anonById = new StringMap<AnonTypedefInfo>();

	/**
	 * All anon objects like typedef by name
	 */
	static final anonByName = new StringMap<AnonTypedefInfo>();

	static var types: PreprocessedTypes;

	/**
	 * Has interfaces
	 */
	public static var hasInterfaces(default, null):Bool;

	/**
	 * Has classes
	 */
	public static var hasClasses(default, null):Bool;

	/**
	 * Has enums
	 */
	public static var hasEnums(get, null):Bool;
		static inline function get_hasEnums() {
			return types != null ? types.enums.length > 0 : false;
		}

	/**
	 * Generate anon ID
	 */
	static function generateAnonId(fields:Array<{name:String, type:Type}>):{id: String, ? iterRet: Type}
	{
		for (f in fields) NimNames.normalize(f.name);
		fields.sort((x1, x2) -> {
			var a = x1.name;
			var b = x2.name;
			return if (a < b) -1 else if (a > b) 1 else 0;
		});
		var iterRet = null;
		if (fields.length == 2 && fields[0].name == "hasNext" && fields[1].name == "next") {
			switch fields[0].type {
				case TFun(_.length => 0, r) if (TypeResolver.isBool(r)):
					switch fields[1].type {
						case TFun(_.length => 0, ret): 
							iterRet = ret;
						default:
					}
				default: 
			}
		}
		if (iterRet == null) {
			final str = fields.map(x -> '${x.name}:${TypeResolver.resolve(x.type)}').join("");
			return {id: Std.string(Math.abs(Crc32.make(Bytes.ofString(str)))), };
		} else {
			final str = 'HaxeIterator[${TypeResolver.resolve(iterRet)}]';
			return {id: str, iterRet: iterRet};
		}
	}

	/**
	 * Constructor
	 */
	public static function init(processed:PreprocessedTypes) {
		types = processed;
		for (item in processed.classes) {
			classes.set(item.classType.name, item);
		}

		for (item in processed.interfaces) {
			interfaces.set(item.classType.name, item);
		}

		for (item in processed.enums) {
			enums.set('${item.enumType.pos}', item);
		}

		for (obj in processed.typedefs) {
			switch (obj.typedefInfo.type) {
				case TAnonymous(a):
					var an = a.get();
					var fields = an.fields.map(x -> {
						return {name: x.name, type: x.type}
					});
					final anInfo = generateAnonId(fields);
					var ano:AnonTypedefInfo = {
						id: anInfo.id,
						name: obj.typedefInfo.name,
						fields: fields,
						iterRet: anInfo.iterRet,
					}
					anonById.set(ano.id, ano);
					anonByName.set(ano.name, ano);
				case v:
					//trace(v);
			}
		}

		hasInterfaces = processed.interfaces.length > 0;
		hasClasses = processed.classes.length > 0;
	}

	/**
	 * Return iterator for all classes
	 */
	public static function classIterator():Iterator<ClassInfo> {
		return classes.iterator();
	}

	/**
	 * Return iterator for all interfaces
	 */
	public static function interfaceIterator():Iterator<InterfaceInfo> {
		return interfaces.iterator();
	}

	/**
	 * Return iterator for all interfaces
	 */
	public static function allAnonymous():Array<AnonTypedefInfo> {
		var res = new Array<AnonTypedefInfo>();
		for (item in anonById.iterator()) {
			res.push(item);
		}

		return res;
	}

	static function getByClass<T>(cls: ClassType, resType: Class<T>): T {
		final o = ObjectType.get(cls);
		if (Std.is(o, resType) ) {
			o.used = true;
			return cast o;
		}
		else return null;	
	}
	/**
	 * Return interface by name
	 */
	public static function getInterfaceByName(cls: ClassType):InterfaceInfo {
		//final o = ObjectType.get(cls);
		//if (o is InterfaceInfo) return cast o;
		//else return null;
		return cast getByClass(cls, InterfaceInfo);
		//return interfaces.get(name);
	}

	/**
	 * Return enum info by EnumType. If Info does not exists it is added
	 */
	public static function getEnumByType(et: EnumType):EnumInfo {
		final key = '${et.pos}';
		var info = enums.get(key);
		if (info == null) {
			final skip = (et.name == "ValueType" && et.module == "Type");
			if ( ! skip) for (f in et.constructs) NimNames.normalize(f.name);
			info = {enumType: et, params: et.params.map(p -> p.t), enumName: skip ? et.name : NimNames.normalize(et.name), isBuild: false};
			enums.set(key, info);
			if ( ! skip) types.enums.push(info);
		}
		return info;
	}

	/**
	 * Return class by name
	 */
	public static function getClassByName(cls: ClassType):ClassInfo {
		return getByClass(cls, ClassInfo);
		//return classes.get(name);
	}

	/**
	 * Return object by typefields
	 */
	public static function getObjectTypeByFields(fields:Array<{name:String, type:Type}>):AnonTypedefInfo {
		var id = generateAnonId(fields);
		var anon = anonById.get(id.id);
		if (anon == null) {
			anon = {
				id: id.id,
				name: id.iterRet == null ? 'Anon${id.id}' : id.id,
				fields: fields,
				iterRet: id.iterRet,
			}
			anonById.set(id.id, anon);
			anonByName.set(anon.name, anon);
		}
		return anon;
	}

	/**
	 * Return object by name
	 */
	public static function getObjectTypeByName(name: String):AnonTypedefInfo {
		//return getByClass(cls, ObjectType);
		return anonByName.get(name);
	}

	/**
	 * Check if type has dynamic support
	 */
	public static inline function isDynamicSupported():Bool {
		return ContextMacro.isDynamicSupported();
	}
}
