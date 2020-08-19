class Loop {

	macro static public function benchmark(test, start, done) {
		return macro {
            trace($start);
            var dt = haxe.Timer.stamp();
            $test;
            var dur = haxe.Timer.stamp() - dt;
            trace($done);
		}
	}

    static function loop() {
        var i = 0;
        for (a in 0...1000) {
            for(b in 0...1000) {
                for(c in 0...1000){
                    i++;
                }
            }
        }        
        trace(i);
    }

    static function main() {
		benchmark(loop(), "for loop nested:", 'completed in $dur');
    }
}