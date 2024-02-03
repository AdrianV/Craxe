package test;

typedef Foo<T> = Array<T>;



class TestList {
    static function main() {
        #if (true)
        final l = new List();
        l.add("Hello");
        l.add("Haxe");
        for (x in l) trace(x);
        #end
    }
}