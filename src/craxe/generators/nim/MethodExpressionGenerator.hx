package craxe.generators.nim;

import haxe.macro.Context;
import craxe.common.ast.type.*;
import haxe.macro.Type;
import haxe.macro.Type.EnumField;
import haxe.macro.Expr.MetadataEntry;
import haxe.macro.Expr.Unop;
import haxe.macro.Expr.Binop;
import haxe.macro.Type.TConstant;
import haxe.macro.Type.TVar;
import haxe.macro.Type.ModuleType;
import haxe.macro.Type.FieldAccess;
import haxe.macro.Type.ClassType;
import haxe.macro.Type.TypedExpr;
import haxe.macro.Type.TypedExprDef;
import haxe.macro.TypeTools;
import craxe.common.IndentStringBuilder;
import craxe.generators.nim.type.*;
import craxe.common.ContextMacro;
import craxe.common.tools.BinSearch;

using craxe.common.ast.MetaHelper;
using craxe.generators.nim.type.TypeResolver;

using StringTools;

enum TypeMix {
	None;
	FloatInt;
	IntFloat;
	FirstUInt;
	FirstString;
	SecondString;
	StringString;
	DynamicAndTInst;
	TInstAndDynamic;
}

typedef VarInfo = {
	name: String,
	id: Int,
	count: Int,
}

private class NameGetter {
  public inline function new() {}
  public inline function key(item: VarInfo): String return item.name;
}

abstract VarInScope(Array<Array<VarInfo>>) {

	static var finder = new BinSearch<VarInfo,String,NameGetter,StringComparer>(new NameGetter(), new StringComparer());
	static var nameOfId = new Map<Int, String>();
	static var isParam = new Map<Int, Bool>();

	public inline function new() this = [[]];
		
	public inline function popScope() this.pop();
		
	public function newScope() {
		this.push([]);
	}


	public function createVar(vr: TVar, _isParam: Bool): String {
		var useName = NimNames.fixLocalVarName(vr.name);
		final last = this[this.length - 1];
		var pos = finder.search(last, useName);
		if (pos.found()) {
			final idx = pos.idx();
			var i = last[idx].count + 1;
			while (true) {
				final n = useName + Std.string(i);
				pos = finder.search(last, n);
				if ( ! pos.found()) {
					useName = n;
					break;
				}
				i++;
			}
			last[idx].count = i;
		} else
			last.insert(pos.idx(), {name: useName, id: vr.id, count: 1});
		nameOfId.set(vr.id, useName);
		if (_isParam)  isParam.set(vr.id, true);
		return useName;
	}

	public function getVarName(name: String, id: Int): String {
		final n = nameOfId.get(id);
		return if (n != null) n else NimNames.fixLocalVarName(name);
	}

	public inline function isParamVar(vr: TVar) return isParam.exists(vr.id);

	public inline function shadowParamVar(vr: TVar) isParam.remove(vr.id);
		
}

/**
 * Generate code for expression
 */
class MethodExpressionGenerator {
	/**
	 * Minimal string size for checking
	 */
	static inline final MIN_STRING_CHECK_SIZE = 100;


	/**
	 * Class context
	 */
	var classContext:ClassInfo;

	/**
	 * Method return type
	 */
	var returnType:Type;
	var needVoid: Bool = true;

	public static final scopes = new VarInScope();
	var reqHash = new Map<String, Bool>();

	public function requiredModules(): Array<String> {
		final res = [for (m => r in reqHash) if (r) m];
		return res;
	}

	inline function checkRequired(meta: MetaAccess) {
		final req = meta.getMetaValue(":require");
		if (req != null) {
			reqHash.set(req, true);
		}
	}

	inline function pushVoid(v: Bool): Bool {
		final res = needVoid;
		needVoid = v;
		return res;
	}

	inline function popVoid(v: Bool) {
		needVoid = v;
	}

	/**
	 * Generate code for TMeta
	 */
	function generateTMeta(sb:IndentStringBuilder, meta:MetadataEntry, expression:TypedExpr) {
		switch (expression.expr) {
			case TConst(c):
				generateTConst(sb, c, expression.t);
			case TLocal(v):
				generateTLocal(sb, v);
			case TSwitch(e, cases, edef):
				generateTSwitch(sb, e, cases, edef);
			case TEnumIndex(e1):
				generateTEnumIndex(sb, e1);
			case TCall(e, el):
				generateCommonTCall(sb, e, el);
			case TIf(econd, eif, eelse):
				generateTIf(sb, econd, eif, eelse);
			case TBlock(el):
				generateTBlockReturnValue(sb, el);
			case TObjectDecl(fields):
				generateTObjectDecl(sb, fields);
			case v:
				throw 'Unsupported ${v}';
		}
	}

	/**
	 * Generate code for TThrow
	 */
	function generateTThrow(sb:IndentStringBuilder, e:TypedExpr) {
		// TODO: normal error throw
		sb.add('newException(Exception, "Error")');
	}

	/**
	 * Generate code for TMeta
	 */
	function generateTEnumIndex(sb:IndentStringBuilder, expression:TypedExpr) {
		switch (expression.expr) {
			case TLocal(v):
				generateTLocal(sb, v);
			case TCast(e, m):
				generateTCast(sb, expression, e, m);
			case v:
				throw 'Unsupported ${v}';
		}
		sb.add(".index");
	}

	/**
	 * Generate custom code for getting enum values
	 * cast[EnumType](enum).value
	 * TODO: minimize casts
	 * Return true if it was processed
	 */
	function generateCustomEnumParameterCall(sb:IndentStringBuilder, e1:TypedExpr, ef:EnumField, index:Int):Bool {
		switch (e1.expr) {
			case TLocal(v) | TCast({t:_,pos:_,expr:TLocal(v)},_):
				switch (v.t) {
					case TEnum(t, _) | TAbstract(_.get().type => TEnum(t, _), _):
						final ent = t.get();
						final enumName = ent.name;
						final instName = ent.names[ef.index];
						sb.add('cast[${enumName}${instName}](');
						sb.add(scopes.getVarName(v.name, v.id));
						sb.add(')');
						switch (ef.type) {
							case TFun(args, _):
								sb.add('.${args[0].name}');
							case v:
								var resolved = TypeResolver.resolve(v);
								sb.add(resolved);
						}
						return true;
					default:
				}
//			case TCast(e, m):
//				switch e.expr {
//					case TLocal(v):
//				}
			default:
		}
		return false;
	}

	/**
	 * Generate code for TEnumParameter
	 */
	function generateTEnumParameter(sb:IndentStringBuilder, expression:TypedExpr, enumField:EnumField, index:Int) {
		switch (expression.expr) {
			case TLocal(v):
				generateTLocal(sb, v);
			case TCast(e, m):
				generateTCast(sb, expression, e, m);
			case v:
				throw 'Unsupported ${v}';
		}
	}

