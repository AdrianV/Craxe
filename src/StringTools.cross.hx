
@:require("nimstring")
@:native("StringTools")
extern class StringTools {

    public static inline function contains(s:String, value:String):Bool {
        return s.indexOf(value) >= 0;
    }

    public static function fastCodeAt(s:String, index:Int):Int;

    public static function urlEncode(s:String):String;

    public static function urlDecode(s:String):String;

    public static function htmlEscape(s:String, ?quotes:Bool):String;

    public static function startsWith(s:String, start:String):Bool;

    public static function hex(n:Int, ?digits:Int): String;

    public static function isSpace(s:String, pos:Int):Bool;

    public static function ltrim(s:String):String;
    public static function rtrim(s:String):String;
    public inline static function trim(s:String):String {
		return ltrim(rtrim(s));
	}    
    public static function replace(s:String, sub:String, by:String):String;
    public static inline function isEof(c: Int) {
        return c == 0;
    }

    @:native("iter")
    public static function iterator(s:String):Iterator<Int>;
    public static function keyValueIterator(s:String):KeyValueIterator<Int, Int>;
    public static function lpad(s:String, c:String, l:Int):String;
    public static function rpad(s:String, c:String, l:Int):String;

}
