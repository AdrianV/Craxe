typedef VRunner = Null<Void->Void>;

@:structInit
class VExprInfo {
	public var r: VRunner;
	public var flat: Bool = true;
}

class VExpr {

	var runner: VRunner;
	var next: VExpr;
	var code: VExpr;
	var runNext: VExpr;
	var info: VExprInfo;

	static public function make() return new VExpr();

	public function run() {
		if (runner != null) {
			var op = runNext;
			while (op != null) {
				op.runner();
				op = op.runNext;
			}
			runner();
		}
	}

	public function process() {
		var op = code;
		while (op != null) {
			op.run();
			op = op.next;
		}
	}

	public function compileRun(prog: Array<VRunner>) {
		if (runner != null) {
			var op = runNext;
			while (op != null) {
				if (op.runner != null) prog.push(op.runner);
				op = op.runNext;
			}
			prog.push(runner);
		}
	}

	public function compileProcess(prog: Array<VRunner>) {
		var op = code;
		while (op != null) {
			op.compileRun(prog);
			op = op.next;
		}
	}

	static function flatten(op: VExpr) {
		op.runNext = null;
		if (op.runner == null) return;
		var last = op;
		op = op.code;
		while (op != null) {
			if (op.runner != null) {
				final x = op;
				if ( op.info.flat ) {
					last.runNext = x;
					last = x.runNext != null ? x.runNext : x;
				}
			}
			op = op.next;
		}
	}

	public inline function new() {}

	public function create(info: VExprInfo, ? ops: Array<VExpr>): VExpr {
		this.runner = info.r;
		this.info = info;
		if (ops != null && ops.length > 0) {
			var p: VExpr = ops[0];
			code = p;
			for (x in 1 ... ops.length) {
				p.next = ops[x];
				p = p.next;
			} 
			if (p != null) p.next = null;
			if (info.flat) flatten(this);
		} else code = null;
		return this;
	}

}

class VExprLoop extends VExpr {
	public function forLoop() {
		this.code.run();
		final test = (cast this.code.next: VExprBool);
		final next = test.next;
		final loop = next.next;
		test.run();
		while (test.value) {
			inline loop.process();
			inline next.run();
			inline test.run();
		}
	}
}

class VExprInt extends  VExpr {
	public var value: Int;
	static public function make() return new VExprInt();
	static public function Val(v: Int): VExprInt {
		var res = new VExprInt();
		res.value = v;
		return res;
	}

	public function valOf() {
		this.value = (cast this.code: VExprIntVar).value.value;
	}
}


class VExprIntVar extends  VExpr {
	public var value: VExprInt;
	static public function make() return new VExprIntVar();
	static public function Val(v: VExprInt): VExprIntVar {
		var res = new VExprIntVar();
		res.value = v;
		return res;
	}

	public function inc1() {
		this.value.value++;
	}

	public function incX() {
		this.value.value += (cast this.code: VExprInt).value;
	}

	public function set() {
		this.value.value = (cast this.code: VExprInt).value;
	}
}

class VExprFloat extends VExpr {
	public var value: Float;
	static public function make() return new VExprFloat();
}

class VExprBool extends VExpr {
	public var value: Bool;
	static public function make() return new VExprBool();

	public function lessII() {
		this.value = (cast this.code: VExprInt).value < (cast this.code.next: VExprInt).value;
	}
}

class C {

	static var EMPTY: VExprInfo = {r: null};

	static public function Block(block: Array<VExpr>): VExpr {
		return new VExpr().create(EMPTY, block);
	}

	static public function ForLoop(init: VExpr, test: VExprBool, next: VExpr, block: Array<VExpr>): VExpr {
		final op = new VExprLoop();
		return op.create({r: op.forLoop, flat: false}, [init, test, next, Block(block)]);
	}

	static public function Set_I(a: VExprInt, v: VExprInt): VExpr {
		final op = VExprIntVar.Val(a);
		return op.create({r: op.set}, [v]);
	}

	static public function Inc(a: VExprInt): VExpr {
		final op = VExprIntVar.Val(a);
		return op.create({r: op.inc1}, []);
	}

	static public function IncX(a: VExprInt, v: VExprInt): VExpr {
		final op = VExprIntVar.Val(a);
		return op.create({r: op.incX}, [v]);
	}

	static public function LessI(a: VExprInt, b: VExprInt): VExprBool {
		final op = new VExprBool();
		op.create({r: op.lessII}, [a,b]);
		return op;
	}

	static public function ValOf(x: VExprIntVar): VExprInt {
		final op = new VExprInt();
		op.create({r: op.valOf}, [x]);
		return op;
	}

}