	/**
	 * Generate code for TSwitch
	 */
	function generateTSwitch(sb:IndentStringBuilder, expression:TypedExpr, cases:Array<{values:Array<TypedExpr>, expr:TypedExpr}>, edef:TypedExpr) {
		function generateCommonTSwitchExpression(sexpression:TypedExpr) {
			switch (sexpression.expr) {
				case TConst(c):
					generateTConst(sb, c, sexpression.t);
				case TCall(e, el):
					generateBlockTCall(sb, e, el);
				case TReturn(e):
					generateTReturn(sb, e);
				case TBlock(el):
					generateTBlock(sb, el, true);
				case TMeta(m, e1):
					generateTMeta(sb, m, e1);
				case TNew(c, params, el):
					generateTNew(sb, c.get(), params, el);
				case TThrow(e):
					generateTThrow(sb, e);					
				case v:
					throw 'Unsupported ${v}';
			}
		}

		sb.add("case ");
		switch (expression.expr) {
			case TParenthesis(e):
				switch (e.expr) {
					case TLocal(v):
						generateTLocal(sb, v);
					case TMeta(m, e1):
						generateTMeta(sb, m, e1);
					case v:
						throw 'Unsupported ${v}';
				}
			case v:
				throw 'Unsupported ${v}';
		}

		for (cs in cases) {
			for (val in cs.values) {
				sb.addNewLine(Same);
				sb.add("of ");

				switch (val.expr) {
					case TConst(c):
						generateTConst(sb, c, val.t);
					case v:
						throw 'Unsupported ${v}';
				}

				sb.add(":");
				sb.addNewLine(Inc);

				generateCommonTSwitchExpression(cs.expr);

				sb.addNewLine(Dec);
			}
		}

		sb.add('else:');
		sb.addNewLine(Inc);
		if (edef == null) {
			sb.add('raise newException(Exception, "Invalid case")');
		} else {
			generateCommonTSwitchExpression(edef);
		}

		sb.addNewLine(Dec);
	}

	/**
	 * Return proper type name and it's field
	 */
	public function getStaticTFieldData(classType:ClassType, classField:ClassField):{
		className:String,
		fieldName:String,
		totalName:String
	} {
		var className = "";

		var fieldName = NimNames.fixStaticFieldVarName(classField.name);
		var totalName = "";
		final Static = switch classField.kind {
			case FVar(read, write): 'StaticInst';
			case FMethod(k): 'Static';
		}
		//isCall ? 'Static' : 'StaticInst';
		if (classType.isExtern) {
			var isTop = classField.meta.has(":topFunction");
			className = classType.meta.getMetaValue(":native");
			checkRequired(classType.meta);
			// Check it's top function
			if (className == null) {
				// TODO: make it better. Maybe getSystemFieldTotalName(classType, classField) ?
				if (classType.module.indexOf("sys.io.") > -1) {
					className = '${classType.name}$Static';
				} else {
					className = classType.name;
				}
			}

			if (isTop) {
				var topName = classField.meta.getMetaValue(":native");
				if (topName != null)
					fieldName = topName;
			}

			totalName = if (isTop) {
				fieldName;
			} else {
				'${className}.${fieldName}';
			}
		} else {
			var name = TypeResolver.resolveClassType(classType, [for (p in classType.params) p.t]);

			switch classType.kind {
				case KNormal:
					className = '${name}$Static';
					totalName = '${className}.${fieldName}';
				case KAbstractImpl(a):
					var abstr = a.get();
					className = '${abstr.name}Abstr';
					fieldName = fieldName.replace("_", "");
					totalName = '${fieldName}${className}';
				case KModuleFields(module):
					className = '${module}$Static';
					totalName = '${className}.${fieldName}';
				case v:
					throw 'Unsupported ${v}';
			}
		}

		if (totalName == "Std.string")
			totalName = "$";

		return {
			className: className,
			fieldName: fieldName,
			totalName: totalName
		}
	}

	function isNullT(type: Type): Bool {
		switch type {
			case null: return false;
			case TType(t, params):
				final tt = t.get();
				return isNullT(tt.type);
			case TAbstract(t, params):
				final tt = t.get();
				if (tt.name == "Null") return true;
				return isNullT(tt.type);
			case _: return false;
		}
	}

	/**
	 * Get instance field data
	 */
	function getInstanceTFieldData(classType:ClassType, params:Array<Type>, classField:ClassField):{
		className:String,
		fieldName:String,
		totalName:String
	} {
		var className = TypeResolver.resolveClassType(classType, params);
		var fieldName:String = classField.meta.getMetaValue(":native"); // TODO: shouldn't native names also get fixed ?
		if (fieldName == null) {
			//if (follow && isNullT(classField.type)) {
			//	fieldName = NimNames.fixFieldVarName(TypeResolver.getFixedTypeName(classField.name)) + ".value";
			//} else
				fieldName = NimNames.fixFieldVarName(classField.name);
		}

		if (classType.isInterface) {
			switch (classField.kind) {
				case FVar(_, _):
					fieldName = '${fieldName}[]';
				case FMethod(_):
			}
		}

		return {
			className: className,
			fieldName: fieldName,
			totalName: '${className}.${fieldName}'
		}
	}

	/**
	 * Generate code for TConstant
	 */
	public function generateTConst(sb:IndentStringBuilder, con:TConstant, t:Type) {
		switch (con) {
			case TInt(i):
				sb.add(Std.string(i));
			case TFloat(s):
				sb.add(Std.string(s));
			case TString(s):
				if (s.length < MIN_STRING_CHECK_SIZE && s.indexOf("\n") < 0) {
					sb.add('"${Std.string(s)}"');
				} else {
					sb.add('"""${Std.string(s)}"""');
				}
			case TBool(b):
				sb.add(Std.string(b));
			case TNull:
				//final tn = TypeResolver.resolve(t);
				// sb.add('$tn.default');
				sb.add('nil');
			case TThis:
				sb.add("this");
			case TSuper:
				throw "Unsupported super";
		}
	}

	/**
	 * Generate code for TVar
	 */
	function generateTVar(sb:IndentStringBuilder, vr:TVar, expr:TypedExpr) {
		sb.add("var ");
		//var name = TypeResolver.getFixedTypeName(vr.name);
		final name = scopes.createVar(vr, false);
		sb.add(name);
		var vartype = '${TypeResolver.resolve(vr.t)}';
		switch vartype {
			case "int32", "float", "Dynamic": sb.add(': $vartype');
			case _ :
				if (expr == null) sb.add(': $vartype');
				else {
					switch expr.expr {
						case TConst(TNull): sb.add(': $vartype');
						case _:
					}
				}
		}
		

		if (expr != null) {
			sb.add(" = ");
			final ovd = pushVoid(false);
			var isConvertFromDynamic = false;
			// Convert from Dynamic to real type
			switch expr.t {
				case TDynamic(_):
					switch vr.t {
						case TMono(_):
						case TDynamic(_):
						// Ignore
						case _:
							isConvertFromDynamic = true;
							sb.add("fromDynamic(");
					}
				case _:
			}

			generateTBlockSingleExpression(sb, expr, false);
			if (isConvertFromDynamic) {
				sb.add(', ${vartype})');
			}
			popVoid(ovd);
		}
		sb.addNewLine(Same);
	}

	/**
	 * Generate code for TNew
	 */
	function generateTNew(sb:IndentStringBuilder, classType:ClassType, params:Array<Type>, elements:Array<TypedExpr>) {
		var typeName = TypeResolver.resolveClassType(classType, params);
		checkRequired(classType.meta);
		//var typeParams = TypeResolver.resolveParameters(params);
		var isPure = false;
		var clsInfo: ClassInfo = null;
		var varTypeName = if ((classType.isExtern && classType.superClass != null && classType.superClass.t.get().name == "Distinct")
							|| (typeName.startsWith('HaxeArray['))) 
		{
			typeName;
		} else {
			clsInfo = TypeContext.getClassByName(typeName);
			if (clsInfo != null && clsInfo.isPure && clsInfo.constrParams.length == elements.length) {
				isPure = true;
				typeName;
			} else 
				'new${typeName}';
		}

		sb.add(varTypeName);
		sb.add("(");
		//if (isPure) sb.add('kind: TAnon');
		var isFirst = ! isPure;
		for (i in 0 ... elements.length) {
			if (! isFirst) sb.add(', ');
			isFirst = false;
			if (isPure) sb.add(clsInfo.constrParams[i] + ': ');
			final expr = elements[i];
			generateTBlockSingleExpression(sb, expr, false);
			#if (false)
			switch (expr.expr) {
				case TConst(c):
					generateTConst(sb, c, expr.t);
				case TLocal(v):
					generateTLocal(sb, v);
				case TBinop(op, e1, e2):
					generateTBinop(sb, op, e1, e2);
				case TNew(c, params, el):
					generateTNew(sb, c.get(), params, el);
				case TField(e, fa):
					generateTField(sb, e, fa);
				case TCast(e, m):
					generateTCast(sb, expr, e, m);
				case TCall(e, el):
					generateCommonTCall(sb, e, el);
				case TArrayDecl(el):
					generateTArrayDecl(sb, el, expr);
				case TObjectDecl(fields):
					generateTObjectDecl(sb, fields);
				case v:
					throw 'Unsupported ${v}';
			}
			#end
		}
		sb.add(")");
	}

