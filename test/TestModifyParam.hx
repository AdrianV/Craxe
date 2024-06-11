package test;

class TestModifyParam {
    static function test(p: Int) {
        trace(++p);
        trace(++p);        
    }

    static function main() {
        test(1);
    }
}