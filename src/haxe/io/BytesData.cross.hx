package haxe.io;

import haxe.io.Input;

@:native("HaxeBytesData")
@:require("core/bytes")
extern class BytesData implements ArrayAccess<Int> {
    //@:native("len")
    var length(default, never): Int;

    public function fastGet(i:Int):Int;

    //@:arrayAccess
    public function get(i:Int):Int;

    //@:arrayAccess
    public function set(i:Int, v:Int): Int;


}