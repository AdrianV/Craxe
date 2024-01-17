import core/core

type
    # HaxeIterError = object of CatchableError
    HaxeIt*[T] = object
        iter*: iterator(): T
        cur: T
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

#proc makeIt*[T](iter: HaxeIterator[T]): HaxeIt[T] {.inline.} =
#    result.iter = iter

template toHaxeKeyValue* [T: DynamicHaxeObjectRef](v: T): auto =
    HaxeKeyValueWrapper[K,V](kind: TAnonWrapper, fields: v.fields, instance: v
        , key: addr v.key
        , value: addr v.value
    )

when false:

    converter toHaxeKeyValue*[K,V] (v: Dynamic): HaxeKeyValueWrapper[K,V] =
        case v.kind:
        of TAnon:
            HaxeKeyValueWrapper[K,V](kind: TAnonWrapper, fields: v.fanon.fields, instance: v.fanon
                , key: adr[K](v.fanon, "key")
                , value: adr[V](v.fanon, "value")
            )
        else: raise newException(ValueError, "not an anon")

proc makeDynamic*[K,V](this:HaxeKeyValue[K,V]) =
    this.fields.insert("key", fromField(this.key))
    this.fields.insert("value", fromField(this.value))



