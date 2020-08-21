{.experimental: "codeReordering".}

import tables
import typetraits
import strutils

type
    # Objects that can calculate self hash
    Hashable = concept x
       x.hash is proc():int

    # Dynamic
    DynamicType* = enum
        THaxe, TAnonWrapper, TString, TInt, TFloat, TAnonObject, TClass, TPointer

    # Main object for all haxe objects
    HaxeObject* = object of RootObj
        kind*: DynamicType

    # Main object for all haxe referrence objects
    HaxeObjectRef* = ref HaxeObject

    # Value object
    Struct* = object of HaxeObject


    ValueType* = bool | int32 | string | float | object 

    Null*[T: ValueType] = ref object of HaxeObject
        value*: T


    NullAbstr*[T] = Null[T]

    # --- Haxe Iterator ---

    HaxeIterator*[T] = ref object of DynamicHaxeObject
        hasNext*:proc():bool
        next*:proc():T

    # --- Haxe Array ---    

    HaxeArrayIterator*[T] = ref object of HaxeIterator[T]
        arr:HaxeArray[T]
        currentPos:int

    HaxeArray*[T] = ref object of HaxeObject
        data*:seq[T]

    # --- Haxe Map

    # Base map
    HaxeMap*[K, V] = ref object of HaxeObject
        data*:Table[K, V]

    # Haxe String map
    HaxeStringMap*[T] = HaxeMap[string, T]

    # Haxe Int map
    HaxeIntMap*[T] = HaxeMap[int, T]

    # Haxe object map
    HaxeObjectMap*[K, V] = HaxeMap[K, V]

    # --- Dynamic ---

    AnonField* = ref object
        name*:string
        value*:Dynamic

    # Haxe anonimous object
    AnonObject* = seq[AnonField]

    # Dynamic object with access to fields by name
    DynamicHaxeObject* = object of HaxeObject
        `getFields`*: proc():HaxeArray[string]
        `getFieldByName`*: proc(name:string): Dynamic
        `setFieldByName`*: proc(name:string, value:Dynamic):void

    DynamicHaxeObjectRef* = ref DynamicHaxeObject

    # Dynamic proxy for real object
    DynamicHaxeObjectProxy*[T] = object of DynamicHaxeObject
        obj*:T

    DynamicHaxeObjectProxyRef*[T] = ref object of DynamicHaxeObjectProxy[T]

    Dynamic* = ref object of RootObj
        case kind*: DynamicType
        of THaxe, TAnonWrapper: discard
        of TString: 
            fstring*: system.string
        of TInt: 
            fint*:int32
        of TFloat: 
            ffloat*:float
        of TAnonObject: 
            fanon*: AnonObject
        of TClass: 
            fclass*: DynamicHaxeObjectRef
        of TPointer:
            fpointer*: pointer

    # --- Haxe Enum ---

    # Haxe enum
    HaxeEnum* = ref object of HaxeObject
        index*:int

# Core procedures
# a++
proc apOperator*[T](val:var T):T {.discardable, inline.} =        
    result = val
    inc(val)

# ++a
proc bpOperator*[T](val:var T):T {.discardable, inline.} =        
    inc(val)
    result = val

# --a
proc ammOperator*[T](val:var T):T {.discardable, inline.} =        
    result = val
    dec(val)

# --a
proc bmmOperator*[T](val:var T):T {.discardable, inline.} =        
    dec(val)
    result = val

when false:
    template `+`*(s:string, i:untyped): string =
        s & $i

    template `+`*(i:untyped, s:string): string =
        $i & s

    template `+`*(s1:string, s2:string): string =
        s1 & s2

template toString*(this:untyped):string =
    $this

# String
template length*(this:string) : int =
    len(this)

# String
template charAt*(this:string, pos:int) : string =
    $this[pos]

converter toValue* [T: ValueType] (v:Null[T]): T {.inline.} =
    if not v.isNil: result = v.value

converter fromValue* [T: ValueType](v:T): Null[T] {.inline.} =
    Null[T](value: v) 

converter fromValue* (v:int): Null[int32] {.inline.} =
    Null[int32](value: v.int32) 

when false:
    template toNull* [T](v:typeof(nil)): Null[T] =
        Null[T](has: false)

    template toNull*[T](v:T): Null[T] =
        Null[T](has: true, value: v)
    
#template `!=`* [T] (v1:Null[T], n: typeof(nil)): bool =
#    v1.has

