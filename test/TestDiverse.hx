package test;

import haxe.io.Bytes;
import haxe.io.BytesData;
using StringTools;

typedef VRunner = Null<Void->Void>;

class A {
    public function new() {
        
    }
}

class B extends A {
    public function new() {
        super();
    }
}

abstract Word16(Int) from Int to Int from Int to Int {

	public inline function new(lo: Int, hi: Int) this = ((hi & 0xFF) << 8) | (lo & 0xFF);
	public var lo(get, set): Int;
	public var hi(get, set): Int;
	
	inline function get_lo(): Int return this & 0xFF;
	inline function set_lo(v: Int) {
		this = (this & 0xFF00) | (v & 0xFF);
		return v;
	}
	
	inline function get_hi(): Int return (this >> 8) & 0xFF;
	inline function set_hi(v) {
		this = ((v & 0xFF) << 8 ) | (this & 0xFF);
		return v;
	}
	static public inline function setI16(b: Bytes, pos: Int, v: Word16) {
		#if neko
		v = v & 0xFFFF;
		#end
		b.set(pos, v);
		b.set(pos +1, v >> 8);
	}
	static public inline function getI16(b: Bytes, pos: Int): Word16 return b.get(pos) | (b.get(pos + 1) << 8);
	static public inline function fastGetI16(b: BytesData, pos: Int): Word16 return b.fastGet(pos) | (b.fastGet(pos + 1) << 8);
}

class TestDiverse {

    static inline var hash_size = 16384;

    #if (false)
    static function term(b: Bytes) {
        var foo = 0;
        var hash = 0;
        var bitbuffer = 0;
        var codelen = 9;
        var kx = b.get(0);
        for (ix in 1 ... b.length) {
            var x = b.get(ix);
            hash = ((kx & 0xFFFF) * 31 + x * 121) & (hash_size -1);
            kx = ((kx << 16) | x);
            trace(hash);
            bitbuffer = ((bitbuffer << codelen) | (kx >>> 16));
            foo = bitbuffer << (16 - ix);
        }
        return {b: bitbuffer, h: hash, foo: foo};
    }
    #end

    static function init(v: Int): Int {
        if (Std.random(25) > 30) return Std.random(v);
        return v;
    }

    static function foo() {
        var foo = init(100);
        var hash = init(10153);
        var bitbuffer = init(128);
        var codelen = 9;
        var kx = init(92);
        var x = init(93);
        var ix = init(7);
        hash = ((kx & 0xFFFF) * 31 + x * 121) & (hash_size -1);
        kx = ((kx << 16) | x);
        bitbuffer = ((bitbuffer << codelen) | (kx >>> 16));
        foo = bitbuffer << (16 - ix);
        return {b: bitbuffer, h: hash, foo: foo};
    }

    static function bar(v: Int): Bytes {
        final b = Bytes.alloc(10);
        //var bd = b.getData();
        for (i in 0 ... b.length) b.set(i, v);
        return b;
    }

    static function nothing() {
        trace("nothing");
    }

	static var nimReserved = [
		"block" => "vBlock",
		"const" => "vConst",
		"let" => "vLet",
		"yield" => "vYield", 
		"iterator" => "vIterator",
		"converter" => "vConverter",
		"method" => "vMethod",
		"proc" => "vProc",
		"result" => "vResult",
	];

	static public function fixReserved(name: String) {
		final fix = nimReserved.get(name);
		return if (fix != null) fix else name;
	}

	static public function fixFieldVarName(name:String):String {
		return if (name.startsWith("__")) "fs_" + name.substr(2) 
			else if (name.startsWith("_")) "f_" + name.substr(1) 
			else fixReserved(name.replace("__", ""));
	}

    static function testIter() {
        var s = "von Müttern und Vätern";
        for (c in s) trace(c);
        for (idx => c in s)
            trace('$idx : $c = ${s.charAt(idx)}');
    }

    static function testPadding() {
        for(text in ["AB", "ÄB"]) {
            for (c in [".", "®"]) {
                trace("left|" + text.lpad(c, 10) + "|right");
                trace("left|" + text.rpad(c, 10) + "|right");        
            }
        }
        for(text in ["AB", "ÄB"]) {
            for (c in [".", "®"]) {
                trace(text.lpad(c, 10).charAt(8));
                trace(text.rpad(c, 10).charAt(8));
            }
        }
    }
    static function main() {
        //var buf = term(Bytes.ofString('ABCDEFGH'));
        var b = new A();
        trace(b is B);
        trace(b is A);
        var bd: Dynamic = b;
        trace(bd is B);
        trace(bd is A);
        trace(bd is String);
        trace(bd is Array);
        trace([1, 2, 3] is Array);
        var buf = foo();
        trace(buf);
        var ba = bar('n'.code);
        trace(ba.toString());
        trace(ba.get(0).hex());
        var w1 = new Word16(1, 2);
        trace(w1);
		trace(w1.lo);
		w1.lo = 5;
		trace(w1.lo);
        trace(w1);
        function xyz() {
            w1.lo = 6;
            trace(w1.lo);
            trace(w1);    
            return 1;
        }
        xyz();
        var ng: VRunner = nothing;
        for(i in 0...3) ng();
        var o = {a: 1, b: 3.14, c: "Hello Nim"};
        trace(Reflect.field(o, "c"));
        trace('has field d: ${Reflect.hasField(o, "d")}');
        Reflect.setField(o, "d", "Ok");
        trace('has field d: ${Reflect.hasField(o, "d")}');
        trace(Reflect.field(o, "d"));
        trace(Reflect.fields(o).toString);
        final fn = '_' +  Reflect.field(o, "d");
        trace(fixFieldVarName(fn));
        Reflect.setField(o, "_Ok", "d");
        trace(Reflect.field(o, "_Ok"));
        for (f in Reflect.fields(o)) {
            trace('$f => ${Reflect.field(o,f)}');
        }
        trace(Reflect.compare(2, 300));
        trace(Reflect.compare("300", "2"));
        trace(Reflect.compare(2.35, 300.14));
        var a: Dynamic = 3;
        var b: Dynamic = 3.0;
        trace(Reflect.compare(a, b));
        b = "3";
        trace(Reflect.compare(a, b));
        trace(ba);
        b = ba;
        trace(b);
        ba = b;
        trace(ba);
        var i = 0;
        while (true) {
            i++;
            if (i > 10) {
                trace(i);
                break;
            }
        }
        trace("done loop");
        testIter();
        testPadding();
    }
}