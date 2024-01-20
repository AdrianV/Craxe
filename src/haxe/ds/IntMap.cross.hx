package haxe.ds;

@:coreApi
@:native("HaxeIntMap")
@:require("nimmap, nimiter")

extern class IntMap<T> implements haxe.Constraints.IMap<Int, T> {
    @:require("nimmap, nimiter")
    public function new();
    function clear():Void;
    function copy():IntMap<T>;
    function exists(key:Int):Bool;
    function get(key:Int):Null<T>;
    @:require("nimiter")
    @:native("values")
    function iterator():Iterator<T>;
    function keyValueIterator():KeyValueIterator<Int,T>;
    @:require("nimiter")
    function keys():Iterator<Int>;
    function remove(key:Int):Bool;
    function set(key:Int, value:T):Void;
    function toString():String;
}