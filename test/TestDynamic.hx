package test;



class A {
    var a: String;
    public inline function new(v: String) a= v;
}

class TestDynamic {
    

    static function main() {
        var d: Dynamic = null;
        var a = new A(if (Std.random(1) > 1) "" else "foo");
        trace(a);
        d = a;
        trace(d);
        a = d;
        trace(a);
    }
}