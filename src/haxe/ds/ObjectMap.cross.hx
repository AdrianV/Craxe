package haxe.ds;

@:native("HaxeObjectMap")
@:require("nimmap, nimiter")

extern class ObjectMap<K,V> implements haxe.Constraints.IMap<K, V> {
    @:require("nimmap, nimiter")
    public function new();
    function clear():Void;
    function copy():ObjectMap<K,V>;
    function exists(key:K):Bool;
    function get(key:K):Null<V>;
    @:require("nimiter")
    @:native("values")
    function iterator():Iterator<V>;
    function keyValueIterator():KeyValueIterator<K,V>;
    @:require("nimiter")
    function keys():Iterator<K>;
    function remove(key:K):Bool;
    function set(key:K, value:V):Void;
    function toString():String;
}