package craxe.common.ast.type;

import haxe.macro.Type;
import haxe.macro.Type.ClassType;
import haxe.macro.Type.ClassField;
import haxe.macro.Expr.Position;

/**
 * Info about class
 */
class ClassInfo extends ObjectType {
	/**
	 * Static fields
	 */
	public final staticFields:Array<ClassField>;

	/**
	 * Static methods
	 */
	public final staticMethods:Array<ClassField>;

	public var isPure: Bool = false;

	public var constrParams: Array<String> = null;

	public static final methodInfo: MethodInfo = new Map();

	/**
	 * Constructor
	 */
	public function new(classType:ClassType, 
					params:Array<Type>, 
					instanceFields:Array<ClassField>, 
					instanceMethods:Array<ClassField>,
					staticFields:Array<ClassField>, 
					staticMethods:Array<ClassField>,
					isHashable:Bool) {
		super(classType, params, instanceFields, instanceMethods, isHashable);
		this.staticFields = staticFields;
		this.staticMethods = staticMethods;
	}

	/**
	 * Get root class
	 * Return null if no base class
	 */
	public function getRootClassType():ClassType {
		if (classType.superClass == null)
			return null;

		var base = classType.superClass.t.get();

		while (true) {
			if (base.superClass == null)
				break;

			base = base.superClass.t.get();
		}

		return base;
	}
}

enum VirtualInfo {
	None;
    Base;
    Override;
}

typedef MethodInfo = Map<String, VirtualInfo>;