package craxe.common.tools;

typedef Comparer<K> = {
	function less(a:K, b:K):Bool;
}

typedef KeyGetter<T,K> = {
	function key(item:T):K;
}

@:generic
class BinSearch<T,K, G: KeyGetter<T,K>,C: Comparer<K>> {

    var get: G;
    var comp:C;
    public inline function new(get: G, comp:C) {
        this.get = get;
        this.comp = comp;
    }

    public function find(k: K, data: Array<T>) return comp.less(k, get.key(data[0]));


    public function search(hay: Array<T>, needle: K): SearchResult {
		var res = 0;
		var H = hay.length -1;
		while (res <= H) {
			var I = (res + H) >> 1;
			if ( comp.less(get.key(hay[I]), needle)  ) 
				res = I + 1 
			else { // every hay item greater or equal needle
				H= I - 1;
				while (res <= H) {
						I = (res + H) >> 1;
						if ( comp.less(get.key(hay[I]), needle) ) 
								res = I + 1 
						else {
								H= I - 1;
						}
				}
				return SearchResult.generate(comp.less(needle, get.key(hay[res])), res);    
			}
		}
		return - (res + 1);		
	}
}

class IntComparer {
  public inline function new() {}
  public inline function less(a: Int, b: Int): Bool return a < b;
}


class StringComparer {
  public inline function new() {}
  public inline function less(a: String, b: String): Bool return a < b;
}