	/**
	 * Generate code for TLocal
	 */
	function generateTLocal(sb:IndentStringBuilder, vr:TVar) {
		var name = scopes.getVarName(vr.name, vr.id);
		if (name == null) {
			trace('name of ${vr} not found');
		}
		sb.add(name);
	}

	/**
	 * Generate code for access Bytes data
	 * Fixes inline access to seq[byte]	of HaxeBytes
	 */
	function generateCustomBytesAccess(sb:IndentStringBuilder, expression:TypedExprDef) {
		switch expression {
			case TField(e, _):
				switch (e.t) {
					case TInst(t, _):
						if (t.get().name == "Bytes") {
							switch (e.expr) {
								case TField(e, fa):
									generateTField(sb, e, fa);
								case TLocal(v):
									generateTLocal(sb, v);
								case TConst(c):
									generateTConst(sb, c, e.t);
								case v:
									throw 'Unsupported ${v} at ${e.pos}';
							}
							return true;
						}
					default:
				}
			default:
		}

		return false;
	}

	/**
	 * Generate code for TArray
	 * Array access arr[it]
	 */
	function generateTArray(sb:IndentStringBuilder, e1:TypedExpr, e2:TypedExpr) {
		if (!generateCustomBytesAccess(sb, e1.expr)) {
			switch (e1.expr) {
				case TLocal(v):
					generateTLocal(sb, v);
				case TField(e, fa):
					generateTField(sb, e, fa);
				case TCast(e, m):
					generateTCast(sb, e1, e, m);
				case v:
					throw 'Unsupported ${v}';
			}
		}

		sb.add("[");
		generateTBlockSingleExpression(sb, e2, false);
		#if (false)
		switch (e2.expr) {
			case TConst(c):
				generateTConst(sb, c);
			case TField(e, fa):
				generateTField(sb, e, fa);
			case TLocal(v):
				generateTLocal(sb, v);
			case TBinop(op, e1, e2):
				generateTBinop(sb, op, e1, e2);
			case TArray(e1, e2):
				generateTArray(sb, e1, e2);
			case TCall(e, el):
				generateCommonTCall(sb, e, el);
			case v:
				throw 'Unsupported ${v}';
		}
		#end
		sb.add("]");
	}

	/**
	 * Generate code for TArrayDecl
	 * An array declaration `[el]`
	 */
	function generateTArrayDecl(sb:IndentStringBuilder, elements:Array<TypedExpr>, expr: TypedExpr) {
		final pt = switch expr.t {
			case TInst(t, params) if (params.length == 1): TypeResolver.resolve(params[0]);
			case v: throw 'Unsupported ${v}';
		}
		sb.add('HaxeArray[$pt](data: @[');
		for (i in 0...elements.length) {
			var expr = elements[i];

			switch (expr.expr) {
				case TConst(c):
					generateTConst(sb, c, expr.t);
				case TNew(c, params, el):
					generateTNew(sb, c.get(), params, el);
				case TCall(e, el):
					generateCommonTCall(sb, e, el);
				case TField(e, fa):
					generateTField(sb, e, fa);
				case TLocal(v):
					generateTLocal(sb, v);
				case v:
					throw 'Unsupported ${v}';
			}
			if (i == 0) sb.add('.$pt');
			if (i + 1 < elements.length)
				sb.add(", ");
		}
		sb.add("])");
	}

	/**
	 * Generate code for TObjectDecl for trace
	 */
	function generateTObjectDeclTrace(sb:IndentStringBuilder, fields:Array<{name:String, expr:TypedExpr}>) {
		for (i in 0...fields.length) {
			var field = fields[i];
			switch field.expr.expr {
				case TConst(c):
					generateTConst(sb, c, field.expr.t);
				case v:
					throw 'Unsupported ${v}';
			}
			if (i + 1 < fields.length)
				sb.add(", ");
		}
	}

	/**
	 * Generate code for TObjectDecl
	 */
	function generateTObjectDecl(sb:IndentStringBuilder, fields:Array<{name:String, expr:TypedExpr}>, type:Type = null) {
		var object = if (type != null) {
			switch (type) {
				case TType(t, _):
					TypeContext.getObjectTypeByName(t.get().name);
				case TAnonymous(a):
					var flds = a.get().fields.map(x -> {
						return {
							name: x.name,
							type: x.type
						};
					});
					TypeContext.getObjectTypeByFields(flds);
				case v:
					throw 'Unsupported ${v}';
			}
		} else {
			TypeContext.getObjectTypeByFields(fields.map(x -> {
				name: x.name,
				type: x.expr.t
			}));
		}

		sb.add('${object.name}(kind: TAnon');
		for (field in fields) {
			final fname = NimNames.fixFieldVarName(field.name);
			sb.add(', ${fname}: ');
			switch field.expr.expr {
				case TConst(c):
					generateTConst(sb, c, field.expr.t);
				case TLocal(v):
					generateTLocal(sb, v);
				case TBinop(op, e1, e2):
					generateTBinop(sb, op, e1, e2);
				case TFunction(tfunc):
					generateTFunction(sb, tfunc);
				case TIf(econd, eif, eelse):
					generateTIf(sb, econd, eif, eelse);
				case TCall(e, el):
					generateCommonTCall(sb, e, el);
				case TUnop(op, postFix, e):
					generateTUnop(sb, op, postFix, e);
				case v:
					throw 'Unsupported ${v}';
			}
		}
		sb.add(')');
	}

	/**
	 * Genertate TCast
	 */
	function generateTCast(sb:IndentStringBuilder, toExpr:TypedExpr, fromExpr:TypedExpr, module:ModuleType) {
		function generateInnerExpr() {
			switch [fromExpr.expr, fromExpr.t] {
				case [TLocal(v), _]:
					sb.add(scopes.getVarName(v.name, v.id));
				case [TConst(c), t]:
					generateTConst(sb, c, t);
				case [TBlock(el), _]:
					generateTBlock(sb, el);
				case [TCall(e, el), _]:
					generateCommonTCall(sb, e, el);
				case [TObjectDecl(fields), _]:
					generateTObjectDecl(sb, fields);
				case [TField(e, fa), TFun(_, _)]:
					final ft = TypeResolver.resolve(fromExpr.t);
					//trace(ft);
					sb.add('$ft = ');
					generateTField(sb, e, fa);
				case [TField(e, fa), _]:
					generateTField(sb, e, fa);
				case [TBinop(op, e1, e2), _]:
					generateTBinop(sb, op, e1, e2);
				case [TTypeExpr(m), _]:
					trace(m);
				case [TCast(e, m), t]:
					generateTCast(sb, toExpr, e, m);
				//case [TInst(t, params), _]:
				//	trace(t);
				case [v, _]:
					throw 'Unsupported ${v}';
			}
		}

		switch toExpr.t {
			case TDynamic(_):
				var name = switch fromExpr.t {
					case TAnonymous(a):
						TypeContext.getObjectTypeByFields(a.get().fields).name;
					case _:
						null;
				}

				if (name != null) {
					TypeContext.addDynamicSupport(name);
					generateInnerExpr();
				} else {
					generateInnerExpr();
				}
			case TAbstract(_.get().name => "Null" , _):
				generateInnerExpr();
			case TAbstract(_, _):
				generateInnerExpr();
			case _:
				final fromType = TypeResolver.resolve(fromExpr.t);
				final toType = TypeResolver.resolve(toExpr.t);
				//trace('cast $fromType to $toType');
				sb.add('cast[$toType](');
				generateInnerExpr();
				sb.add(")");
		}
	}

