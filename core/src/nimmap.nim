import core/core
import std/tables
import nimiter

const TABLE_INIT_SIZE = 32

type
  #HaxeIntMapStatic* = object of HaxeStaticObject
  #HaxeObjectMapStatic* = object of HaxeStaticObject
  ObjectMapXhaxeds* = HaxeObjectMap
  HaxeDynamicMap* = HaxeObjectMap[Dynamic, Dynamic]

template newHaxeStringMap*[T](): HaxeStringMap[T] = newStringMap[T]()
template newStringMapXhaxeds*[T](): HaxeStringMap[T] = newStringMap[T]()
template newHaxeIntMap*[T](): HaxeIntMap[T] = newIntMap[T]()
template newIntMapXhaxeds*[T](): HaxeIntMap[T] = newIntMap[T]()

var HaxeIntMapStaticInst* = HaxeStaticObjectRef(qkind: TStatic, qparent: nil, qname: "haxe.ds.IntMap")
var HaxeObjectMapStaticInst* = HaxeStaticObjectRef(qkind: TStatic, qparent: nil, qname: "haxe.ds.ObjectMap")
var HaxeStringMapStaticInst* = HaxeStaticObjectRef(qkind: TStatic, qparent: nil, qname: "haxe.ds.StringMap")

register(HaxeIntMap[Dynamic], HaxeIntMapStaticInst)
register(HaxeDynamicMap, HaxeObjectMapStaticInst)
register(HaxeStringMap[Dynamic], HaxeStringMapStaticInst)

proc newStringMap*[T](init: bool = true) : HaxeStringMap[T] =
    result = HaxeStringMap[T](kind: getKind(typedesc T), qstatic: HaxeStringMapStaticInst, qkind: TClass)
    if init: result.data = initTable[string, T](TABLE_INIT_SIZE)

proc newIntMap*[T](init: bool = true) : HaxeIntMap[T] =
    result = HaxeIntMap[T](kind: getKind(typedesc T), qstatic: HaxeIntMapStaticInst, qkind: TClass)
    if init: result.data = initTable[int32, T](TABLE_INIT_SIZE)

proc newObjectMap*[K, V](init: bool = true) : HaxeObjectMap[K, V] =
    result = HaxeObjectMap[K, V](kind: getKind(typedesc V), qstatic: HaxeObjectMapStaticInst, qkind: TClass)
    if init: result.data = initTable[K, V](TABLE_INIT_SIZE)

# --- Haxe Map --- 

# Haxe Map
template set*[V](this:HaxeStringMap[V], key:string, value:V) =
    this.data[key] = value

template set*[V](this:HaxeStringMap[V], key:String, value:V) =
    this.data[$key] = value

#template set*[V](this:HaxeMap[string, V], key:String, value:V) =
#    this.data[key.fdata] = value

template set*[K: not(string|String), V](this:HaxeMap[K, V], key:K, value:V) =
    this.data[key] = value

proc getNull*[K, V](this:Table[K, V], key:K): Null[V] =    
    if this.hasKey(key):
        return Null[V](value: this.getOrDefault(key))
    else:
        return nil

template get*[K, V: HaxeValueType](this:HaxeMap[K, V], key:K): auto = 
    this.data.getNull(this, key)

template get*[K: not (string | String), V](this:HaxeMap[K, V], key:K): auto =
  when (V is ptr or V is ref):
    this.data.getOrDefault(key)
  else:
    getNull(this.data, key)

template get*[V](this:HaxeStringMap[V], key:string): auto =
  when (V is ptr or V is ref):
    this.data.getOrDefault(key)
  else:
    getNull(this.data, key)

template get*[V](this:HaxeStringMap[V], key:String): auto =
  when (V is ptr or V is ref):
    this.data.getOrDefault($key)
  else:
    getNull(this.data, $key)

template `$`*[K, V](this:HaxeMap[K, V]) : string =
    $this.data


template newDynamic*[K,V](value: HaxeMap[K,V]) = 
    #checkDynamic[HaxeMap[K,V]](value)
    Dynamic(q:Dyn(kind:TClass, fclass: value))


template clear*[K,V](t: HaxeMap[K, V]): void = t.data.clear()

proc copy*[K,V](this: HaxeMap[K, V]): HaxeMap[K, V] = 
  when K is int32:
    result = newIntMap[V](false)
  else:
    result = newObjectMap[K,V](false)
  result.data = initTable[K,V](this.data.len)
  for k, v in tables.pairs(this.data):
    result.data[k] = v

