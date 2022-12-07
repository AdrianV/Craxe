package test;

class AB {
    static function testAandB() {
        var a = new test.a.Foo();
        a.bar();
        var b = new test.b.Foo();
        b.bar();    
    }

    static function main() {
        testAandB();       
    }
}