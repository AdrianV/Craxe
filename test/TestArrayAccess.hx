package test;

abstract Rev(Map<String, Int>) from Map<String, Int> to Map<String, Int> {

	@:arrayAccess
    function get1(k: String) {
			return this.get(k);
    }
  @:arrayAccess
    function get2(val: Int): Null<String> {
			for (k => v in this)
        if (v == val) return k;
      return null;
    }
}

class TestArrayAccess {
  static function main() {
    trace("Haxe is great!");
    var mp: Rev = [
			"eins" => 1,
      "zwei" => 2,
      "drei" => 3,
    ];
    trace(mp["zwei"]);
    trace(mp[1]);
    var d: Dynamic = mp;
    trace(d[1] == null);
    d = [
			1 => "foo",
      2 => "bar"
    ];
    trace(d[1] == null);
    //d = {"1": "eins", "2": "zwei"};
    //trace(d[1] == null);
    
      
  }
}