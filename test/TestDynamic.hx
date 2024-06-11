package test;

import haxe.Unserializer;
import haxe.Serializer;



class A {
    var a: String;
    public inline function new(v: String) a= v;
}

class TestDynamic {
    

    static function foo(s: String) {
        trace(s);
    }

    static function main() {
        var d: Dynamic = null;
        if (d) trace(d);
        var ad = [1, 2, 3];
        d = ad;
        function testD() {
            trace('testD !');
            if (d is Array ) {
                trace('d[1] = ${d[1]}, length: ${d.length}');
            } else {
                trace('$d is not an array');
            }
        }
        trace("-------------------------------------------");
        testD();
        trace("-------------------------------------------");
        var ad = ["eins", "zwei", "drei"];
        d = ad;
        trace("-------------------------------------------");
        testD();
        trace("-------------------------------------------");
        d = "Hallo Nim";
        foo(d);
        var a = new A(if (Std.random(1) > 1) "" else "foo");
        trace(a);
        d = a;
        trace(d);
        a = d;
        trace(a);
        var ar = [{a: 32, b: 3.14, c: "Hallo"}, {a: 23, b: 2.7, c: "Welt"}];
        trace(ar[0]);
        trace(ar);
        var s = Serializer.run(ar);
        trace(s);
        d = Unserializer.run(s);
        //d = ar;
        trace(d);
        ar = d;
        trace(ar);
        var dt = new Date(2024, 1, 13, 0, 0, 0);
        trace(dt.toString());
    }
}