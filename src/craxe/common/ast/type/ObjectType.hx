package craxe.common.ast.type;

import haxe.macro.Type;
import haxe.macro.Type.ClassType;
import haxe.macro.Type.ClassField;
import craxe.generators.nim.type.TypeResolver;

/**
 * Base object info
 */
class ObjectType {
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

	public final className: String;

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
		this.className = TypeResolver.resolveClassType(classType, params);
	}
}
