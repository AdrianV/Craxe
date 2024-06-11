package craxe.common.ast.type;

import haxe.macro.Type;
import haxe.macro.Type.ClassType;
import haxe.macro.Type.ClassField;
import haxe.macro.Expr.Position;
import craxe.generators.nim.NimNames;

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
		this.isPure = constructorIsPure();
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

	function constructorIsPure(): Bool {
		if (classType.constructor == null) {
			constrParams = [];
			return true;
		}
		final constructor = classType.constructor.get();
		final constrExpr = constructor.expr();
		if (constrExpr == null) { 
			constrParams = [];
			return true;
		}
		switch constrExpr.expr {
			case TFunction(tfunc):
				switch tfunc.expr.expr {
					case TBlock(el) if (tfunc.args.length == el.length):
						var par = [];
						for (x => e in el) {
							switch e.expr {
								case TBinop(OpAssign, _.expr => TField(ef, FInstance(_, _, cf)), _.expr => TLocal(v)):
									switch ef.expr {
										case TConst(TThis):
											final pname = cf.get().name;
											final fname = NimNames.fixFieldVarName(pname);
											if (tfunc.args[x].v.id != v.id)
												return false;
											par.push(fname);
										default: return false;
									}
								case _: return false;
							}
						}
						constrParams = par;
						return true;
					default:
				}
			case _:
		}
		return false;
	}

	static public inline function getClassName(c: ClassInfo) {
		return switch c.classType.kind {
			case KModuleFields(module): module;
			case _: c.className;
		}
	}


}

enum VirtualInfo {
	None;
    Base;
    Override;
}

typedef MethodInfo = Map<String, VirtualInfo>;