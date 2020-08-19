package craxe.common.tools;

abstract SearchResult(Int) from Int {
	public inline function new(pos: Int) this = pos;
	static public inline function generate(cond: Bool, pos: Int): Int return cond ? -pos -1: pos;
	@:to public inline function found(): Bool return this >= 0;
	@:to public inline function idx(): Int return generate(this < 0 ,  this);
  	@:op(! A) public inline function notBool(): Bool return ! found();	
	@:commutative @:op(A && B) static inline function and(A: SearchResult, B: Bool) return A.found() && B;	
	@:commutative @:op(A || B) static inline function or(A: SearchResult, B: Bool) return A.found() || B;

	static inline function empty() return new SearchResult(-1);
}