	public function generateShadowAnons(sb:IndentStringBuilder, anons: Array<{i: Int, name: String}>) {
		return; // rethink optimzation
		if (anons != null) for (d in anons) { // shadow and unpack anon objects
			sb.add('var ${d.name} = ${d.name}.fromDynamic(DynamicHaxeObjectRef)');
			sb.addNewLine(Same);
		}		
	}

	/**
	 * Generate TFunction
	 */
	function generateTFunction(sb:IndentStringBuilder, func:TFunc) {
		scopes.newScope();
		var args = "";
		var anons = [];
		if (func.args.length > 0) {
			var largs = [for (a in func.args) {name: scopes.createVar(a.v, true), t: a.v.t}];
			for (i => x in largs) {
				if (i > 0) args += ", ";
				final tn = TypeResolver.resolve(x.t);
				switch x.t {
					case TAnonymous(a):
						anons.push({i:i, name: x.name});
						args += '${x.name}:${tn}Wrapper';
					case _:
						args += '${x.name}:$tn';
				}
			}
		}

		sb.addNewLine(Inc);
		sb.add("proc(");

		sb.add(args);

		sb.add("):");
		sb.add(TypeResolver.resolve(func.t));
		sb.add(" = ");
		sb.addNewLine(Inc);

		generateShadowAnons(sb, anons);

		switch (func.expr.expr) {
			case TBlock(el):
				generateTBlock(sb, el, true);
			case v:
				throw 'Unsupported ${v}';
		}

		sb.addNewLine(Dec);
		sb.addNewLine(Dec);
		scopes.popScope();
	}

	/**
	 * Generate code for TReturn
	 */
	function generateTReturn(sb:IndentStringBuilder, expression:TypedExpr) {
		var isDynamicReturn = false;
		var isVoidReturn = false;
		var needBrackets = false;
		if (returnType != null) {
			switch returnType {
				case TAbstract(t, _), TFun(_, TAbstract(t,_)) if (t.get().name == "Void"): 
					isVoidReturn = true;
				case TDynamic(_):
					switch expression.t {
						case TDynamic(_):
						case TAnonymous(_):
						case _:
							isDynamicReturn = true;
					}
				case _:
			}
		}

		function addReturn() {
			if (isDynamicReturn) {
				sb.add("return toDynamic(");
			} else {
				sb.add("return ");
				if (needBrackets) sb.add("(");
			}
		}

		function addClose() {
			if (isDynamicReturn || needBrackets) {
				sb.add(")");
			}
		}

		if (expression == null || expression.expr == null) {
			sb.add("return");
		} else {
			final ovd = pushVoid(isVoidReturn);
			switch (expression.expr) {
				case TBlock(e):
					generateTBlock(sb, e);
				case TReturn(e):
					generateTReturn(sb, e);
				case TCall(e, el):
					addReturn();
					generateCommonTCall(sb, e, el);
					addClose();
				case TNew(c, params, el):
					addReturn();
					generateTNew(sb, c.get(), params, el);
					addClose();
				case TConst(c):
					addReturn();
					generateTConst(sb, c, expression.t);
					addClose();
				case TFunction(tfunc):
					addReturn();
					generateTFunction(sb, tfunc);
					addClose();
				case TBinop(op, e1, e2):
					needBrackets = true;
					addReturn();
					generateTBinop(sb, op, e1, e2);
					addClose();
				case TUnop(op, postFix, e):
					addReturn();
					generateTUnop(sb, op, postFix, e);
					addClose();
				case TArray(e1, e2):
					addReturn();
					generateTArray(sb, e1, e2);
					addClose();
				case TLocal(v):
					addReturn();
					generateTLocal(sb, v);
					addClose();
				case TObjectDecl(fields):
					addReturn();
					generateTObjectDecl(sb, fields);
					addClose();
				case TCast(e, m):
					addReturn();
					generateTCast(sb, expression, e, m);
					addClose();
				case TField(e, fa):
					addReturn();
					generateTField(sb, e, fa);
					addClose();
				case TMeta(m, e1):
					generateTMeta(sb, m, e1);
				case TIf(econd, eif, eelse):
					addReturn();
					generateTIf(sb, econd, eif, eelse);
					addClose();
				case TThrow(e):
					generateTThrow(sb, e);
				case v:
					throw 'Unsupported ${v}';
			}
			popVoid(ovd);
		}
	}

	var binOpLevel = 0;
	/**
	 * Generate code for TBinop
	 */
	function generateTBinop(sb:IndentStringBuilder, op:Binop, e1:TypedExpr, e2:TypedExpr) {
		binOpLevel++;
		final ovd = pushVoid(false);
		final needBrackets = (binOpLevel > 1) || (switch op {
			case OpBoolOr | OpShr | OpShl | OpUShr | OpOr | OpAnd  : true;
			case OpAssign:
				switch e1.expr {
					case TLocal(v) if (scopes.isParamVar(v)):
						sb.add("var ");
						scopes.shadowParamVar(v);
					case _:
				}
				false;
			case _: 
				false;
		} );
		if (needBrackets) sb.add("(");
		final typMix: TypeMix  = switch op {
			case OpUShr: FirstUInt; 
			case OpAdd | OpAssign | OpAssignOp(_):
				if (e1.t.isString()) {
					if (e2.t.isString()) StringString
					else FirstString;
				} 
				else if (e2.t.isString()) SecondString
				else if (e1.t.isFloat() && e2.t.isInt()) FloatInt
				else if (e1.t.isInt() && e2.t.isFloat()) IntFloat
				else if (e1.t.isDynamic() && e2.t.isInst()) DynamicAndTInst
				else if (e1.t.isInst() && e2.t.isDynamic()) TInstAndDynamic
				else None;
			case OpMult | OpDiv | OpSub | OpEq | OpNotEq | OpGt |
				OpGte | OpLt | OpLte | OpMod :
				if (e1.t.isFloat() && e2.t.isInt()) FloatInt
				else if (e1.t.isInt() && e2.t.isFloat()) IntFloat
				else None;		
			case _: None;
		}
		if ( !op.match(OpAssign) && !op.match(OpAssignOp(_)) ) switch typMix {
			case IntFloat: sb.add("toFloat(");
			case SecondString: sb.add("$(");
			case _:
		}
		generateTBlockSingleExpression(sb, e1, false);
		switch typMix {
			case IntFloat | SecondString: if ( !op.match(OpAssign) && !op.match(OpAssignOp(_))) sb.add(")");
			case FirstUInt: sb.add(".uint32");
			case TInstAndDynamic: 
				//sb.add('.fromDynamic(${TypeResolver.resolve(e1.t)})');
			case _:
		}
		sb.add(" ");
		switch (op) {
			case OpAdd:
				switch typMix {
					case FirstString | SecondString | StringString: sb.add("&");
					case _: sb.add("+");
				}
			case OpMult:
				sb.add("*");
			case OpDiv:
				sb.add("/");
			case OpSub:
				sb.add("-");
			case OpAssign:
				sb.add("=");
			case OpEq:
				sb.add("==");
			case OpNotEq:
				sb.add("!=");
			case OpGt:
				sb.add(">");
			case OpGte:
				sb.add(">=");
			case OpLt:
				sb.add("<");
			case OpLte:
				sb.add("<=");
			case OpAnd:
				sb.add("and");
			case OpOr:
				sb.add("or");
			case OpXor:
				sb.add("xor");
			case OpBoolAnd:
				sb.add("and");
			case OpBoolOr:
				sb.add("or");
			case OpShl:
				sb.add("shl");
			case OpShr:
				sb.add("shr");
			case OpUShr:
				sb.add("shr");
			case OpMod:
				sb.add("mod");
			case OpAssignOp(op):
				switch op {
					case OpAdd:
						switch typMix {
							case FirstString | SecondString | StringString:
								sb.add("&=");
							case _:
								sb.add("+=");
							}
					case OpDiv:
						sb.add("/=");
					case OpSub:
						sb.add("-=");
					case OpMult:
						sb.add("*=");
					case OpOr:
						sb.add("|=");
					case v:
						//trace(e1.pos);
						throw 'Unsupported ${v} at ${e1.pos}';
				}
			case OpInterval:
			case OpArrow:
			case OpIn:
			case OpNullCoal:
		}
		sb.add(" ");
		switch typMix {
			case FloatInt: sb.add("toFloat(");
			case FirstString: sb.add("$(");
			case TInstAndDynamic:
				sb.add('fromDynamic(');				
			//case IntFloat if (op.match(OpAssign) || op.match(OpAssignOp(_))): 
			case _:
		}
		switch e2.expr {
			case null:
			case TBlock(el):
				generateTBlock(sb, el, false);
			case _:
				generateTBlockSingleExpression(sb, e2, false);
		}
		switch typMix {
			case FloatInt | FirstString: sb.add(")");
			case TInstAndDynamic: sb.add(', ${TypeResolver.resolve(e1.t)})');
			case IntFloat:
				switch op {
					case OpAdd | OpAssign | OpAssignOp(_):
					case _:
				}
			case _:
		}
		if (needBrackets) sb.add(")");
		if (typMix.match(FirstUInt)) sb.add(".int32");
		popVoid(ovd);
		binOpLevel--;
	}

