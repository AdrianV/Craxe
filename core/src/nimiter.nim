import core/core

type
    # HaxeIterError = object of CatchableError
    HaxeItWrapper*[T] = ref object of DynamicHaxeObject
        it: HaxeIt[T]
    HaxeKeyValue*[K,V] = ref object of DynamicHaxeObject
        key* :K
        value* :V

    HaxeKeyValueWrapper*[K,V] = ref object of DynamicHaxeWrapper
        key* : ptr K
        value* : ptr V

proc hasNext*[T](this: var HaxeIt[T]): bool {.inline.} =
    this.cur = this.iter()
    result = not finished(this.iter)

proc next*[T](this: var HaxeIt[T]): T {.inline.}= 
    result = this.cur

proc hasNext*[T](this: HaxeItWrapper[T]): bool {.inline.} =
    this.it.cur = this.it.iter()
    result = not finished(this.it.iter)

proc next*[T](this: HaxeItWrapper[T]): T {.inline.}= 
    result = this.cur

#proc makeIt*[T](iter: HaxeIterator[T]): HaxeIt[T] {.inline.} =
#    result.iter = iter

template toHaxeKeyValue* [T: DynamicHaxeObjectRef](v: T): auto =
    HaxeKeyValueWrapper[K,V](kind: TAnonWrapper, qfields: v.qfields, instance: v
        , key: addr v.key
        , value: addr v.value
    )

template toWrapper*[T](this:HaxeIt[T]): HaxeItWrapper[T] =
    HaxeItWrapper[T](qkind: TAnon, it: this)

when false:

    converter toHaxeKeyValue*[K,V] (v: Dynamic): HaxeKeyValueWrapper[K,V] =
        case v.kind:
        of TAnon:
            HaxeKeyValueWrapper[K,V](kind: TAnonWrapper, qfields: v.fanon.qfields, instance: v.fanon
                , key: adr[K](v.fanon, "key")
                , value: adr[V](v.fanon, "value")
            )
        else: raise newException(ValueError, "not an anon")

proc makeDynamic*[K,V](this:HaxeKeyValue[K,V]) {.nimcall.} =
    this.qfields.insert("key", fromField(this.key))
    this.qfields.insert("value", fromField(this.value))

proc makeDynamic*[V](this:HaxeIterator[V]) {.nimcall.} =
    this.qfields.insert("hasNext", fromField(this.hasNext))
    this.qfields.insert("next", fromField(this.next))


