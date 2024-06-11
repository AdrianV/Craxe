package test;

enum T {
    Foo(a: T, b: Int);
    Bar(b: T);
    Stop;
}

enum E {
    Muh;
    Ene(a: Int, b: String);
    Mene;
}

class A {
    static var static_a = -1;
    public var a = 1;
}

class B extends A {
    static var static_b = "static B";
    var b = "Bee";
    public function new(a, b) {
        this.a = a;
        this.b = b;
    }
}

class TestTypeAndReflect {

    static function main() {
        //var c = ; //Type.resolveClass("String");
        switch Type.typeof("") {
            case TClass(c):
                if (c == String) trace("c is a String");
                else trace("oops");
            case var c:
                trace('oops $c');
        }
        var eall = Type.allEnums(E);
        trace(eall);
        var a = Type.createEmptyInstance(A);
        trace(a.a);
        final e = Type.createEnum(E, "Ene", [1, "zwei"]);
        trace(e);
        final m = Type.createEnumIndex(E, 0);
        trace(m);
        var a = Type.createInstance(A, []);
        trace(a.a);
        trace(Type.enumConstructor(m));
        final cp = Type.enumParameters(e);
        trace(cp);
        final at = Type.getClass(a);
        var a3 = Type.createInstance(at, []);
        trace(a3);
        var b = Type.createInstance(B, []);
        if (b != null)  trace(b);
        b = Type.createInstance(B, [4, "Vier"]);
        trace(b);
        var sf = Type.getClassFields(B);
        trace(sf);
        sf = Type.getInstanceFields(B);
        trace(sf);
        final a = Foo(Bar(Foo(Stop, 2)), 1);
        final b = Foo(Bar(Foo(Stop, 2)), 1);
        trace(Type.enumEq(a, b));
        final bc = Type.resolveClass("test.B");
        if (bc != null) {
            final p = Type.getSuperClass(bc);
            if (p != null) trace(Type.getInstanceFields(p));
        } else trace('class not found');
    
    }

}