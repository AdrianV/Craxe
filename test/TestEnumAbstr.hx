package test;

import helper.bytes.FastArray;

enum abstract A(String) {
    var Ene;
    var Mene;
    var Muh;
}

enum FooBar {
    Foo(a: Array<Int>);
    Bar(b: Array<Int>);
}

enum B {
    bEne;
    bMuh;
    bMene;
}

abstract Test(FooBar) from FooBar to FooBar {
    public var data(get, never): Array<Int>;
    inline function get_data() {
        switch this {
            case Foo(a): return a;
            case Bar(b): return b;
        }
    }
}

typedef Record = {a: Int}

abstract Rec(Float) from Float to Float {
    public inline function new(v) this = v;
    
    public function decode(): Record {
        return {a: Std.int(this)};
    }
    public function getA() {
        return decode().a;
    }

    public static function fromDynamic(d: Dynamic): Rec {
        switch Type.typeof(d) {
            case TNull : return 0;
            case TInt : return (d : Int);
            case TFloat : return new Rec(d);
            case TObject : if ( Std.isOfType(d, String) ) return (d:String).length;
            default:
        }
        return 0;
    }

}

class TestEnumAbstr {
    static function blub(a:A) {
        trace(a);
        var r = new Rec(47.11);
        trace(r.getA());
    }

    static function foo(f: Test) {
        return f.data;
    }

    static function main() {
        var a: Null<Int> = null;
        trace(Ene);
        blub(Mene);
        final ar = new FastArray<Int>(10);
        //untyped ar.length = 10;
        for(x in 0 ... ar.length) ar[x] = x;
        trace(ar);
        var test: Test = Foo([1,2,3,4]);
        trace(foo(test));
        trace(bMuh);
        final all = Type.allEnums(B);
        trace(all);
    }
}