package craxe.generators.nim;
using  StringTools;

class NimNames {

	static var nimReserved = [
		"block" => "qBlock",
		"const" => "qConst",
		"let" => "qLet",
		"yield" => "qYield", 
		"iterator" => "qIterator",
		"converter" => "qConverter",
		"method" => "qMethod",
		"proc" => "qProc",
		"typeof" => "getTypeof",
		"hasNext" => "hasNext",
	];

	static var nimFixed = [
		"result" => "qResult",
		"typeof" => "getTypeof",
		"hasNext" => "hasNext",
		"resolveClass" => "resolveClass",
		"resolveEnum" => "resolveEnum", 
	];

	static public function allFixed(): Array<{key: String, value: String}> {
		final res = [for (k => v in nimFixed) if (k != v) {key: k, value: v}];
		return res;
	}

	static inline function fixReserved(name: String) {
		final fix = nimReserved.get(name);
		return if (fix != null) fix else name;
	}

	static inline function fixLocalVarName(name:String):String {
		return normalize(name);
		#if (false)
		return if (name.startsWith("__")) "ls_" + name.substr(2) 
			else if (name.startsWith("_")) "l_" + name.substr(1) 
			else fixReserved(name.replace("__", ""));
		#end
	}

	static public inline function fixFieldVarName(name:String):String {
		return normalize(name);
		#if (false)
		return if (name.startsWith("__")) "fs_" + name.substr(2) 
			else if (name.startsWith("_")) "f_" + name.substr(1) 
			else fixReserved(name.replace("__", ""));
		#end
	}

	static function fixStaticFieldVarName(name:String):String {
		return normalize(name);
		#if (false)
		var res = if (name.startsWith("__")) "sy_" + name.substr(2);
			else {
				if (name.startsWith("_")) name.substr(1);
				else name;
			}
		return fixReserved(res.replace("__", ""));
		#end
	}

	static public function fixed(name: String) {
		final fix = nimFixed.get(name);
		return fix != null ? fix : name;
	}

	static public function fixOnly(name: String) {
		final res = fixReserved(name);
		nimFixed.set(name, res);
		return res;	
	}

	static public function normalize(name: String): String {
		var res = nimFixed.get(name);
		if (res != null) return res;
		res = "";
		var lu = 0;
		var first = true;
		var hash = 0;
		for( x => c in name) {
			switch c {
				case '_'.code:
					if (first) lu++;
					else hash = hash * 31 + (c - 0x1F + x);
					continue;
				case 'Q'.code if (x == 0):
					hash = hash * 31 + (c - 0x1F + x);
					res += "Q";
				case var cc if (cc >= 'A'.code && cc <= 'Z'.code && x > 0):
					res += String.fromCharCode(cc);
					hash = hash * 31 + (cc - 0x1F + x);
				case 'q'.code :
					hash = hash * 31 + (c - 0x1F + x);
					//if (first && firstUpper) res += "Q";
					res += "q";
				case var cc if (cc >= 'a'.code && cc <= 'z'.code):
					//if (first && firstUpper) {
					//	res += String.fromCharCode(cc - 0x20);
					//	hash = hash * 31 + (cc - 0x3F);
					//} else {
						res += String.fromCharCode(cc);
					//}
				case var cc if (false && res == "q"):
					res += "q" + String.fromCharCode(cc);
				case var cc: 
					res += String.fromCharCode(cc);
			}
			first = false;
		}
		if (hash < 0) hash = -hash;
		if (hash == 0 && lu == 0) res = fixReserved(res);
		else if (hash == 0 && lu == 1) res = 'q_${res}';
		else if (lu != 0) res = 'q${lu}_${hash}${res}';
		else res = '${res}_${hash}';
		nimFixed.set(name, res);
		return res;
	}

	#if (testing)
	static function main() {
		for (s in ["__s", "q2_s", "q2s1582", "q2s158250", "Q", "Q18", "_a", "_A"]) {
			trace('$s => ${normalize(s)}');
		}
	}
	#end
}
