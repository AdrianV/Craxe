package test;

import haxe.io.Encoding;

@:forward
enum abstract WeekDays(Int) from Int to Int {
    var Mon = 0;
    var Tue = 1;
    var Wed = 2;
    var Thu = 3;
    var Fri = 4;
    var Sat = 5;
    var Sun = 6;
    inline public function isWeekend(): Bool return this == Sat || this == Sun;
    @:op(A - B) static function sub1(lhs:Int, rhs:WeekDays):Int;
    @:op(A + B) static function add1(lhs:Int, rhs:WeekDays):Int;
    @:op(A < B) static function less(lhs:WeekDays, rhs:WeekDays):Bool;
    @:op(A <= B) static function leq(lhs:WeekDays, rhs:WeekDays):Bool;
    @:op(A == B) static function eq(lhs:WeekDays, rhs:WeekDays):Bool;
    @:op(A => B) static function qeq(lhs:WeekDays, rhs:WeekDays):Bool;
    @:op(A > B) static function greater(lhs:WeekDays, rhs:WeekDays):Bool;
    @:op(A != B) static function neq(lhs:WeekDays, rhs:WeekDays):Bool;
}

class TestStaticProcs {

    static function fuzz(encoding: Encoding) {
      trace(encoding);
    }

    static function bar(a: Float) {
      var minDays = 5;
      var weekDay: WeekDays = Sun;
      var day4: Float = ((a - weekDay) + 8) - minDays;
      trace(day4);      
    }

    static function foo() {
        trace("foo");
        function bar(v: {c: Float, a: String}, d: Float) {
          d = 2 * v.c + d;
          trace('${v.a} ${v.c}');
        }
      	bar({a: "Hallo", c:0.007}, 0.01);
    }

    static function main() {
      bar(35678.5);
      var call = foo;
      call();
      call();
      fuzz(RawNative);
    }
}