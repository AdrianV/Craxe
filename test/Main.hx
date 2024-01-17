package test;

import haxe.io.Bytes;

typedef Callback = Void->Void;

class Tool {

    static public inline function assert(cond: Bool, msg = "") {
        if ( ! cond) {
            trace('ERROR $msg ==================');
        }
    }
}

class Ugly {
    public var _data: Int;

    public inline function new(data) {
        _data = data;        
    }
}

enum EnumTest {
    Some(value: String);
    Other(value: String);
}

class EnumTestX {

    var _x: EnumTest;

    public var x(get, never): String;


    inline function get_x() return switch _x {
        case Some(value): value;
        case Other(value): value;
    }
        
    public function new(v) {     
        _x = v;
    }
}

class Complex {

    public var i:Float;
    public var j:Float;
    
    public function new(inI:Float, inJ:Float)
    {
       i = inI;
       j = inJ;
    }
 
    public static inline function Length2(val:Complex) : Float
    {
        return val.i*val.i + val.j*val.j;
    }
     
    public inline static function Add(val0:Complex, val1:Complex)
    {
        return create( val0.i + val1.i, val0.j + val1.j );
    }
     
    public inline static function Square(val:Complex)
    {
        return create(  val.i*val.i - val.j*val.j, 2.0 * val.i * val.j );
    }
          
    inline public static function create(inI:Float, inJ:Float) return new Complex(inI, inJ);

}

abstract Nonsense(Int) {
    static public var mem = [];

    static public function keep(l: RecursiveNew) mem.push(l);
}

class RecursiveNew {
    
    var left: RecursiveNew;
    var right: RecursiveNew;
    public final v: Float;

    public function new(n: Int, l: RecursiveNew = null, r: RecursiveNew = null) {
        if (n > 1) {
            left = if (l == null) new RecursiveNew(n - 1) else l;
            right = if (r == null) new RecursiveNew(n - 2) else r;
        }
        v = n;
        Nonsense.keep(this);
    }
}

class SomeGeneric<T> {
    final data: T;

    public function new(data: T) {
        this.data = data;
    }
}

typedef SomeAnon = {a: Int, b: String};


class FooBar extends test.a.Foo {
    override public function bar() {
        super.bar();
        trace('and a FooBar');
    }
}

class Main {

    static function testGeneric() {
        var x = new SomeGeneric("Hi Nim");
        trace(x);    
    }

    static function testAandB() {
        var a = new test.a.Foo();
        a.bar();
        a = new FooBar();
        a.bar();
        var b = new test.b.Foo();
        b.bar();    
    }

    static function testAnon() {
        var v = {a: 3, b: "hallo"};
        getAnAnon(v);
        trace(v);
        var v2 = {a: 4, b: "welt", c: 3.1415};
        getAnAnon(v2);
        trace(v2);
        getOtherAnon(v2);
        getOtherAnon({c: 1.3});
        var dyn: Dynamic = {};
        dyn.c = 47.11;
        getOtherAnon(dyn);
        trace(dyn);
        dyn.c = "foo";
        try {
            getOtherAnon(dyn);
            trace("ERROR we should never reach here");
        } catch (e) {
            trace(e);
        }
    }


    static function call() {
        trace('ok');
    }

    static function getOtherAnon(v: {c: Float}) {
        trace(v);
        v.c = 2.7;
    }

    static function getAnAnon(v: {a: Int, b: String}) {
        trace('getAnAnon ---------------------------');
        trace('a = ${v.a} b = ${v.b}');    
        var factor: Int = 2;
        var x = v.a * factor;
        trace(x);
        x = factor * v.a;
        trace(x);
        var factor: Float = 2.3;
        var x = v.a * factor;
        trace(x);
        x = factor * v.a;
        trace(x);
        v.a = 2;
    }
    
    static function testStringArray() {
        var arr: Array<String> = new Array();
        arr.push("foo");
        trace(arr);
    }

    static function testRecursiveNew() {
        var node = new RecursiveNew(3);    
        trace(node.v);
    }

    static function testDiscard() {
        var a = [1,2,3];
        if (a.length == 3)  
            a.push(4);  
        var b = if (a.length == 4) a.push(5) else 0;
        trace(b);
        a.push(6);
    }

    static function testComplex() {
        final MaxIterations = 1000;
        final MaxRad = 1<<16;
        var offset = Complex.create(-2.5, - 1);
        var val = Complex.create(0.0,0.0);
        var iteration = 0;
        while( Complex.Length2(val)< MaxRad && iteration < MaxIterations)
        {
            val = Complex.Add( Complex.Square(val), offset );
            iteration++;
        }
        trace(val.i);
        function fooBar(v: {i: Float, j: Float}) {
            var foo: {i: Float, j: Float} = v;
            trace(foo);
        }
        fooBar({i: 2.0, j: 3.1});
        //fooBar(val);
    }

    static function testNullT() {
        var a: Null<Int> = null;
        trace(a);
        a = 32;
        trace(a);    
    } 

    #if (true)
    static function testMap() {
        var m = new haxe.ds.StringMap(); // new Map();
        m.set('foo', 'bar');
        m.set('bar', 'foo');
        trace(m.get('foo'));
        var m2 = m.copy();
        //$type(m2);
        m.clear();
        trace(m.exists('foo'));
        trace(m2.exists('bar'));
        trace(m2);
        for (v in m2) trace(v);
        for (k in m2.keys()) trace(k);
        for (k => v in m2) trace('$k => $v');
    }
    #end

    static function testEnumExpr() {
        var e = Some("23");
        trace((switch e {
            case Some(value): value;
            case Other(value): value;
        }).length);        
        var x = new EnumTestX(e);
        trace(x.x.length);
    }

    static function testUgly() {
        final ug = new Ugly(12);
        trace(ug._data);
    }

    static function testClosure() {
        var i = 0;
        var cb: Callback = call; // works because is not a closure
        cb();    
        cb = () -> trace(++i);
        cb();   
        Tool.assert(i == 1, "foo");     
    }

    static function testSys() {
        Sys.println('Hallo Welt');
        trace(Sys.args());
        Sys.println(Sys.getEnv('PATH'));
    }

    static function main() {
        testClosure();
        testUgly();
        testEnumExpr();
        testComplex();
        testNullT();
        trace(Sys.cpuTime());
        trace(Math.abs(-1));
        testStringArray();
        testAnon();
        testAandB();
        testGeneric();
        testSys();
        testMap();
    }
}