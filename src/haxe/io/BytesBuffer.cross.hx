package haxe.io;

@:native("HaxeBytesData")
extern class BytesBuffer {
    @:native("len")
    var length(default, never): Int;

    function new();
    function addByte(byte:Int): Void;
    function add(src:Bytes): Void;
    function addString(v:String, ?encoding:Encoding): Void;
    function addInt32(v:Int): Void;
    //function addInt64(v:haxe.Int64);
    function addFloat(v:Float): Void;
    function addDouble(v:Float): Void;
    function addBytes(src:Bytes, pos:Int, len:Int): Void;
    function getBytes():Bytes;

}