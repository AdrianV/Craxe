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

typedef SomeAnon = {a: Int, b: String};

class Main {



    static function call() {
        trace('ok');
    }

    static function getSomeAnon(v: SomeAnon) {
        
    }

    static function getAnAnon(v: {a: Int, b: String}) {
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
    
    static function testAnon() {
        var v = {a: 3, b: "hallo"};
        getAnAnon(v);
        trace(v);
        var v2 = {a: 4, b: "welt", c: 3.1415};
        getAnAnon(v2);
        trace(v2);
        getSomeAnon(v);
        getSomeAnon(v2);
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
    }

    static function testNullT() {
        var a: Null<Int> = null;
        trace(a);
        a = 32;
        trace(a);    
    } 

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
    }
}