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

    public static inline function isSpace(s:String, pos:Int):Bool {
        final c = fastCodeAt(s, pos);
        return (c > 8 && c < 14) || c == 32;
    }

    public static function ltrim(s:String):String;
    public static function rtrim(s:String):String;
    public inline static function trim(s:String):String {
		return ltrim(rtrim(s));
	}    
}
