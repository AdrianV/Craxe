package haxe.ds;

@:coreApi
@:native("HaxeStringMap")
@:require("nimmap, nimiter")

extern class StringMap<T> implements haxe.Constraints.IMap<String, T> {
    @:require("nimmap, nimiter")
    public function new();
    function clear():Void;
    function copy():StringMap<T>;
    function exists(key:String):Bool;
    function get(key:String):Null<T>;
    @:require("nimiter")
    @:native("values")
    function iterator():Iterator<T>;
    function keyValueIterator():KeyValueIterator<String,T>;
    @:require("nimiter")
    function keys():Iterator<String>;
    function remove(key:String):Bool;
    function set(key:String, value:T):Void;
    function toString():String;
    //function blah(): HxKeyValue<String,T>;
}