#template `==`* [T] (v1:Null[T], n: typeof(nil)): bool =
#    not v1.has

template `==`* (v1:string, n: typeof(nil)): bool =
    false

#template `.`* [T](v: Null[T], f: untyped) =
#    v.value.f

#template `.=`* [T,V](v: var Null[T], f: untyped, val: V) =
#    v.value.`f` = val

#from macros import unpackVarargs

#template `.()`* [T](v: Null[T]; f: untyped, args: varargs[untyped]): untyped =
#  unpackVarargs(s.value.f, args)


#template `==`* [T] (v1:Null[T], n: typeof(nil)): bool =
#    isNil(v1.value)

template `==`* [T:ValueType] (v1:Null[T], n: typeof(nil)): bool =
    v1.isNil

template `==`* [T:ValueType](v1:Null[T], v2:T):bool =
    not v1.isNil and v1.value == v2
    

proc `$`* [T:ValueType] (this:Null[T]):string =
    if this.isNil: "null"  else: $(this.value)

proc `==`*(v1:Hashable, v2:Hashable):bool =
    v1.hash() == v2.hash()

template hash*(this:HaxeObjectRef):int =
    cast[int](this)

proc `==`*(v1:HaxeObjectRef, v2:HaxeObjectRef):bool =
    v1.hash() == v2.hash()

template `==`*[T: ValueType](v1:Null[T], v2:Null[T]):bool =
    return if not v1.isNil and not v2.isNil : v1.value == v2.value else : v1.isNil and v2.isNil

# Scoped block
template valueBlock*(body : untyped) : untyped = 
    (proc() : auto {.gcsafe.} = 
        body
    )()

# --- Haxe Array ---

# HaxeArray

template newHaxeArray*[T](): HaxeArray[T] = HaxeArray[T]()
    
template `[]`*[T](this:HaxeArray[T], pos:Natural):T =
    #let this = this
    if pos >= 0 and pos < this.data.len: this.data[pos] else: T.default
    
template get*[T](this:HaxeArray[T], pos:Natural):T =
    #let this = this
    if pos == 437504: echo this.data.len
    if pos >= 0 and pos < this.data.len: this.data[pos] else: T.default

template `[]=`*[T](this:var HaxeArray[T], pos:Natural, v: T) =
    if pos >= 0 :
        if pos >= this.data.len: setLen(this.data, pos + 1)
        this.data[pos] = v

template set* [T] (this:var HaxeArray[T], pos:Natural, v: T) =
    if pos >= 0 :
        if pos == 437504: echo this.data.len
        if pos >= this.data.len: setLen(this.data, pos + 1)
        this.data[pos] = v

    
template push*[T](this:HaxeArray[T], value:T):int32 =
    this.data.add(value)
    len(this.data).int32

template pop*[T](this:HaxeArray[T]): T =
    let last = this.data.len - 1
    let res = this.data[last]
    delete(this.data, last)
    res

#template get*[T](this:HaxeArray[T], pos:int): T =
#    this.data[pos]

template length*[T](this:HaxeArray[T]): int32 =    
    this.data.len.int32

template `$`*[T](this:HaxeArray[T]) : string =
    $this.data

proc newHaxeArrayIterator*[T](arr:HaxeArray[T]) : HaxeArrayIterator[T] =
    var res = HaxeArrayIterator[T](arr: arr)
    res.hasNext = proc():bool =
        return res.currentPos < length(res.arr)
    res.next = proc():T =
        result = res.arr[res.currentPos]
        inc(res.currentPos)

    return res

# TODO: rewrite
proc `iterator`*[T](this:HaxeArray[T]):HaxeIterator[T] =
    return newHaxeArrayIterator(this)

# --- Haxe Map --- 

const TABLE_INIT_SIZE = 64

# Haxe Map
template set*[K, V](this:HaxeMap[K, V], key:K, value:V) =
    this.data[key] = value

proc get*[K](this:HaxeMap[K, ValueType], key:K):Null[ValueType] =    
    if this.data.hasKey(key):
        return Null[ValueType](has: true, value: this.data[key])
    else:
        return Null[ValueType](has: false)

template get*[K, V](this:HaxeMap[K, V], key:K):V =
    if this.data.hasKey(key):
        this.data[key]
    else:
        nil

template `$`*[K, V](this:HaxeMap[K, V]) : string =
    $this.data

proc newStringMap*[T]() : HaxeStringMap[T] =
    result = HaxeStringMap[T]()
    result.data = initTable[string, T](TABLE_INIT_SIZE)

