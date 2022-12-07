import VExpr;
import VExpr.C.*;

@:access(VExpr)
class Main {

	macro static public function benchmark(test, start, done) {
		return macro {
            trace($start);
            var dt = haxe.Timer.stamp();
            $test;
            var dur = haxe.Timer.stamp() - dt;
            trace($done);
		}
	}

	static inline var cloop = 1000;
	static function main() {
		var a = VExprInt.Val(0);
		var b = VExprInt.Val(0);
		var c = VExprInt.Val(0);
		var i = VExprInt.Val(0);
		var x1 = Set_I(a, VExprInt.Val(10));
		trace(x1.code);
		x1.run();
		trace(a.value);
		var loop = ForLoop(Set_I(a, VExprInt.Val(0)),  
			LessI(a, VExprInt.Val(cloop)),
			Inc(a), [
				ForLoop(Set_I(b, VExprInt.Val(0)),  
					LessI(b, VExprInt.Val(cloop)),
					Inc(b), [
						ForLoop(Set_I(c, VExprInt.Val(0)),  
							LessI(c, VExprInt.Val(cloop)),
							Inc(c), [
								Inc(i)
							])
					]
				)
			]
		);
		benchmark(loop.run(), "for loop nested:", 'completed in $dur');
		trace(a.value);
		trace(b.value);
		trace(c.value);
		trace(i.value);
		i.value = 0;
		loop = ForLoop(Set_I(a, VExprInt.Val(0)),  
			LessI(a, VExprInt.Val(cloop * cloop * cloop)),
			Inc(a), [
					Inc(i)
			]
		);
		benchmark(loop.run(), "for loop:", 'completed in $dur');
		trace(a.value);
		trace(b.value);
		trace(c.value);
		trace(i.value);
	}
}
