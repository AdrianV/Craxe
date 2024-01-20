import core/core
import std/tables
import nimiter


template newHaxeStringMap*[T](): HaxeStringMap[T] = newStringMap[T]()
template newStringMapXhaxeds*[T](): HaxeStringMap[T] = newStringMap[T]()
template newHaxeIntMap*[T](): HaxeIntMap[T] = newIntMap[T]()
template newIntMapXhaxeds*[T](): HaxeIntMap[T] = newIntMap[T]()

template newDynamic*[K,V](value: HaxeMap[K,V]) = 
    #checkDynamic[HaxeMap[K,V]](value)
    Dynamic(kind:TClass, fclass: value)


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

proc values*[K,V](this: HaxeMap[K, V]): HaxeIt[V] = 
  result.iter = iterator (): V = 
      for x in this.data.values() : yield x

proc keys*[K,V](this: HaxeMap[K, V]): HaxeIt[K] = 
  result.iter = iterator (): auto = 
      for x in this.data.keys() : yield x

proc keyValueIterator*[K,V](this: HaxeMap[K, V]): HaxeIt[HaxeKeyValue[K,V]] = 
  result.iter = iterator (): HaxeKeyValue[K,V] = 
      for k,v in this.data.pairs() : yield HaxeKeyValue[K,V](kind: TAnon, key: k, value: v)
