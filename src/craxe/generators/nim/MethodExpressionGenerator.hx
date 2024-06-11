package craxe.generators.nim;

import haxe.xml.Check;
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
import haxe.macro.PositionTools;
import craxe.common.IndentStringBuilder;
import craxe.generators.nim.type.*;
import craxe.common.ContextMacro;
import craxe.common.tools.BinSearch;
import craxe.common.ast.type.ObjectType;

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
		var useName = NimNames.normalize(vr.name);
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
		return if (n != null) n else NimNames.fixed(name);
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
	static final BOOL = Context.typeof(macro true);
	static final VOID = Context.typeof(macro {});


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
	var helperVarId = 0;

	function genHelperVar(name: String, t: Type): TVar {
		final vr: TVar = {id: --helperVarId, name: name, t: t, capture: false, meta: null, extra: null};
		return vr;
	}

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

	public inline function pushVoid(v: Bool): Bool {
		final res = needVoid;
		needVoid = v;
		return res;
	}

	public inline function popVoid(v: Bool) {
		needVoid = v;
	}

	/**
	 * Generate code for TMeta
	 */
	function generateTMeta(sb:IndentStringBuilder, meta:MetadataEntry, expression:TypedExpr) {
		//trace('meta $meta');
		generateSingleExpression(sb, expression, true);
	}

	/**
	 * Generate code for TThrow
	 */
	function generateTThrow(sb:IndentStringBuilder, e:TypedExpr) {
		// TODO: normal error throw
		var err = switch e.expr {
			case TConst(c): getConstAsString(c, false);
			default : "Error";
		}
		sb.add('raise newException(Exception, "${err}")');
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
		sb.add(".qindex");
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
						final enumName = NimNames.fixed(ent.name);
						final instName = NimNames.fixed(ent.names[ef.index]);
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
	 * Generate code for TSwitch as chain of if's
	 */
	 function generateTSwitchAsIf(sb:IndentStringBuilder, expression:TypedExpr, cases:Array<{values:Array<TypedExpr>, 
		expr:TypedExpr}>, edef:TypedExpr, promo: TypePromotion) 
	{
		scopes.newScope();
		sb.add("block:");
		sb.addNewLine(Inc);	
		final ovd = pushVoid(false);
		if (! ovd) sb.add("(");
		final svar: TVar = genHelperVar("svar", expression.t);
		generateTVar(sb, svar, expression);
		final evar: TypedExpr = {t: expression.t, pos: expression.pos, expr: TLocal(svar)};
		var first = true;
		for (cs in cases) {
			needVoid = false;
			if (first) sb.add("if ");
			else sb.add("elif ");
			first = false;
			var cond: TypedExpr = null;
			for (val in cs.values) {
				var term = {t: BOOL, pos: expression.pos, expr: TBinop(OpEq, evar, val)};
				if (cond == null) cond = term;
				else cond = {t: BOOL, pos: expression.pos, expr: TBinop(OpBoolOr, cond, term)};
			}
			switch cond.expr {
				case TBinop(op, e1, e2): generateTBinop(sb, op, e1, e2);
				default: 
					trace("WTF !!!");
			}
			sb.add(" :");
			sb.addNewLine(Inc);
			needVoid = ovd;
			promo.start();
			generateSingleExpression(sb, cs.expr, false);
			promo.promote(cs.expr);
			promo = promo.copy();
			sb.addNewLine(Dec);
		}
		if (edef != null) {
			sb.add('else :');
			sb.addNewLine(Inc);
			promo.start();
			generateSingleExpression(sb, edef, false);
			promo.promote(edef);
			sb.addNewLine(Dec);
		}
		if (! ovd) sb.add(")");
		sb.addNewLine(Dec);
		scopes.popScope();
	}

	/**
	 * Generate code for TSwitch
	 */
	function generateTSwitch(sb:IndentStringBuilder, expression:TypedExpr, cases:Array<{values:Array<TypedExpr>, expr:TypedExpr}>, 
			edef:TypedExpr, promo: TypePromotion) 
	{
		for (cs in cases) {
			for (val in cs.values) {
				if (! val.expr.match(TConst(_))) {
					generateTSwitchAsIf(sb, expression, cases, edef, promo);
					return;
				}
			}
		}
		final ovd = pushVoid(false);
		if (! ovd) sb.add("(");
		sb.add("case ");
		switch (expression.expr) {
			case TParenthesis(e):
				if (TypeResolver.isString(e.t)) 
					sb.add("$");
				generateSingleExpression(sb, e, false);
			case v:
				throw 'Unsupported ${v}';
		}
		popVoid(ovd);
		for (cs in cases) {
			sb.addNewLine(Same);
			sb.add("of ");
			for (x => val in cs.values) {
				if (x > 0) {
					sb.add(", ");
					if (x % 4 == 0) sb.addNewLine(Same);
				}
				switch (val.expr) {
					case TConst(c):
						generateTConst(sb, c, val.t);
					case v:
						throw 'Unsupported ${v}';
				}
			}
			sb.add(" :");
			sb.addNewLine(Inc);
			promo.start();
			generateSingleExpression(sb, cs.expr, true);
			if (TypeResolver.isString(expression.t)) {
				if (cs.expr.expr.match(TConst(_)))
					sb.add('.toXString');
			} else if (TypeResolver.isDynamic(expression.t))
				sb.add('.toDynamic');
			promo.promote(cs.expr);
			promo = promo.copy();
			sb.addNewLine(Dec);
		}

		sb.add('else:');
		sb.addNewLine(Inc);
		if (edef == null) {
			sb.add('raise newException(Exception, "Invalid case")');
		} else {
			promo.start();
			generateSingleExpression(sb, edef, false);
			promo.promote(edef);
		}

		if (! ovd) sb.add(")");
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

		var fieldName =  classField.meta.getMetaValue(":native"); 
		var totalName = "";
		final Static = switch classField.kind {
			case FVar(read, write): 'StaticInst';
			case FMethod(k): 'Static';
		}
		if (classType.isExtern) {
			if (fieldName == null) fieldName = NimNames.fixOnly(classField.name);
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
			if (fieldName == null) fieldName = NimNames.fixed(classField.name);
			var name = TypeResolver.resolveClassType(classType, [for (p in classType.params) p.t]);
			final dot = classField.kind.match(FMethod(_)) ? "_" : ".";
			switch classType.kind {
				case KNormal:
					className = '${name}$Static';
					totalName = '${className}${dot}${fieldName}';
				case KAbstractImpl(a):
					var abstr = a.get();
					className = name;
					//fieldName = fieldName.replace("_", "");
					totalName = '${fieldName}${className}';
				case KModuleFields(module):
					className = '${module}$Static';
					totalName = '${className}${dot}${fieldName}';
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
				fieldName = NimNames.fixed(classField.name);
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

	function getConstAsString(con: TConstant, asCode: Bool): String {
		return switch (con) {
			case TInt(i):
				Std.string(i);
			case TFloat(s):
				Std.string(s);
			case TString(s):
				if ( ! asCode) s;
				else if (s.length < MIN_STRING_CHECK_SIZE && s.indexOf("\n") < 0) {
					'"${Std.string(s)}"';
				} else {
					'"""${Std.string(s)}"""';
				}
			case TBool(b):
				Std.string(b);
			case TNull:
				//final tn = TypeResolver.resolve(t);
				// sb.add('$tn.default');
				'nil';
			case TThis:
				"this";
			case TSuper:
				"super";
		}
	}

	/**
	 * Generate code for TConstant
	 */
	public function generateTConst(sb:IndentStringBuilder, con:TConstant, t:Type) {
		sb.add(getConstAsString(con, true));
		#if (false)
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
		#end
	}

	/**
	 * Generate code for TVar
	 */
	function generateTVar(sb:IndentStringBuilder, vr:TVar, expr:TypedExpr) {
		sb.add('var ');
		//var name = TypeResolver.getFixedTypeName(vr.name);
		final name = scopes.createVar(vr, false);
		sb.add(name);
		var vartype = TypeResolver.resolve(vr.t);
		var isClosureCall = false;
		switch vartype {
			case "int32", "float", "Dynamic", "String": sb.add(': $vartype');
			case _ if (expr == null || expr.expr.match(TConst(TNull))) : sb.add(': $vartype');
			case _ if (expr.t.match(TFun(_))) :
				sb.add(': $vartype');
				#if (false)
				isClosureCall = switch expr.expr {
					case TField(_, FClosure(c, cf)): true;
					default: false;
				}
				#end
			default:
				switch TypeTools.followWithAbstracts(vr.t) {
					case TAnonymous(a) if (vartype.startsWith("HaxeIterator[")):
						trace('$a');
					case TAnonymous(a):
						sb.add(': ${vartype}Wrapper');
					default:
				}
			}
		

		if (expr != null) {
			sb.add(" = ");
			final ovd = pushVoid(false);
			final prom = new TypePromotion(this, sb, vr.t);
			prom.start();
			generateSingleExpression(sb, expr, false);
			prom.promote(expr);
			#if (false) // handle by TypePromotion
			if (vartype == "float" && TypeResolver.isInt(expr.t)) {
				sb.add('.toFloat');
			}
			#end
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
		ObjectType.use(classType);
		//var typeParams = TypeResolver.resolveParameters(params);
		var isPure = false;
		var clsInfo: ClassInfo = null;
		final isArray = typeName.startsWith('HaxeArray[');
		var varTypeName = if ((classType.isExtern && classType.superClass != null && classType.superClass.t.get().name == "Distinct")
							//|| (isArray) 
							|| (classType.constructor == null)) 
		{
			typeName;
		} else {
			clsInfo = TypeContext.getClassByName(classType);
			if (clsInfo == null) {
				trace("here <===================================");
				trace(classType.isExtern);
				trace(classType.isInterface);	
			}
			if (clsInfo != null && clsInfo.isPure && clsInfo.constrParams.length == elements.length) {
				isPure = true;
				typeName;
			} else 
				'new${typeName}';
		}
		if (varTypeName == "newDate") {
			trace("here <===================================");
			trace(classType.isExtern);
			trace(classType.isInterface);
			final constr = classType.constructor.get();
			final cexpr = constr.expr();
			trace(cexpr.expr);
		}
		sb.add('${varTypeName}(');
		var isFirst = true;
		if (isPure) {
			final clsName = ClassInfo.getClassName(clsInfo);
			sb.add('qkind: TClass, qstatic: ${clsInfo.basicName}StaticInst');
			isFirst = false;
		}
		if (isArray) {
			final skind = typeName.substring(10, typeName.length -1);
			if (isPure) sb.add(", kind: ");
			sb.add('getKind(${skind})');
			isFirst = false;
		}
		for (i in 0 ... elements.length) {
			if (! isFirst) sb.add(', ');
			isFirst = false;
			if (isPure) sb.add(clsInfo.constrParams[i] + ': ');
			final expr = elements[i];
			generateSingleExpression(sb, expr, false);
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
	function generateTArray(sb:IndentStringBuilder, e1:TypedExpr, e2:TypedExpr): Bool {
		if (!generateCustomBytesAccess(sb, e1.expr)) {
			generateSingleExpression(sb, e1, false);
			#if (false)
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
			#end
		}
		final dynAccess = e1.t.isDynamic();
		if (dynAccess && e2.expr.match(TCast(_,_))) {
			generateSingleExpression(sb, e2, false);
		} else {
			sb.add("[");
			generateSingleExpression(sb, e2, false);
			sb.add("]");
			return dynAccess;
		}
		return false;
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
		sb.add('HaxeArray[$pt](kind: getKind($pt), qkind:TClass ,qstatic: HaxeArrayStaticInst, data: @[');
		for (i in 0...elements.length) {
			var expr = elements[i];
			generateSingleExpression(sb, expr, false);
			#if (false)
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
			#end
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
							name: NimNames.fixed(x.name),
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
		final stodyn = fields.length > 0 ? 'cast[proc (_: DynamicHaxeObjectRef) {.nimcall.}]((proc (_: ${object.name}))(makeDynamic))' : 'nil';
		sb.add('${object.name}(qkind: TAnon, qtodyn: ${stodyn}');
		var hasFields = false;
		for (field in fields) {
			if (! hasFields) {
				hasFields = true;
				sb.addNewLine(Inc);
			} else 
				sb.addNewLine(Same);
			final fname = NimNames.fixed(field.name);
			sb.add(', ${fname}: ');
			var isFunc = false;
			switch field.expr.t {
				case TFun(args, ret): 
					final tname = TypeResolver.resolve(field.expr.t);
					sb.add('${tname} = ');
					isFunc = true;
				default:
			}
			final ovd = pushVoid(false);
			generateSingleExpression(sb, field.expr, false);
			if (isFunc) {
				switch field.expr.t {
					case TFun(args, ret): 
						final sparams = args.map(f -> NimNames.fixed(f.name)).join(", ");
						sb.add('(${sparams})');
					default:
				}
			}
			popVoid(ovd);
		}
		if (hasFields) sb.addNewLine(Dec);
		sb.add(')');
	}

	/**
	 * Genertate TCast
	 */
	function generateTCast(sb:IndentStringBuilder, toExpr:TypedExpr, fromExpr:TypedExpr, module:ModuleType) {
		function generateInnerExpr() {
			switch [fromExpr.expr, fromExpr.t] {
				case [TField(e, fa), TFun(_, _)]:
					final ft = TypeResolver.resolve(fromExpr.t);
					//trace(ft);
					sb.add('$ft = ');
					generateTField(sb, e, fa);
				case [_, _]:
					generateSingleExpression(sb, fromExpr, false);
					//throw 'Unsupported ${v}';
			}
		}
		final typTo = TypeTools.followWithAbstracts(toExpr.t);
		if ('${toExpr.pos}'.contains(':67:')) {
			trace(typTo);
		}
		switch typTo {
			case TDynamic(_):
				generateInnerExpr();
				sb.add(".toDynamic");
			case TAbstract(_.get().name => "Null" , _):
				generateInnerExpr();
			case TFun(args, ret):
				switch fromExpr.t {
					case TFun(fargs, fret):
						if (args.length != fargs.length) 
							throw 'arguments length differ at ${toExpr.pos}';
						sb.add('(proc(');
						var params = [];
						for (i => a in fargs) {
							if (i > 0) sb.add(", ");
							final pname = NimNames.normalize(a.name);
							params.push(pname);
							final tname = TypeResolver.resolve(args[i].t);
							sb.add('${pname}: ${tname}');
						}
						final tt = TypeResolver.resolve(ret);
						sb.add('):${tt} = ');
						final promo = new TypePromotion(this, sb, ret);
						promo.start(true);
						generateInnerExpr();
						sb.add("(");
						sb.add(params.join(", "));
						sb.add(")");
						promo.promote({expr: TIdent(""), t: fret, pos: null});
						promo.discard(fret);
						sb.add(")");
					case var v:
						throw 'Unsupported type $v';
				}
			case _:
				final fromType = switch fromExpr.expr {
					case TCast(e, _): 
						fromExpr = e;
						TypeResolver.resolve(e.t);
					default: TypeResolver.resolve(fromExpr.t);
				}
				//final fromType = TypeResolver.resolve(fromExpr.t);
				final toType = TypeResolver.resolve(toExpr.t);
				if (toType == "int32" && fromType != toType) {
					trace('$fromType at ${fromExpr.pos}');
					trace(fromExpr.expr);
				}
				if (fromType != toType) {
					if (fromType == "Dynamic") {
						sb.add("fromDynamic(");
						generateInnerExpr();
						sb.add(', $toType)');
					} else if (fromType == "String" && toType != "Dynamic") {
						sb.add("{");
						generateSingleExpression(sb, fromExpr, false);
						sb.add("}");
					} else {
						var needCast = false;
						switch [fromExpr.t, toExpr.t] {
							case [TInst(_, _), TType(_, _)] :
							case [TType(_, _), TInst(_, _)] :
							case [TInst(_, _), TInst(_, _)] | [TEnum(_, _), TEnum(_, _)] :
								needCast = true;
							default:
								throw 'Unsupported cast from ${fromType} to ${toType}';		
						}
						if (needCast) sb.add('cast[$toType](');
						switch fromExpr.expr {
							case TCast(e, _):
								generateSingleExpression(sb, e, false);
							default: generateInnerExpr();
						}
						if (needCast) sb.add(")");		

					}
				} else {
					generateInnerExpr();	
				}
				//trace('cast $fromType to $toType');
		}
	}

	@:deprecated
	public inline function generateShadowAnons(sb:IndentStringBuilder, anons: Array<{i: Int, name: String}>) {
		return; // rethink optimzation
	}

	public function generateShadowVars(sb:IndentStringBuilder, args:Array<{v:TVar, value:Null<TypedExpr>}>) {
		function genVarShadows(ind: Int) {
			var res = "";
			for(a in args) {
				if (! scopes.isParamVar(a.v)) {
					res += sb.calcIndent(ind);
					final aname = scopes.getVarName(a.v.name, a.v.id);
					res += 'var ${aname} = ${aname}  \n';
				}
			}
			return Str(res);
		}
		if (args.length > 0) {
			//sb.addNewLine(Inc);
			sb.addCallback(genVarShadows);
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
		generateShadowVars(sb, func.args);
		final ort = returnType;
		returnType = func.t;
		final ovd = pushVoid(func.t.isVoid());
		generateSingleExpression(sb, func.expr);
		popVoid(ovd);
		returnType = ort;
		sb.addNewLine(Dec);
		sb.addNewLine(Dec);
		scopes.popScope();
	}

	/**
	 * Generate code for TReturn
	 */
	function generateTReturn(sb:IndentStringBuilder, expression:TypedExpr, promo: TypePromotion) {
		var conv = "";
		var convTo = "";
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
							conv = "toDynamic";
					}
				case _ if (TypeResolver.isDynamic(expression.t)):
					//conv = "fromDynamic";
					//convTo = TypeResolver.resolve(returnType);
				#if (false) // handle by TypePromotion
				case _ if (TypeResolver.isFloat(returnType)):
					if (TypeResolver.isInt(expression.t))
						conv = "toFloat";
				#end
				case _ :
			}
		}
		var isConverter = conv.length > 0;

		function addReturn() {
			sb.add("return ");
			if (promo != null) 
				promo.start();
			if (isConverter) {
				sb.add('${conv}(');
			} else {
				//sb.add("return ");
				if (needBrackets) sb.add("(");
			}
		}

		function addClose() {
			if (isConverter || needBrackets) {
				sb.add('${convTo})');
			}
		}

		if (expression == null || expression.expr == null) {
			sb.add("return");
		} else {
			final ovd = pushVoid(isVoidReturn);
			switch (expression.expr) {
				case TReturn(e):
					generateTReturn(sb, e, promo);
				case TThrow(e):
					generateTThrow(sb, e);
				case v:
					addReturn();
					generateSingleExpression(sb, expression, false);
					addClose();
					//throw 'Unsupported ${v}';
			}
			if (promo != null)
				promo.promote(expression);
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
			case OpAssign | OpAssignOp(_):
				switch e1.expr {
					case TLocal(v) : scopes.shadowParamVar(v);
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
		generateSingleExpression(sb, e1, false);
		switch typMix {
			case IntFloat | SecondString: if ( !op.match(OpAssign) && !op.match(OpAssignOp(_))) sb.add(")");
			case FirstUInt: sb.add(".uint32");
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
			#if (false) // handled by TypePromotion
			case FloatInt: sb.add("toFloat(");
			#end
			case FirstString: sb.add("$(");
			//case IntFloat if (op.match(OpAssign) || op.match(OpAssignOp(_))): 
			case _:
		}
		final promo = new TypePromotion(this, sb, e1.t);
		promo.start();
		generateSingleExpression(sb, e2, false);
		#if (false) // handled in generateSingleExpression
		switch e2.expr {
			case null:
			case TBlock(el):
				generateTBlock(sb, el, false);
			case TTypeExpr(TClassDecl(c)) if (op.match(OpEq) || op.match(OpNotEq)):
				final ct = c.get();
				ObjectType.use(ct);
				final cInfo = TypeContext.getClassByName(ct);
				if (cInfo != null) sb.add(cInfo.basicName + "StaticInst.qtype");
				else generateSingleExpression(sb, e2, false);
			case _:
				generateSingleExpression(sb, e2, false);
		}
		#end
		promo.promote(e2);
		switch typMix {
			case /*FloatInt | */ FirstString: sb.add(")");
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
					scopes.shadowParamVar(v);
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
				generateSingleExpression(sb, expr, false);
			case OpNeg:
				sb.add("- ");
				generateSingleExpression(sb, expr, false);
			case OpNegBits:
				sb.add("~ ");
				generateSingleExpression(sb, expr, false);
			case OpSpread:
				throw 'Unsupported';
		}
	}

	/**
	 * Generate code for static field referrence
	 */
	function generateTFieldFStatic(sb:IndentStringBuilder, classType:ClassType, classField:ClassField) {
		ObjectType.use(classType);
		var fieldData = getStaticTFieldData(classType, classField);
		switch TypeTools.followWithAbstracts(classField.type) {
			case TFun(_, _):
				//sb.add(TypeResolver.resolve(classField.type));
				//sb.add("= ");
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
			case TAnonymous(a):
				trace(a);
			case v:
				throw 'Unsupported ${v}';
		}

		sb.add(fieldData.totalName);
	}

	/**
	 * Generate code for instance field referrence
	 */
	function generateTFieldFInstance(sb:IndentStringBuilder, classType:ClassType, params:Array<Type>, classField:ClassField) {
		ObjectType.use(classType);
		var fieldData = getInstanceTFieldData(classType, params, classField);

		sb.add(".");
		sb.add(fieldData.fieldName);
	}

	/**
	 * Generate code for anon field call
	 */
	function generateTCallTFieldFAnon(sb:IndentStringBuilder, classField:ClassField) {
		var fieldName = classField.name;
		sb.add('{"${fieldName}"}');
	}

	/**
	 * Generate code for static field call
	 */
	function generateTCallTFieldFStatic(sb:IndentStringBuilder, classType:ClassType, classField:ClassField) {
		ObjectType.use(classType);
		var fieldData = getStaticTFieldData(classType, classField);
		sb.add(fieldData.totalName);
	}

	/**
	 * Generate code for instance field call
	 */
	function generateTCallTFieldFInstance(sb:IndentStringBuilder, classType:ClassType, params:Array<Type>, classField:ClassField) {
		ObjectType.use(classType);
		var fieldData = getInstanceTFieldData(classType, params, classField);

		sb.add(".");
		sb.add(fieldData.fieldName);
	}

	/**
	 * Generate code for calling base class field
	 */
	function generateSuperCall(sb:IndentStringBuilder, classType:ClassType, classField:ClassField) {
		ObjectType.use(classType);
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
				generateSingleExpression(sb, e);
				sb.add(")");
			case TIdent(s):
				//trace('skip ident $s for now'); //TODO fix it
				sb.add(s);
			case v:
				generateSingleExpression(sb, expression, false);
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
					final name = NimNames.fixed(e.get().name);
					final fname = NimNames.fixed(ef.name);
					sb.add('new${name}${fname}()');
				case FAnon(cf):
					var name = cf.get().name;
					sb.add('{"${name}"}');
				case FDynamic(s):
					sb.add('{"${s}"}');
				case FClosure(c, cf):
					final ccf = cf.get();
					final fname = NimNames.fixed(ccf.name);
					sb.add('.${fname}');
					if (c != null) {
						final ct = c.c.get();
					}
					trace('closure');
				case v:
					throw 'Unsupported ${v}';
			}
		}

		switch (expression.expr) {
			case TTypeExpr(_):
				genAccess();
			case TConst(c) if (false):
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
			case TField(e, fa) if (false):
				generateTField(sb, e, fa);
				genAccess();
			case TCast(e, m) if (false):
				generateTCast(sb, expression, e, m);
				genAccess();
			case TParenthesis(e) if (false):
				sb.add("(");
				generateSingleExpression(sb, e);
				sb.add(")");
				genAccess();				
			case v:
				//throw 'Unsupported ${v}';
				generateSingleExpression(sb, expression, false);
				genAccess();
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
		var isOfTypeCall = false;
		var isAsync = false;
		var needExtraBracket = false;
		final needDiscard = needVoid && ! expression.t.isVoid();
		if (needDiscard) 
			sb.add("discard ");
		switch (expression.expr) {
			case TField(_, FEnum(c, ef)):
				final name = NimNames.fixed(c.get().name);
				final fname = NimNames.fixed(ef.name);
				sb.add('new${name}${fname}');
				sb.add("(");
			case TField(e, fa):
				switch (e.expr) {
					case TLocal(v) if (expressions.length == 0 && fa.match(FAnon(_)) && TypeResolver.isIterator(v.t)):
						generateTLocal(sb, v);
						switch fa {
							case FAnon(cf):
								final c = cf.get();
								if (c.name == "hasNext" || c.name == "next") {
									sb.add('.${c.name}()');
									return;
								}
							default:
						}
					case TTypeExpr(TClassDecl(c)):
						final ct = c.get();
						ObjectType.use(ct);
						switch ct.name {
							case "Log":
								isTraceCall = true;
							case "Async_Impl_":
								isAsync = true;
							case "nimsys" if (fa.match(FStatic(_, _.get().name => "isOfType"))):
								isOfTypeCall = true;
						}
					case _:
				}

				if (!isAsync) {
					needExtraBracket = generateTCallTField(sb, e, fa);
					if (e.t.isDynamic()) sb.add(".call");
					sb.add("(");
				}
			case TConst(TSuper):
				if (classContext.classType.superClass != null) {
					final superCls = classContext.classType.superClass.t.get();
					final ci: ClassInfo = cast ObjectType.get(superCls);
					if (ci == null || ! (ci is ClassInfo) || ! ci.isPure) {
						final superName = TypeResolver.resolveClassType(superCls, [for (p in superCls.params) p.t]);
						//var superName = superCls.name;
						sb.add('init${superName}(this');
						if (expressions.length > 0) {
							sb.add(", ");
						}
					} else {
						sb.add("(false");
					}
				}
			case TLocal(v):
				generateTLocal(sb, v);
				if (v.t.isDynamic()) sb.add(".call");
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

		final ovd = pushVoid(false);
		for (i in 0...expressions.length) {
			var wasConverter = false;
			var expr = expressions[i];
			var farg = if (funArgs != null) {
				funArgs[i];
			} else null;

			//var extraConversion = null;
			var promo = null;
			if (farg != null) {
				final tt = TypeResolver.resolve(farg.t);
				final ft = TypeResolver.resolve(expr.t);
				if (ft != tt) {
					promo = new TypePromotion(this, sb, farg.t);
					switch farg.t {
						case TInst(t, _):
							var tp = t.get();
							if (tp.isInterface) {
								sb.add('to${tp.name}(');
								wasConverter = true;
							}
							//if (ft == "Dynamic" && tt != "ClassAbstr[Dynamic]" && tt != "EnumAbstr[Dynamic]") {
							//	extraConversion = '.fromDynamic(${tt})';
							//}
						case TAnonymous(a), TType(_.get().type => TAnonymous(a), _):
							if (tt != "Dynamic") {
								//trace('from $ft to $tt');
								sb.add('to${tt}(');
								wasConverter = true;
							}
						case TDynamic(_) | TType(_, _):
							if (! isTraceCall && ! isOfTypeCall) {
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
							#if (false) // handled by TypePromotion
							switch [ft, tt] {
								case ["int32", "float"] | ["Null[int32]", "float"] :
									sb.add("toFloat(");
									wasConverter = true;
								default:
							}
							#end
					}
				}
			}
			if (promo != null) promo.start();
			switch (expr.expr) {
				case TObjectDecl(e) if (isTraceCall):
					generateTObjectDeclTrace(sb, e);
				case TTypeExpr(TClassDecl(c)):
					final ct = c.get();
					ObjectType.use(ct);
					final s = if (isOfTypeCall) 
							TypeResolver.resolveClassType(ct, []) + 'StaticInst.qtype' 
						else TypeResolver.resolveClassType(ct, [for (p in ct.params) p.t]);
					sb.add(s);
				case _:
					generateSingleExpression(sb, expr, false);
			}
			if (promo != null) promo.promote(expr);
			if (wasConverter)
				sb.add(")");
			//if (extraConversion != null)
			//	sb.add(extraConversion);
			if (i + 1 < expressions.length)
				sb.add(", ");
		}
		popVoid(ovd);
		if (!isAsync)
			sb.add(")");
		if (needExtraBracket)
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
	function generateTIf(sb:IndentStringBuilder, econd:TypedExpr, eif:TypedExpr, eelse:TypedExpr, promo: TypePromotion) {
		//final ovd = pushVoid(isVoid(promo.left));
		final ovd = pushVoid(false);
		if (! ovd) sb.add("(");
		sb.add("if ");
		var promIf = new TypePromotion(this, sb, BOOL);
		promIf.start();
		generateSingleExpression(sb, econd, false);
		promIf.promote(econd);
		popVoid(ovd);
		sb.add(":");
		sb.addNewLine(Inc);
		promo.start();
		generateSingleExpression(sb, eif, true);
		promo.promote(eif);
		if (eelse != null) {
			promo = promo.copy();
			switch eif.expr {
				case TConst(TString(_)): sb.add(".toXString");
				default:
			}
			sb.addNewLine(Dec);
			sb.add("else:");
			sb.addNewLine(Inc);
			promo.start();
			generateSingleExpression(sb, eelse, true);
			promo.promote(eelse);
		}
		if (! ovd) sb.add(")");
		//popVoid(ovd);
		sb.addNewLine(Dec);
	}

	/**
	 * Generate code for TWhile
	 */
	function generateTWhile(sb:IndentStringBuilder, econd:TypedExpr, whileExpression:TypedExpr, isNormal:Bool) {
		sb.add("while ");
		final ovd = pushVoid(false);
		generateSingleExpression(sb, econd, false);
		popVoid(ovd);
		sb.add(":");
		sb.addNewLine(Inc);
		generateSingleExpression(sb, whileExpression, true);
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
		generateSingleExpression(sb, expr);
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
					generateSingleExpression(sb, e.expr);
					sb.addNewLine(Dec);	
			}
		}	
	}


	public function generateExpression(sb:IndentStringBuilder, expr:TypedExpr, consumeValue = true) {
		final ovd = pushVoid(! consumeValue);
		generateSingleExpression(sb, expr, false);
		popVoid(ovd);
	}

	/**
	 * Generate single expression from TBlock
	 */
	function generateSingleExpression(sb:IndentStringBuilder, expr:TypedExpr, newLine = true) {
		if (expr != null) {
			if (Std.string(expr.pos).indexOf(":110:") > 0 ) {
				trace("here <================================");
			}
			var isAsignment = false;
			var asignHook = -1;
			final ovd = needVoid;
			if (ovd && ! expr.t.isVoid() && newLine) {
				asignHook = sb.addHook();
				#if (false)
				sb.addCallback(indent -> {
					if (true) switch expr.expr {
						case TVar(v, expr): trace('${expr.pos} var of ' + TypeResolver.resolve(v.t) + ' $isAsignment');
						case TBinop(op, e1, e2): trace('${expr.pos} is Assign: $isAsignment  op: $op');
						case var v: if (isAsignment) trace('${expr.pos} $v');
					}
					if (isAsignment) 
						Str("");
					else 
						Data("discard ");
				});
				#end
				needVoid = false;
			}
			switch (expr.expr) {
				case TConst(c):
				// TODO: handle THIS
					generateTConst(sb, c, expr.t);
				case TVar(v, expr):
					isAsignment = true;
					generateTVar(sb, v, expr);
				case TCall(e, el):
					if (! newLine) 
						generateCommonTCall(sb, e, el);
					else
						generateBlockTCall(sb, e, el, false);
					//popVoid(ovd);
				case TReturn(e):
					isAsignment = true;
					final promo = new TypePromotion(this, sb, returnType);
					generateTReturn(sb, e, promo);
				case TBinop(op, e1, e2):
					isAsignment = op.match(OpAssign) || op.match(OpAssignOp(_));
					var obl = -1;
					if (isAsignment && ! ovd) {
						obl = binOpLevel;
						binOpLevel = 0;
						sb.add("(");
					}
					generateTBinop(sb, op, e1, e2);
					if (obl >= 0) {
						final sbl = new IndentStringBuilder();
						generateSingleExpression(sbl, e1, false);
						sb.add('; ${sbl})');
						binOpLevel = obl;
					}
				case TBlock(el):
					isAsignment = true;
					needVoid = ovd;
					if (newLine) 
						generateTBlock(sb, el, true);
					else generateTBlockInline(sb, el);
				case TIf(econd, eif, eelse):
					isAsignment = true;
					needVoid = ovd;
					final promo = new TypePromotion(this, sb, expr.t);
					generateTIf(sb, econd, eif, eelse, promo);
				case TWhile(econd, e, normalWhile):
					generateTWhile(sb, econd, e, normalWhile);
				case TMeta(m, e1):
					//generateTMeta(sb, m, e1);
					generateSingleExpression(sb, e1, newLine);
				case TUnop(op, postFix, e):
					generateTUnop(sb, op, postFix, e);
				case TSwitch(e, cases, edef):
					isAsignment = true;
					needVoid = ovd;
					final promo = new TypePromotion(this, sb, expr.t);
					generateTSwitch(sb, e, cases, edef, promo);
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
					final h = expr.t.isDynamic() ? -1 : sb.addHook();
					final dynAccess = generateTArray(sb, e1, e2);
					if (dynAccess && h >= 0) {
						sb.resolveHook(h, Data("fromDynamic("));
						final stype = TypeResolver.resolve(expr.t);
						sb.add(', ${stype})');
					}
				case TArrayDecl(el):
					generateTArrayDecl(sb, el, expr);
				case TParenthesis(e):
					sb.add("(");
					generateSingleExpression(sb, e, newLine);
					sb.add(")");
				case TNew(c, params, el):
					generateTNew(sb, c.get(), params, el);
				case TEnumParameter(e1, ef, index):
					if (!generateCustomEnumParameterCall(sb, e1, ef, index))
						generateTEnumParameter(sb, e1, ef, index);		
				case TObjectDecl(fields):
					generateTObjectDecl(sb, fields);		
				case TTypeExpr(TAbstract(a)):
					var at = a.get();
					switch at.name {
						case "Class":
							sb.add("TClass");
						case "Enum":
							sb.add("TEnum");
						default:
							final s = TypeResolver.resolve(at.type);
							sb.add(s);
					}
				case TContinue:
					isAsignment = true;
					sb.add("continue");
					//sb.addNewLine(Same);
				case TBreak:
					isAsignment = true;
					sb.add("break");
					//sb.addNewLine(Same);	
				case TThrow(e):
					isAsignment = true;
					generateTThrow(sb, e);				
				case TTypeExpr(TClassDecl(c)):
					final ct = c.get();
					ObjectType.use(ct);
					//final s = TypeResolver.resolveClassType(ct, [for (p in ct.params) p.t]);
					final s = TypeResolver.resolveClassType(ct, []);
					//sb.add('${s}StaticInst.qtype');
					sb.add(s);
				case TTypeExpr(TEnumDecl(c)):
					final ct = c.get();
					final s = NimNames.fixed(ct.name);
					//sb.add('${s}EnumInfo.qtype');
					sb.add(s);
				case v:
					throw 'Unsupported ${v}';
			}
			if (asignHook >= 0 && ! isAsignment) {
				sb.resolveHook(asignHook, Data("discard "));
			}
			popVoid(ovd);
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
				#if (false)
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
						}
					case _:
				}
				#end

				final ovd = isLast ? pushVoid(needVoid) : pushVoid(true);
				//if (! isAsignment && (needVoid && ! isVoid(expr.t))) sb.add("discard ");
				generateSingleExpression(sb, expr, true);
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
								generateSingleExpression(sb, expr);
								sb.add(")");
							case _:
								generateSingleExpression(sb, expr);
						}
					}
				} else {
					generateSingleExpression(sb, expr);
				}
			}
		} else {
			sb.add("discard");
		}
	}
	#end


	/**
	 * Generate inline block like. Relevant?
	 * (block:
	 * 		expressions
	 * )
	 */
	function generateTBlockInline(sb:IndentStringBuilder, expressions:Array<TypedExpr>) {
		sb.add("(block:");
		sb.addNewLine(Inc);
		for (i => expr in expressions) {
			final isLast = i == expressions.length - 1;
			final ovd = isLast ? pushVoid(needVoid) : pushVoid(true);
			generateSingleExpression(sb, expr, false);
			popVoid(ovd);
			sb.addNewLine(Same);
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
		final ovd = pushVoid(returnType == null || returnType.isVoid());
		switch (methodExpression.expr) {
			case TFunction(tfunc): 
				//trace(TypeResolver.resolve(tfunc.t) + " and return type " + (returnType == null ? "null" : TypeResolver.resolve(returnType)));
				generateSingleExpression(sb, tfunc.expr, true);
			case v:
				throw 'Unsupported paramter ${v}';
		}
		popVoid(ovd);
	}
}

private class TypePromotion {

	//TODO: FooWrapper(a: addr b.a, foo: proc(v:int32) = b.foo(v), qinstance: b)
	final generator: MethodExpressionGenerator;
	final sb: IndentStringBuilder;
	public final left: Type;
	public final parent: TypedExpr;
	var leftHook: Int = -1;
	var checkDiscard = false;
	var useIndent = false;


	public function new(generator: MethodExpressionGenerator, sb: IndentStringBuilder, left: Type, ? parent: TypedExpr) {
		this.generator = generator;
		this.sb = sb;
		this.left = left;
		this.parent = parent;
	}

	public function start(? checkDiscard = false) {
		useIndent = switch sb.currentItem { case Line(_) | Indent(_): true; default: false; };
		leftHook = sb.addHook();
		this.checkDiscard = checkDiscard;
	}

	function _unhook(v) {
		if (leftHook >= 0)
			sb.resolveHook(leftHook, useIndent ? Data(v) : Str(v));
		leftHook = -1;
	}

	var out: String = "";
	function unhook(v: String) {
		if (checkDiscard) out = v;
		else _unhook(v);
	}

	public function discard(right: Type) {
		if (checkDiscard) {
			final tt = TypeResolver.resolve(left);
			if (tt == "void") {
				final ft = TypeResolver.resolve(right);
				_unhook(ft != tt ? 'discard $out' : out);
			} else {
				_unhook(out);
			}
			out = "";
			checkDiscard = false;
		}
	}

	public function copy(): TypePromotion {
		return new TypePromotion(generator, sb, left, parent);
	}
	public function promote(right: TypedExpr) {
		switch [left, right.expr] {
			case [TFun(args, ret), TField(_, FClosure(c, cf))]:
				unhook({
					final s = TypeResolver.resolve(left);
					'($s = ';
				});
				sb.add('(');
				sb.add(args.map(a -> a.name).join(", "));
				sb.add('))');
			default:
				var ft = TypeResolver.resolve(right.t);
				var tt = TypeResolver.resolve(left);
				if (ft != tt) {
					switch ft {
						case "Dynamic" if (tt != "ClassAbstr[Dynamic]" && tt != "EnumAbstr[Dynamic]" && tt != "void"):
							switch left {
								case TAnonymous(a):
									// TODO: check all cases ?
								default:
									unhook("fromDynamic(");
									sb.add(', $tt)');
							}
						case "int32" |"Null[int32]" if (tt == "float") :
							unhook("toFloat(");
							sb.add(")");
						default:
							switch right.t {
								case TFun(args, ret) if (tt == "Dynamic"): 
									unhook("newDynamic(proc(param: varargs[Dynamic]): Dynamic = ");
									sb.add('(');
									for (i => a in args) {
										if (i > 0) sb.add(",");
										final ptype = TypeResolver.resolve(a.t);
										sb.add('fromDynamic(param[$i], ${ptype})');
									}
									sb.add(')');
									if ( ! ret.isVoid()) sb.add(".toDynamic");
									sb.add(")");
								case TType(t, params):
									switch tt {
										case "ClassAbstr[HaxeObjectRef]":
											sb.add("StaticInst.qtype");
									}
								default:
							}
					}
				}
		}
	}
}
