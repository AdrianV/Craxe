import core/core

type
    # HaxeIterError = object of CatchableError
    # HaxeItState = enum Init, Running, StepMade, Done
    #HaxeIterator*[T] = iterator(): T {.closure.}
    HaxeIt*[T] = object
        iter*: iterator(): T
        cur: T
    HaxeKeyValue*[K,V] = ref object of DynamicHaxeObject
        key:K
        value:V

    HaxeKeyValueWrapper*[K,V] = ref object of DynamicHaxeWrapper
        key: ptr K
        value: ptr V

proc hasNext*[T](this: var HaxeIt[T]): bool {.inline.} =
    this.cur = this.iter()
    result = not finished(this.iter)

proc next*[T](this: var HaxeIt[T]): T {.inline.}= 
    result = this.cur

#proc makeIt*[T](iter: HaxeIterator[T]): HaxeIt[T] {.inline.} =
#    result.iter = iter

when false:
    converter toHaxeKeyValue* [K,V](v: HaxeKeyValue[K,V]): HaxeKeyValueWrapper[K,V] {.inline} =
        HaxeKeyValueWrapper[K,V](kind: TAnon, fields: v.fields, instance: v
            , key: addr v.key
            , value: addr v.value
        )

    converter toHaxeKeyValue*[K,V] (v: Dynamic): HaxeKeyValue[K,V] =
        case v.kind:
        of TClass:
            cast[HaxeKeyValue[K,V]](HaxeKeyValueWrapper[K,V](kind: TAnon, fields: v.fclass.fields, instance: v.fclass
                , key: adr[K](v.fclass, "key")
                , value: adr[V](v.fclass, "value")
            ))
        else: raise newException(ValueError, "not an anon")

proc makeDynamic*[K,V](this:HaxeKeyValue[K,V]) =
    this.fields.insert("key", fromField(this.key))
    this.fields.insert("value", fromField(this.value))

