class FibNode {
  var n1: FibNode;
  var n2: FibNode;
  public var v(default, null): Float;
  
  public function new(n: Int, ? f1: FibNode, ? f2: FibNode) {
    if (n < 2) {
      v = n;
    } else {
      n1 = f1 != null ? f1 : new FibNode(n - 1);
      n2 = f2 != null ? f2 : new FibNode(n - 2);
      v = n1.v + n2.v;
    }
  }
  
  public function count(): Float {
    if (n1 != null && n2 != null) return 1.0 + n1.count() + n2.count();
    if (n1 != null) return 1.0 + n1.count();
    return 1.0;
  }
  
  public function recalc(): Float {
    return (n1 != null && n2 != null) ?
      n1.recalc() + n2.recalc()
      : v;
  }
}

abstract Fib(FibNode) from FibNode to FibNode {
  static var mem = new Array<FibNode>();
  
  public function new(n: Int) {
  	this = mem[n];
    if (this == null) {
      this = n >= 2 ? new FibNode(n, new Fib(n-1), new Fib(n-2)) : new FibNode(n);
      mem[n] = this;
    }
  }
  
  public var v(get, never): Float;
  inline function get_v() return this.v;
  
  public inline function count() return this.count();
  public inline function recalc() return this.recalc();

  public static function cleanup() {
	  mem = [];
  }
  
}

class Tree {

	static function main1() {
		final minDepth = 24;
		final n = 28;
		final maxDepth = minDepth + 2 > n ? minDepth + 2 : n;
		final stretchDepth = maxDepth + 1;

		var check = new FibNode(stretchDepth).count();
		trace('stretch tree of depth $stretchDepth \t check: $check');

		final longLivedTree = new FibNode(maxDepth);

		var depth = minDepth;
		while (depth <= maxDepth) {
			final iterations = Std.int(new Fib(maxDepth + 8 - depth).v);
			check = 0.0;
			for (i in 1 ... iterations + 1)
				check += new FibNode(depth).count();

			trace('${iterations*2} \t trees of depth  $depth \t check: $check');
			depth += 2;
		}
		trace('long lived tree of depth $maxDepth \t check: ${longLivedTree.count()}');
	}

  static function main() {
    trace("--- build and keep a big tree ----");
	  final n2 = 35;
    var f2 = new FibNode(n2);
    trace('fib($n2) = ${f2.v}\tnodes:${f2.count()}');      

	  trace("--- build memoized trees ----");
    for (n in 0...40) {
      var f = new Fib(n);
      trace('fib($n) = ${f.v}');      
    }

	  trace("--- recalc the existing tree ---");
    trace('fib($n2) = ${f2.recalc()}\tnodes:${f2.count()}');  

	  trace("--- release the existing tree ---");
    f2 = null;

    trace("--- build some trees ---");
    var count = 1;
    for (i in 0...6) {
      final n = n2 - i * 5;
      final data = [];
      trace('build ${count} trees for fib($n)');
      for (k in 1 ... count + 1) {
        data[k] = new FibNode(n);
      }
      count = 10 * count;
    }    

    trace("--- clean up the memoized trees ---");
    Fib.cleanup();

  	trace("--- build memoized trees again ----");
    for (n in 0...45) {
      var f = new Fib(n);
      trace('fib($n) = ${f.v}');      
    }
  }

}