	/**
	 * Generate code for TUnop
	 */
	function generateTUnop(sb:IndentStringBuilder, op:Unop, post:Bool, expr:TypedExpr) {

		inline function incdec(opCall: String) {
			sb.add('$opCall(');
			switch (expr.expr) {
				case TLocal(v):
					generateTLocal(sb, v);
				case TField(e, fa):
					generateTField(sb, e, fa);
				case v:
					throw 'Unsupported ${v}';
			}
			sb.add(")");		
		}

		switch (op) {
			case OpIncrement:
				incdec(if (post) "apOperator" else "bpOperator");
			case OpDecrement:
				incdec(if (post) "ammOperator" else "bmmOperator");
			case OpNot:
				sb.add("not ");
				generateTBlockSingleExpression(sb, expr, false);
			case OpNeg:
				sb.add("- ");
				generateTBlockSingleExpression(sb, expr, false);
			case OpNegBits:
				sb.add("~ ");
				generateTBlockSingleExpression(sb, expr, false);
			case OpSpread:
				throw 'Unsupported';
		}
	}

	/**
	 * Generate code for static field referrence
	 */
	function generateTFieldFStatic(sb:IndentStringBuilder, classType:ClassType, classField:ClassField) {
		var fieldData = getStaticTFieldData(classType, classField);
		switch TypeTools.followWithAbstracts(classField.type) {
			case TFun(_, _):
				sb.add(TypeResolver.resolve(classField.type));
				sb.add("= ");
			case TInst(t, params):
				//sb.add(t.get().name);
				//sb.add(TypeResolver.resolveParameters(params));
				//sb.add("=  ");
				//trace(params);
			case TType(t, params):
				sb.add(t.get().name);
				sb.add(TypeResolver.resolveParameters(params));
				sb.add("=   ");
				//trace(params);
			case TEnum(t, params):
				sb.add(t.get().name);
				sb.add(TypeResolver.resolveParameters(params));
				sb.add("= block: "); // hacky
			case TAbstract(t, params):
				if (params.length > 0) {
					throw 'Unsupported ${t}';
				}
			case v:
				throw 'Unsupported ${v}';
		}

		sb.add(fieldData.totalName);
	}

	/**
	 * Generate code for instance field referrence
	 */
	function generateTFieldFInstance(sb:IndentStringBuilder, classType:ClassType, params:Array<Type>, classField:ClassField) {
		var fieldData = getInstanceTFieldData(classType, params, classField);

		sb.add(".");
		sb.add(fieldData.fieldName);
	}

	/**
	 * Generate code for anon field call
	 */
	function generateTCallTFieldFAnon(sb:IndentStringBuilder, classField:ClassField) {
		var fieldName = classField.name;
		sb.add('.$fieldName');
	}

	/**
	 * Generate code for static field call
	 */
	function generateTCallTFieldFStatic(sb:IndentStringBuilder, classType:ClassType, classField:ClassField) {
		var fieldData = getStaticTFieldData(classType, classField);
		sb.add(fieldData.totalName);
	}

	/**
	 * Generate code for instance field call
	 */
	function generateTCallTFieldFInstance(sb:IndentStringBuilder, classType:ClassType, params:Array<Type>, classField:ClassField) {
		var fieldData = getInstanceTFieldData(classType, params, classField);

		sb.add(".");
		sb.add(fieldData.fieldName);
	}

	/**
	 * Generate code for calling base class field
	 */
	function generateSuperCall(sb:IndentStringBuilder, classType:ClassType, classField:ClassField) {
		final name = TypeResolver.resolveClassType(classType, [for (p in classType.params) p.t]);
		//var name = classType.name;
		sb.add('procCall(cast[${name}](this)');
	}

	/**
	 * Generate code for calling field
	 */
	function generateTCallTField(sb:IndentStringBuilder, expression:TypedExpr, access:FieldAccess): Bool {
		var res = false;
		switch (expression.expr) {
			case TTypeExpr(_):
			case TConst(TSuper):
				switch (access) {
					case FInstance(c, params, cf):
						generateSuperCall(sb, c.get(), cf.get());
						res = true;
					case v:
						throw 'Unsupported ${v}';
				}
			case TConst(c):
				generateTConst(sb, c, expression.t);
			case TNew(c, params, el):
				generateTNew(sb, c.get(), params, el);
			case TCall(e, el):
				generateCommonTCall(sb, e, el);
			case TLocal(v):
				generateTLocal(sb, v);
			case TField(e, fa):
				generateTField(sb, e, fa);
			case TParenthesis(e):
				sb.add("(");
				generateTBlockSingleExpression(sb, e);
				sb.add(")");
			case TIdent(s):
				//trace('skip ident $s for now'); //TODO fix it
				sb.add(s);
			case v:
				generateTBlockSingleExpression(sb, expression, false);
				//throw 'Unsupported ${v}';
		}

		switch (access) {
			case FInstance(c, params, cf):
				generateTCallTFieldFInstance(sb, c.get(), params, cf.get());
			case FStatic(c, cf):
				generateTCallTFieldFStatic(sb, c.get(), cf.get());
			case FAnon(cf):
				generateTCallTFieldFAnon(sb, cf.get());
			case FDynamic(s):
				sb.add('{"${s}"}');
			case v:
				throw 'Unsupported ${v}';
		}
		return res;
	}