proc newIntMap*[T]() : HaxeIntMap[T] =
    result = HaxeIntMap[T]()
    result.data = initTable[int, T](TABLE_INIT_SIZE)

proc newObjectMap*[K, V]() : HaxeObjectMap[K, V] =
    result = HaxeObjectMap[K, V]()
    result.data = initTable[K, V](TABLE_INIT_SIZE)

# --- Dynamic ---

# AnonObject
proc newAnonObject*(names: seq[string]) : AnonObject {.inline.}  =
    result = newSeqOfCap[AnonField](names.len)    
    for i in 0..<names.len:
        result.add(AnonField(name: names[i]))

template newAnonObject*(fields: seq[AnonField]) : AnonObject =
    fields

proc newAnonField*(name:string, value:Dynamic) : AnonField {.inline.} =
    AnonField(name : name, value : value)

proc `{}=`*[T](this:AnonObject, pos:int, value:T) {.inline.} =
    this[pos].value = value

proc `{}=`*[T](this:AnonObject, name:string, value:T) {.inline.} =
    for fld in this:
        if fld.name == name:
            fld.value = value

template `{}`*(this:AnonObject, pos:int):Dynamic =
    this[pos].value

proc `{}`*(this:AnonObject, name:string):Dynamic =
    if this.len < 1:
        return nil

    for fld in this:
        if fld.name == name:
            return fld.value

    return nil

proc getFields*(this:AnonObject):HaxeArray[string] =
    result = HaxeArray[string]()
    for f in this:
        discard result.push(f.name)

# Dynamic 
proc `$`*(this:Dynamic):string =
    case this.kind
    of TString:
        return this.fstring
    of TInt:
        return $this.fint
    of TFloat:
        return $this.ffloat
    of TAnonObject:
        return $this[]
    of TClass:
        let fields = this.fclass.getFields()
        var data = newSeq[string]()
        for fld in fields.data:
            data.add(fld & ": " & $this.fclass.getFieldByName(fld))
        return $data
    else:
        return "Dynamic unknown"

template newDynamic*(value:string):Dynamic =
    Dynamic(kind:TString, fstring: value)

template newDynamic*(value:int32):Dynamic =
    Dynamic(kind:TInt, fint: value)

template newDynamic*(value:int):Dynamic =
    Dynamic(kind:TInt, fint: value.int32)

template newDynamic*(value:float):Dynamic =
    Dynamic(kind:TFloat, ffloat: value)

template newDynamic*(value:AnonObject):Dynamic =
    Dynamic(kind:TAnonObject, fanon: value)

template newDynamic*[T:DynamicHaxeObjectRef](value:T):Dynamic =
    mixin makeDynamic
    #let value = value
    echo value.getFields == nil
    if value.getFields == nil: makeDynamic(value)
    Dynamic(kind:TClass, fclass: value)

proc newDynamic*(value:pointer):Dynamic =
    Dynamic(kind:TPointer, fpointer: value)
    
proc `{}`*(this:Dynamic, name:string):Dynamic {.gcsafe.} =    
    case this.kind
    of TAnonObject:
        this.fanon{name}
    of TClass:
        this.fclass.getFieldByName(name)
    else:
        nil

proc `{}=`*(this:Dynamic, name:string, value: Dynamic) {.gcsafe.} =    
    case this.kind
    of TAnonObject:
        this.fanon{name}=value
    of TClass:
        this.fclass.setFieldByName(name, value)
    else:
        discard

proc `{}=`*[T](this:Dynamic, name:string, value: T) {.gcsafe.} =    
    case this.kind
    of TAnonObject:
        this.fanon{name}=newDynamic(value)
    of TClass:
        this.fclass.setFieldByName(name, newDynamic(value))
    else:
        discard


proc getFieldNames*(this:Dynamic):HaxeArray[string] {.gcsafe.} =
    case this.kind
    of TAnonObject:
        this.fanon.getFields()
    of TClass:
        this.fclass.getFields()
    else:
        nil

template call*[T](this:Dynamic, tp:typedesc[T], args:varargs[untyped]):untyped =    
    case this.kind
    of TPointer:
        var pr:T = cast[tp](this.fpointer)
        pr(args)
    else:
        raise newException(ValueError, "Dynamic wrong type")

template call*[T](this:Dynamic, name:string, tp:typedesc[T], args:varargs[untyped]):untyped =    
    case this.kind:
    of TAnonObject, TClass:
        this{name}.call(tp, args)
    else:
        raise newException(ValueError, "Dynamic wrong type")