proc copy*[V](this: HaxeStringMap[V]): HaxeStringMap[V] =
  result = newStringMap[V](false)
  result.data = initTable[string,V](this.data.len)
  for k, v in tables.pairs(this.data):
    result.data[k] = v

template exists*[V](t: HaxeStringMap[V], k:string|String): bool = t.data.hasKey($k)

template exists*[K,V](t: HaxeMap[K, V], k:K): bool = t.data.hasKey(k)

template remove*[K,V](t: HaxeMap[K, V], k:K): bool = 
  block:
    var v: V
    t.data.pop(k, v)

proc toString*[K,V](this: HaxeMap[K, V]): String = 
  var res = "["
  var first = true
  for k, v in tables.pairs(this.data):
    if not first : res &= ", "
    res &= $k & " => " & $v
    first = false
  res &= "]"
  return res.toXString

proc values*[K,V](this: HaxeMap[K, V]): HaxeIt[V] = 
  result.iter = iterator (): V = 
      for x in this.data.values() : yield x

proc keys*[K,V](this: HaxeMap[K, V]): HaxeIt[K] = 
  result.iter = iterator (): auto = 
      for x in this.data.keys() : yield x

proc keyValueIterator*[K,V](this: HaxeMap[K, V]): HaxeIt[HaxeKeyValue[K,V]] = 
  result.iter = iterator (): HaxeKeyValue[K,V] = 
      for k,v in this.data.pairs() : yield HaxeKeyValue[K,V](qkind: TAnon, key: k, value: v)

proc keys*[V](this: HaxeStringMap[V]): HaxeIt[String] = 
  result.iter = iterator (): auto = 
      for x in this.data.keys() : yield x.toXString

proc keyValueIterator*[V](this: HaxeStringMap[V]): HaxeIt[HaxeKeyValue[String,V]] = 
  result.iter = iterator (): HaxeKeyValue[String,V] = 
      for k,v in this.data.pairs() : yield HaxeKeyValue[String,V](qkind: TAnon, key: k.toXString, value: v)

proc values*[K,V](this: HaxeObjectMap[K, V]): HaxeIt[V] = 
  result.iter = iterator (): V = 
      for x in this.data.values() : yield x.v

proc keys*[K,V](this: HaxeObjectMap[K, V]): HaxeIt[K] = 
  result.iter = iterator (): auto = 
      for x in this.data.values() : yield x.k

proc keyValueIterator*[K,V](this: HaxeObjectMap[K, V]): HaxeIt[HaxeKeyValue[K,V]] = 
  result.iter = iterator (): HaxeKeyValue[K,V] = 
      for x in this.data.values() : yield HaxeKeyValue[K,V](qkind: TAnon, key: x.k, value: x.v)

proc get*(this: HaxeIntMap[Dynamic], k: int32): Dynamic =
  case this.kind :
  of TString : return cast[HaxeIntMap[String]](this).data.getOrDefault(k).toDynamic
  of TInt : return cast[HaxeIntMap[int32]](this).data.getOrDefault(k).toDynamic
  of TFloat : return cast[HaxeIntMap[float]](this).data.getOrDefault(k).toDynamic
  of TBool : return cast[HaxeIntMap[bool]](this).data.getOrDefault(k).toDynamic
  of TAnon : return cast[HaxeIntMap[DynamicHaxeObjectRef]](this).data.getOrDefault(k).asDynamic
  of TClass : return cast[HaxeIntMap[HaxeObjectRef]](this).data.getOrDefault(k).toDynamic
  of TEnum : return cast[HaxeIntMap[HaxeEnum]](this).data.getOrDefault(k).toDynamic
  of TAnonWrapper : return cast[HaxeIntMap[DynamicHaxeWrapper]](this).data.getOrDefault(k)
  of TStatic: return cast[HaxeIntMap[ptr HaxeStaticObject]](this).data.getOrDefault(k).toDynamic
  of TDynamic : return this.data.getOrDefault(k)
  of TFunc : return this.data.getOrDefault(k)
  of TNone : return nil
  of TType : return cast[HaxeIntMap[TypeIndex]](this).data.getOrDefault(k).toDynamic

proc get*(this: HaxeDynamicMap, k: Dynamic): Dynamic =
  nil

proc set*(this: HaxeDynamicMap, k: Dynamic, value: Dynamic) =
  # this.data[k] = value
  discard