	/**
	 * Generate field of object
	 */
	function generateTField(sb:IndentStringBuilder, expression:TypedExpr, access:FieldAccess) {
		function genAccess() {
			switch (access) {
				case FInstance(c, params, cf):
					generateTFieldFInstance(sb, c.get(), params, cf.get());
				case FStatic(c, cf):
					generateTFieldFStatic(sb, c.get(), cf.get());
				case FEnum(e, ef):
					var name = TypeResolver.getFixedTypeName(e.get().name);
					sb.add('new${name}${ef.name}()');
				case FAnon(cf):
					var name = cf.get().name;
					sb.add('{"${name}"}');
				case FDynamic(s):
					sb.add('{"${s}"}');
				case v:
					throw 'Unsupported ${v}';
			}
		}

		switch (expression.expr) {
			case TTypeExpr(_):
				genAccess();
			case TConst(c):
				generateTConst(sb, c, expression.t);
				genAccess();
			case TLocal(v):
				switch access {
					case FInstance(c, params, cf):
						if (c.get().isInterface) {
							var tp = TypeResolver.resolve(cf.get().type);
							sb.add('cast[${tp}](');
							generateTLocal(sb, v);
							generateTFieldFInstance(sb, c.get(), params, cf.get());
							sb.add(")");
						} else {
							generateTLocal(sb, v);
							generateTFieldFInstance(sb, c.get(), params, cf.get());
						}
					case FClosure(c, cf):
						generateTLocal(sb, v);
						if (c != null)
							generateTFieldFInstance(sb, c.c.get(), c.params, cf.get());
					case FAnon(_) | FDynamic(_):
						generateTLocal(sb, v);
						genAccess();
					case _:
						generateTLocal(sb, v);
				}
			case TField(e, fa):
				generateTField(sb, e, fa);
				genAccess();
			case TCast(e, m):
				generateTCast(sb, expression, e, m);
				genAccess();
			case TParenthesis(e):
				sb.add("(");
				generateTBlockSingleExpression(sb, e);
				sb.add(")");
				genAccess();				
			case v:
				throw 'Unsupported ${v}';
		}
	}

	/**
	 *	Generate code for Nim.code("some nim code")
	 *	Return true if processed
	 */
	function generateRawCodeCall(sb:IndentStringBuilder, expression:TypedExpr, expressions:Array<TypedExpr>):Bool {
		switch (expression.expr) {
			case TField(_, fa):
				switch (fa) {
					case FStatic(c, cf):
						var classType = c.get();
						var classField = cf.get();
						switch classType.name {
							case "NimExtern":
								switch classField.name {
									case "rawCode":
										var error = "Raw code must have one string parameter";
										if (expressions.length != 1)
											throw error;

										switch expressions[0].expr {
											case TConst(c):
												switch c {
													case TString(s):
														sb.add(s);
													case _:
														throw error;
												}
											case _:
												throw error;
										}
										return true;
								}
							case _:
						}
					case _:
				}
			case _:
		}

		return false;
	}

	/**
	 * Generate code for common TCall
	 */
	// TODO: refactor that
	function generateCommonTCall(sb:IndentStringBuilder, expression:TypedExpr, expressions:Array<TypedExpr>) {
		// Check raw code paste
		if (generateRawCodeCall(sb, expression, expressions))
			return;

		var isTraceCall = false;
		var isAsync = false;
		var needExtraBracket = false;
		final needDiscard = needVoid && ! isVoid(expression.t);
		#if (false)
		{
			case TInst(_, _): true;
			case TAbstract(t, _): t.get().name != "Void";
			case TFun(_, TAbstract(t, _)): t.get().name != "Void";
			case _: false;
		}
		#end
		if (needDiscard) 
			sb.add("discard ");
		switch (expression.expr) {
			case TField(_, FEnum(c, ef)):
				var name = c.get().name;
				sb.add('new${name}${ef.name}');
				sb.add("(");
			case TField(e, fa):
				switch (e.expr) {
					case TTypeExpr(m):
						switch (m) {
							case TClassDecl(c):
								switch c.get().name {
									case "Log":
										isTraceCall = true;
									case "Async_Impl_":
										isAsync = true;
								}
							case _:
						}
					case _:
				}

				if (!isAsync) {
					needExtraBracket = generateTCallTField(sb, e, fa);
					sb.add("(");
				}
			case TConst(TSuper):
				if (classContext.classType.superClass != null) {
					final superCls = classContext.classType.superClass.t.get();
					final superName = TypeResolver.resolveClassType(superCls, [for (p in superCls.params) p.t]);
					//var superName = superCls.name;
					sb.add('init${superName}(this, ');
				}
			case TLocal(v):
				generateTLocal(sb, v);
				sb.add("(");
			case TIdent(s):
				trace('dont know what to do with $s');
			case v:
				throw 'Unsupported ${v}';
		}

		var funArgs = switch (expression.t) {
			case TFun(args, _):
				args;
			case _:
				null;
		}

		var wasConverter = false;
		final ovd = pushVoid(false);
		for (i in 0...expressions.length) {
			var expr = expressions[i];
			var farg = if (funArgs != null) {
				funArgs[i];
			} else null;

			if (farg != null) {
				switch farg.t {
					case TInst(t, _):
						var tp = t.get();
						if (tp.isInterface) {
							sb.add('to${tp.name}(');
							wasConverter = true;
						}
					case TAnonymous(a), TType(_.get().type => TAnonymous(a), _):
						final tt = TypeResolver.resolve(farg.t);
						final ft = TypeResolver.resolve(expr.t);
						if (ft != tt && tt != "Dynamic") {
							//trace('from $ft to $tt');
							sb.add('to${tt}(');
							wasConverter = true;
						}
					case TDynamic(_) | TType(_, _):
						if (!isTraceCall) {
							switch expr.t {
								case TDynamic(_):
								case TAnonymous(a), TType(_.get().type => TAnonymous(a),_):
									//trace("from: " + TypeResolver.resolve(expr.t) + " to: " + TypeResolver.resolve(farg.t));
								case TType(_, _):
								case _:
									sb.add('toDynamic(');
									wasConverter = true;
							}
						}
					case _:
				}
			}

			switch (expr.expr) {
				case TConst(c):
					generateTConst(sb, c, expr.t);
				case TObjectDecl(e):
					if (isTraceCall) {
						generateTObjectDeclTrace(sb, e);
					} else
						generateTObjectDecl(sb, e);
				case TFunction(tfunc):
					generateTFunction(sb, tfunc);
				case TLocal(v):
					if (farg != null) {
						switch v.t {
							case TInst(t, _):
								switch farg.t {
									case TType(_, _) | TAnonymous(_) | TDynamic(_):
										var name = t.get().name;
										TypeContext.addDynamicSupport(name);
									case _:
								}
							case _:
						}
					}

					generateTLocal(sb, v);
				case TNew(c, params, el):
					generateTNew(sb, c.get(), params, el);
				case TBinop(op, e1, e2):
					generateTBinop(sb, op, e1, e2);
				case TField(e, fa):
					generateTField(sb, e, fa);
				case TCall(e, el):
					generateCommonTCall(sb, e, el);
				case TArray(e1, e2):
					generateTArray(sb, e1, e2);
				case TCast(e, m):
					generateTCast(sb, expr, e, m);
				case TBlock(el):
					generateTBlock(sb, el);
				case TArrayDecl(el):
					generateTArrayDecl(sb, el, expr);
				case TMeta(m, e1):
					generateTMeta(sb, m, e1);
				case TUnop(op, postFix, e):
					generateTUnop(sb, op, postFix, e);
				case TIf(econd, eif, eelse):
					generateTIf(sb, econd, eif, eelse);
				case v:
					throw 'Unsupported ${v}';
			}

			// generateTypedAstExpression(sb, expr);
			if (i + 1 < expressions.length)
				sb.add(", ");
		}
		popVoid(ovd);
		if (!isAsync)
			sb.add(")");
		if (needExtraBracket)
			sb.add(")");
		if (wasConverter)
			sb.add(")");
	}

