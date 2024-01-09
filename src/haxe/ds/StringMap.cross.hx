package haxe.ds;

@:coreApi
@:native("HaxeStringMap")
@:require("nimmap")
extern class StringMap<T> implements haxe.Constraints.IMap<String, T> {
    @:require("nimmap")
    public function new();
    function clear():Void;
    function copy():StringMap<T>;
    function exists(key:String):Bool;
    function get(key:String):Null<T>;
    function iterator():Iterator<T>;
    function keyValueIterator():KeyValueIterator<String, T>;
    function keys():Iterator<String>;
    function remove(key:String):Bool;
    function set(key:String, value:T):Void;
    function toString():String;
}