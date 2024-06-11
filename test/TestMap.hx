package test;

class Foo {
    var f: Map<String,String> = new Map();
    public inline function new() {}

    public function add(k: String, v: String) {
        f.set(k, v);
    }
}

class TestMap {

    static function testMap() {
        var m = new Map();
        m.set('foo', 'bar');
        m.set('bar', 'foo');
        trace(m.get('foo'));
        trace(m.get('bar'));
        trace(m.get('baz'));
        var m2 = m.copy();
        //$type(m2);
        m.clear();
        trace(m.exists('foo'));
        trace(m2.exists('bar'));
        trace(m2);
        for (v in m2) trace(v);
        for (k in m2.keys()) trace(k);
        for (k => v in m2) trace('$k => $v');
    }

    static function main() {
        final f = new Foo();
        f.add("Foo", "Bar");
        trace(f);
        testMap();
    }
    
}