	/**
	 * Generate code for root TCall in block
	 */
	function generateBlockTCall(sb:IndentStringBuilder, expression:TypedExpr, expressions:Array<TypedExpr>, checkReturn = true) {
		// Detect if need discard type
		if (checkReturn) switch (expression.expr) {
			case TField(_, fa):
				var cfield:ClassField = null;
				switch (fa) {
					case FInstance(_, _, cf):
						cfield = cf.get();
					case FStatic(_, cf):
						cfield = cf.get();
					case FAnon(cf):
						cfield = cf.get();
					case FDynamic(s):
						trace(s);
					case _:
				}
				if (cfield == null) 
					trace('$fa at ${expression.pos}');
				var hasReturn = false;
				if (cfield != null) switch (cfield.type) {
					case TFun(_, ret):
						switch (ret) {
							case TInst(t, _):
								hasReturn = true;
							case TAbstract(t, _):
								if (t.get().name != "Void")
									hasReturn = true;
							case _:
						}
					case _:
				}

				if (hasReturn && checkReturn) {
					sb.add('discard ');
				}
			case _:
		}

		generateCommonTCall(sb, expression, expressions);
	}

	/**
	 * Generate code for TIf
	 */
	function generateTIf(sb:IndentStringBuilder, econd:TypedExpr, eif:TypedExpr, eelse:TypedExpr) {
		sb.add("if ");
		final ovd = pushVoid(false);
		switch (econd.expr) {
			case TParenthesis(e):
				switch e.expr {
					case TBinop(op, e1, e2):
						generateTBinop(sb, op, e1, e2);
					case TField(e, fa):
						generateTField(sb, e, fa);
					case TCall(e, el):
						generateCommonTCall(sb, e, el);
					case TUnop(op, postFix, e):
						generateTUnop(sb, op, postFix, e);
					case TLocal(v):
						generateTLocal(sb, v);
					case v:
						throw 'Unsupported ${v}';
				}
			case v:
				throw 'Unsupported ${v}';
		}
		popVoid(ovd);
		sb.add(":");
		sb.addNewLine(Inc);

		switch (eif.expr) {
			case TConst(c):
				generateTConst(sb, c, eif.t);
			case TNew(c, params, el):
				generateTNew(sb, c.get(), params, el);
			case TReturn(e):
				generateTReturn(sb, e);
			case TBinop(op, e1, e2):
				generateTBinop(sb, op, e1, e2);
			case TCall(e, el):
				generateCommonTCall(sb, e, el);
			case TMeta(m, e1):
				generateTMeta(sb, m, e1);
			case TBlock(el):
				generateTBlock(sb, el, true);
			case TField(e, fa):
				generateTField(sb, e, fa);
			case TLocal(v):
				generateTLocal(sb, v);
			case TCast(e, m):
				generateTCast(sb, eif, e, m);
			case TUnop(op, postFix, e):
				generateTUnop(sb, op, postFix, e);
			case TThrow(e):
				generateTThrow(sb, e);
			case TContinue:
				sb.add("continue");
				sb.addNewLine(Same);
			case TBreak:
				sb.add("break");
				sb.addNewLine(Same);
			case v:
				throw 'Unsupported ${v}';
		}

		if (eelse != null) {
			sb.addNewLine(Dec);
			sb.add("else:");
			sb.addNewLine(Inc);

			switch (eelse.expr) {
				case TConst(c):
					generateTConst(sb, c, eelse.t);
				case TBlock(el):
					generateTBlock(sb, el, needVoid);
					#if (false)
					if (el.length > 0) {
						switch (eelse.expr) {
							case v:
								throw 'Unsupported ${v}';
						}
					}
					#end
				case TBinop(op, e1, e2):
					generateTBinop(sb, op, e1, e2);
				case TCall(e, el):
					generateCommonTCall(sb, e, el);
				case TMeta(m, e1):
					generateTMeta(sb, m, e1);
				case TLocal(v):
					generateTLocal(sb, v);
				case TField(e, fa):
					generateTField(sb, e, fa);
				case TNew(c, params, el):
					generateTNew(sb, c.get(), params, el);
				case TBreak:
					sb.add("break");
					sb.addNewLine(Same);
				case TContinue:
					sb.add("continue");
					sb.addNewLine(Same);
				case TIf(econd, eif, eelse):
					generateTIf(sb, econd, eif, eelse);
				case TReturn(e):
					generateTReturn(sb, e);
				case v:
					throw 'Unsupported ${v}';
			}
		}
		sb.addNewLine(Dec);
	}

	/**
	 * Generate code for TWhile
	 */
	function generateTWhile(sb:IndentStringBuilder, econd:TypedExpr, whileExpression:TypedExpr, isNormal:Bool) {
		sb.add("while ");
		final ovd = pushVoid(false);
		generateTBlockSingleExpression(sb, econd, false);
		popVoid(ovd);
		sb.add(":");
		sb.addNewLine(Inc);

		switch (whileExpression.expr) {
			case TBinop(op, e1, e2):
				generateTBinop(sb, op, e1, e2);
			case TBlock(el):
				generateTBlock(sb, el, true);
			case TCall(e, el):
				generateCommonTCall(sb, e, el);
			case v:
				throw 'Unsupported ${v}';
		}

		sb.addNewLine(Dec, true);
	}

	/**
	 * Generate TFor expression
	 */
	function generateTFor(sb:IndentStringBuilder, v:TVar, e1:TypedExpr, e2:TypedExpr) {						
		sb.add("while ");
		var nsb = new IndentStringBuilder();
		switch e1.expr {
			case TField(e, fa):
				generateTField(nsb, e, fa);
			case v:

		}

		var cfield = nsb.toString();

		sb.add('${cfield}.hasNext():');

		sb.addNewLine(Inc);
		sb.add('var ${v.name} = ${cfield}.next()');
		sb.addNewLine(Same);
		switch e2.expr {
			case TCall(e, el):
				generateCommonTCall(sb, e, el);
			case v:
				throw 'Unsupported ${v}';
		}

		sb.addNewLine(Dec);
	}

	/**
	 * Generate single try catch expression
	 */
	function generateTTryExpression(sb:IndentStringBuilder, expr:TypedExpr, catches:Array<{v:TVar, expr:TypedExpr}>) {
		sb.add("try:");
		sb.addNewLine(Inc);
		generateTBlockSingleExpression(sb, expr);
		sb.addNewLine(Dec);
		for (e in catches) {
			var etname = TypeResolver.resolve(e.v.t);
			if (etname == "Dynamic") etname = "Exception";
			switch e.expr.expr {
				case TBlock(el) if (el.length == 0):
					switch etname {
						case "Exception":
							sb.add('except: discard');
						case _:
							sb.add('except $etname : discard');
					}
				case _:
					sb.add('except $etname as ${e.v.name} :');
					sb.addNewLine(Inc);
					generateTBlockSingleExpression(sb, e.expr);
					sb.addNewLine(Dec);	
			}
		}	
	}

