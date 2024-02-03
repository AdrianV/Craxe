package haxe.io;

@:native("HaxeBytes")
@:require("core/bytes")
extern class Bytes {
    var length(default, never):Int;
    private var b:BytesData;
    function get(pos:Int):Int;
    function set(pos:Int, v:Int):Void;
    function blit(pos:Int, src:Bytes, srcpos:Int, len:Int):Void;
    //function fill(pos:Int, len:Int, value:Int);
    //function sub(pos:Int, len:Int):Bytes;
    function compare(other:Bytes):Int;
    //function getDouble(pos:Int):Float;
    //function getFloat(pos:Int):Float;
    //function setDouble(pos:Int, v:Float):Void;
    //function setFloat(pos:Int, v:Float):Void;
    //function getUInt16(pos:Int):Int;
    //function setUInt16(pos:Int, v:Int):Void;
    //function getInt32(pos:Int):Int;
    //function getInt64(pos:Int):haxe.Int64;
    //function setInt32(pos:Int, v:Int):Void;
    //function setInt64(pos:Int, v:haxe.Int64):Void;
    function getString(pos:Int, len:Int, ?encoding:Encoding):String;
    public inline function readString(pos:Int, len:Int):String {
		return getString(pos, len);
	}
    public inline function toString():String {
        return getString(0, length);
    }
    function toHex():String;
    function getData():BytesData;
    static function alloc(length:Int):Bytes;
    static function ofString(s:String, ?encoding:Encoding):Bytes;
    //static function ofData(b:BytesData);
    //static function ofHex(s:String):Bytes;
    static function fastGet(b:BytesData, pos:Int):Int;
}