package test;

typedef Foo = {var a: Int; function foo(v: Int): Void;};

class Bar {
    public inline function new() {}
	public var a: Int = 1;
    public inline function foo(v: Int) {
            a += v;
    }
}


class TestAnons {

    static var foo: Foo;
    static function main() {
        final b = new Bar();
        foo = b;
        trace(foo.a);
        foo.foo(3);
        trace(foo.a);
        trace(foo == b);
    }
}