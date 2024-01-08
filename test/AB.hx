package test;

class FooBar extends test.a.Foo {
    override public function bar() {
        super.bar();
        trace('FooBar');
    }
}

class AB {
    static function testAandB() {
        var a = new test.a.Foo();
        a.bar();
        a = new FooBar();
        a.bar();
        var b = new test.b.Foo();
        b.bar();    
    }

    static function main() {
        testAandB();       
    }
}