	function isVoid(t:Type): Bool {
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

	/**
	 * Generate single expression from TBlock
	 */
	public function generateTBlockSingleExpression(sb:IndentStringBuilder, expr:TypedExpr, newLine = true) {
		if (expr != null) switch (expr.expr) {
			case TConst(c):
			// TODO: handle THIS
				generateTConst(sb, c, expr.t);
			case TVar(v, expr):
				generateTVar(sb, v, expr);
			case TCall(e, el):
				#if (false)
				final hasDiscard = needVoid && ! isVoid(e.t);
				if (hasDiscard) {
					sb.add("discard ");
					trace('${e.pos} ${e.t}');
				}
				final ovd = pushVoid(false);
				#end
				if (! newLine) 
					generateCommonTCall(sb, e, el);
				else
					generateBlockTCall(sb, e, el, false);
				//popVoid(ovd);
			case TReturn(e):
				generateTReturn(sb, e);
			case TBinop(op, e1, e2):
				generateTBinop(sb, op, e1, e2);
			case TBlock(el):
				if (newLine) 
					generateTBlock(sb, el, true);
				else generateTBlockInline(sb, el);
			case TIf(econd, eif, eelse):
				generateTIf(sb, econd, eif, eelse);
			case TWhile(econd, e, normalWhile):
				generateTWhile(sb, econd, e, normalWhile);
			case TMeta(m, e1):
				generateTMeta(sb, m, e1);
			case TUnop(op, postFix, e):
				generateTUnop(sb, op, postFix, e);
			case TSwitch(e, cases, edef):
				generateTSwitch(sb, e, cases, edef);
			case TFor(v, e1, e2):
				generateTFor(sb, v, e1, e2);
			case TCast(e, m):
				generateTCast(sb, expr, e, m);
			case TField(e, fa):
				generateTField(sb, e, fa);
			case TLocal(v):
				generateTLocal(sb, v);
			case TTry(e, catches):
				generateTTryExpression(sb, e, catches);
			case TFunction(tfunc):
				generateTFunction(sb, tfunc);
			case TEnumIndex(e1):
				generateTEnumIndex(sb, e1);
			case TArray(e1, e2):
				generateTArray(sb, e1, e2);
			case TArrayDecl(el):
				generateTArrayDecl(sb, el, expr);
			case TParenthesis(e):
				sb.add("(");
				generateTBlockSingleExpression(sb, e, newLine);
				sb.add(")");
			case TNew(c, params, el):
				generateTNew(sb, c.get(), params, el);
			case TEnumParameter(e1, ef, index):
				if (!generateCustomEnumParameterCall(sb, e1, ef, index))
					generateTEnumParameter(sb, e1, ef, index);		
			case TObjectDecl(fields):
				generateTObjectDecl(sb, fields);		
			case v:
				throw 'Unsupported ${v}';
		} else {
			trace('null expr');
		}
		if (newLine) sb.addNewLine(Same);
	}

	/**
	 * Generate code for TBlock
	 */
	function generateTBlock(sb:IndentStringBuilder, expressions:Array<TypedExpr>, isBody: Bool = false) {
		if (expressions.length > 0) {
			if ( ! isBody) {
				scopes.newScope();
				sb.add("block:");
				sb.addNewLine(Inc);	
			}
			for (x => expr in expressions) {
				final isLast = x == expressions.length - 1;
				switch (expr.expr) {
					case TLocal(_): // hacky way to filter out unnecessary local variable which should be discarded
						//trace('$isBody $x from ${expressions.length}');
						//trace('$expr');
						if (needVoid || ! isLast) 
							continue;
					case TConst(v):
						if (needVoid || ! isLast) 
							continue;
						if (isBody) {
							if (x < expressions.length - 1) continue;
							#if (false)
							switch (returnType.t.get()) {
								case TAbstract(a):
							}
							continue;
							#end
						}
					case _:
				}
				final ovd = pushVoid(needVoid || ! isLast);
				generateTBlockSingleExpression(sb, expr, true);
				popVoid(ovd);
			}
			if ( ! isBody) {
				sb.addNewLine(Dec);
				scopes.popScope();
			}
		} else {
			sb.add("discard");
		}
	}

	#if (false)
	/**
	 * Generate root block of method
	 */
	function generateTBlockRoot(sb:IndentStringBuilder, expressions:Array<TypedExpr>) {
		if (expressions.length > 0) {
			for (i in 0...expressions.length) {
				var expr = expressions[i];
				if (i >= expressions.length - 1) {
					if (returnType != null) {
						switch returnType {
							case TDynamic(_):
								sb.add("toDynamic(");
								generateTBlockSingleExpression(sb, expr);
								sb.add(")");
							case _:
								generateTBlockSingleExpression(sb, expr);
						}
					}
				} else {
					generateTBlockSingleExpression(sb, expr);
				}
			}
		} else {
			sb.add("discard");
		}
	}
	#end

	/**
	 * Generate TBlock like:
	 * (proc() : auto =
	 *  	body
	 *  )()
	 */
	function generateTBlockReturnValue(sb:IndentStringBuilder, expressions:Array<TypedExpr>) {
		sb.add("block:");
		sb.addNewLine(Inc);
		if (expressions.length > 0) {
			for (i in 0...expressions.length) {
				var expr = expressions[i];
				switch (expr.expr) {
					case TVar(v, expr):
						generateTVar(sb, v, expr);
					case TSwitch(e, cases, edef):
						generateTSwitch(sb, e, cases, edef);
					case v:
						throw 'Unsupported ${v}';
				}
			}
		}

		sb.addNewLine(Dec);
	}

	/**
	 * Generate inline block like. Relevant?
	 * (block:
	 * 		expressions
	 * )
	 */
	function generateTBlockInline(sb:IndentStringBuilder, expressions:Array<TypedExpr>) {
		sb.add("(block:");
		sb.addNewLine(Inc);
		if (expressions.length > 0) {
			for (i in 0...expressions.length) {
				var expr = expressions[i];
				if (i + 1 < expressions.length) {
					generateTBlockSingleExpression(sb, expr);
				} else {
					switch (expr.expr) {
						case TNew(c, params, el):
							generateTNew(sb, c.get(), params, el);
						case TCall(e, el):
							generateBlockTCall(sb, e, el, false);
						case TLocal(v):
							generateTLocal(sb, v);
						case TCast(e, m):
							generateTCast(sb, expr, e, m);
						case v:
							throw 'Unsupported ${v}';
					}
				}
			}
		}

		sb.addNewLine(Dec);
		sb.add(")");
	}

	/**
	 * Constructor
	 */
	public function new() {
	}

	#if (false)
	public function generateFuncArguments(sb:IndentStringBuilder, args:Array<ArgumentInfo>) {
		for (i in 0...args.length) {
			var arg = args[i];
			sb.add(arg.name);
			sb.add(":");
			sb.add(TypeResolver.resolve(arg.t));
			if (i + 1 < args.length)
				sb.add(", ");
		}
	}
	#end

	/**
	 * Generate method body
	 */
	public function generateMethodBody(sb:IndentStringBuilder, classContext:ClassInfo, methodExpression:TypedExpr, returnType:Type = null) {
		this.classContext = classContext;
		this.returnType = returnType;
		final ovd = pushVoid(returnType == null || isVoid(returnType));
		switch (methodExpression.expr) {
			case TFunction(tfunc):
				//var largs = [for (a in func.args) {name: scopes.createVar(a.v), t: a.v.t}];
				//args = largs.map(x -> '${x.name}:${TypeResolver.resolve(x.t)}').join(", ");
	
				switch (tfunc.expr.expr) {
					case TBlock(el):
						generateTBlock(sb, el, true);
					case TReturn(e):
						generateTReturn(sb, e);	
					case TFunction(tfunc):
						generateTFunction(sb, tfunc);	
					case v:
						throw 'Unsupported paramter ${v}';
				}
			case v:
				throw 'Unsupported paramter ${v}';
		}
		popVoid(ovd);
	}
}