converter toDynamic*[T: DynamicHaxeObjectRef](v:T): Dynamic {.inline.} = newDynamic(v)

template toDynamic*(this:untyped):untyped =
    newDynamic(this)

proc fromDynamic*[T](this:Dynamic, t:typedesc[T]) : T =
    case this.kind
        of TInt:
            when T is int32: this.fint
            elif T is float: this.fint.float
            elif T is string: $this.fint
            else: T.default
        of TString:
            when T is string: this.fstring
            else: T.default # $this
        of TFloat:
            when T is float: this.ffloat
            elif T is int32: int32(this.ffloat)
            elif T is string: $this.ffloat
            else: T.default
        of TClass:
            when T is DynamicHaxeObjectRef: 
                #echo this.fclass == nil
                cast[T](this.fclass)
            elif T is DynamicHaxeObject:
                if this.fclass != nil: cast[T](this.fclass) else: 
                    echo "null acces"
                    T.default
            else: 
                echo "warning ", t.name
                T.default
        else:
            raise newException(ValueError, "Dynamic wrong type")

template declDynaimcBinOp(op) =
    template op*[T:int32|float|int|string|bool](lhs: Dynamic, rhs:T): auto =
        when T is int: op(lhs.fromDynamic(int32), rhs.int32)
        else: op(lhs.fromDynamic(typeof T) , rhs)

    template op*[T:int32|float|int|string|bool](lhs: T, rhs: Dynamic): auto =
        when T is int: op(lhs.int32, rhs.fromDynamic(int32))
        else: op(lhs, rhs.fromDynamic(typeof T))

    template op*(lhs: Dynamic, rhs: Dynamic): Dynamic =
        toDynamic(op(lhs.fromDynamic(float),rhs.fromDynamic(float)))

declDynaimcBinOp(`*`)
declDynaimcBinOp(`-`)
declDynaimcBinOp(`/`)
declDynaimcBinOp(`+`)
declDynaimcBinOp(`and`)
declDynaimcBinOp(`or`)
declDynaimcBinOp(`&`)

template toFloat* (v:SomeInteger): float = float(v)

template toFloat*(v: Dynamic): float = v.fromDynamic(float)

template toFloat*(v: float): float = v

# --- Haxe Enum ---

# Enum
proc `$`*(this:HaxeEnum) : string =
    result = $this[]

proc `==`*(e1:HaxeEnum, e2:int) : bool {.inline.} =
    result = e1.index == e2

# --- closure hack ----
proc rawClosure* [T: proc](prc: pointer, env: pointer): T {.noSideEffect, inline.} =
  {.emit: """
  `result`->ClP_0 = `prc`;
  `result`->ClE_0 = `env`;
  """.}

#template rawClosure* [T: proc](prce: untyped, enve: untyped) =
#    let prc = cast[pointer](prce)
#    let env = cast[pointer](enve)
#    var closure : T
#    {.emit: """
#    `closure`->ClP_0 = `prc`;
#    `closure`->ClE_0 = `env`;
#    """.}
#    closure

import macros

macro `{}`*(f: typed, name: static string): auto =
    let xn = ident(name)
    let isdyn = ident("kind")
    let ft = getType(f)
    var tn = ft[1].strVal
    let ttn = ident(tn.substr(0, tn.find(":") - 1) & "Wrapper")
    let x = quote do:
        if `f`.`isdyn` == THaxe: `f`.`xn` else: cast[`ttn`](`f`).`xn`[] 
    return x

macro `{}=`* [T](f: typed, name: static string, value: T) =
    let xn = ident(name)
    let isdyn = ident("kind")
    let ft = getType(f)
    var tn = ft[1].strVal
    let ttn = ident(tn.substr(0, tn.find(":") - 1) & "Wrapper")
    let res = value.sameType(bindSym"int")
    if res:
        let xx = quote do:
            block:
                let v = `value`
                if `f`.`isdyn` == THaxe: 
                    `f`.`xn` = v.int32
                else: 
                    cast[`ttn`](`f`).`xn`[] = v.int32
        return xx
    else:
        let xx = quote do:
            block:
                let v = `value`
                if `f`.`isdyn` == THaxe: 
                    `f`.`xn` = v
                else: 
                    cast[`ttn`](`f`).`xn`[] = v
        return xx

template `{}`* (this: untyped, name: string): Dynamic =
    this.getFieldByName(name)
