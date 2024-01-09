import core/core
import std/tables


template newHaxeStringMap*[T](): HaxeStringMap[T] = newStringMap[T]()

template clear*[K,V](t: HaxeMap[K, V]): void = t.data.clear()

proc copy*[K,V](this: HaxeMap[K, V]): HaxeMap[K, V] = 
  result = HaxeMap[K,V]()
  result.data = initTable[K,V](this.data.len)
  for k, v in tables.pairs(this.data):
    result.data[k] = v

template exists*[K,V](t: HaxeMap[K, V], k:K): bool = t.data.hasKey(k)

template remove*[K,V](t: HaxeMap[K, V], k:K): bool = 
  block:
    var v: V
    t.data.pop(k, v)

proc toString*[K,V](this: HaxeMap[K, V]): system.string = 
  result = "["
  var first = true
  for k, v in tables.pairs(this.data):
    if not first : result &= ", "
    result &= $k & " => " & $v
    first = false
  result &= "]"

  

