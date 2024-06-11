package test;

class Foo {
	static inline var compress_size = 2046;
	static inline var hash_size = 16384;
	#if (python)
	static inline var _mask = 0x7FFFFFFF; // (0x7FFFFFFF << 1) | 1;
	#end
	#if (js || neko || php || python || lua)
	static inline var _empty: Int = null;
	#else
	static public inline var _empty: Int = 0;
	#end    
    static public function getIt() {
        return _empty;
    }
    static var fooBar = "FooBar";
}

class TestKeyword {
    static inline var _empty: Int = 0;
    static function block() {
        trace("Wow");
    }
    static function main() {
        block();
        var a = {_empty: 1, converter: "b", method: "c"};
        final atyp = Type.typeof(a);
        trace(atyp);
        trace(a);
        trace(_empty);
        trace(Foo.getIt());
        //final foo = Foo;
        trace(Foo);
    }
}