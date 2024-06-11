package test;

class Call {

    var cnt = 0;
    public function new() {}

    public function run(x: Int) {
        cnt += x;
        trace(cnt);
    }

    function next(): String {
        return switch cnt++ {
            case 0: "Zero";
            case 1: "One";
            case 2: "Two";
            case 3: "Three";
            case 4: "Four";
            case 5: "Five";
            case 6: "Six";
            case 7: "Seven";
            case 8: "Eight";
            case 9: "Nine";
            default: "boom";
        }
    }
    function hasNext() {
        return cnt >= 0 && cnt <= 9;
    }
    public function iterator() {
        return {hasNext: hasNext, next: next};
    }
}

typedef SomeCall = {
    run: Int->Float,
}

enum ECall {
    None;
    Call(call: Int-> Float);
}

class TestDynCalls {
    
    static function run(x: Int) {
        trace(x);
    }
    static function testDynPromotion() {
        var x: Int = (2: Dynamic);
        trace(x);
        x = (3:Dynamic) + 4;
        function foo(v): Int {
            return v + (5: Dynamic);
        }
        x = foo(x);
        trace(x);
        x = foo((3: Dynamic));
        trace(x);
        x = if (x == 8) (1: Dynamic)  else 2;
        if (x == 8) (1: Dynamic)  else 2;
        if (x == 1) {
            trace("here" + (x != 1 ? " wtf" : " as expected"));
            (1: Dynamic);
        }  else {
            var i = 1;
            while (x-- > 0) {
                trace(x);
                i * 2;
            }
            trace("there");
            2;
        };
        x = 1;
        var y = x = (++x: Dynamic);
        trace('x = $x y = $y');
        var sc: SomeCall = {run: foo};
        trace(sc.run(1));
        var e = Call(sc.run);
        switch e {
            case None: trace("None");
            case Call(call): trace('call ${call(42)}');
        }
        trace(e);
        var d: Dynamic;
        d = sc.run;
        x = d(43);
        //var x,y : Int = 5;
    }

    static function main() {
        var c = run;
        c(3);
        var o = new Call();
        var c = o.run;
        c(1);
        c = o.run;
        c(2);
        c(3);
        testDynPromotion();
        for (x in o) {
            trace(x);
        }
    }
}