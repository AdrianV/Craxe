{.experimental: "codeReordering".}

import tables
import typetraits
import strutils
import tools.tokenhash

export tokenhash

type
    # Objects that can calculate self hash
    Hashable = concept x
       x.hash is proc():int

    # Dynamic
    DynamicType* = enum
        THaxe, TAnonWrapper, TString, TInt, TFloat, TBool, TAnonObject, TClass, TPointer

    # --- AnonNextGen ---

    AnonNextGenType* = enum
        atStaticBool, atStaticInt, atStaticFloat, atStaticString, atStaticArray, atStaticAnon, atStaticInstance, atDynamic

    AnonNextGen* = object
        case fanonType*: AnonNextGenType
        of atStaticBool, atStaticInt, atStaticFloat, atStaticString, atStaticArray, atStaticAnon, atStaticInstance:
            fstatic*: pointer
        of atDynamic:
            fdynamic*: Dynamic

    FieldTable* = TokenTable[AnonNextGen]

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

    # Dynamic object with access to fields by name
    DynamicHaxeObject* = object of HaxeObject
        fields*: FieldTable

    DynamicHaxeObjectRef* = ref DynamicHaxeObject

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

    # Dynamic proxy for real object
    DynamicHaxeObjectProxy*[T] = object of DynamicHaxeObject
        obj*:T

    DynamicHaxeObjectProxyRef*[T] = ref object of DynamicHaxeObjectProxy[T]

    Dynamic* = ref object 
        case kind*: DynamicType
        of THaxe, TAnonWrapper: discard
        of TString: 
            fstring*: system.string
        of TInt: 
            fint*:int32
        of TFloat: 
            ffloat*:float
        of TBool:
            fbool*: bool
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

    NullAccess* = object of CatchableError

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
    
template `[]`*[T](this:HaxeArray[T], pos:Natural): T =
    block:
        let data = addr this.data
        let x = pos
        if x >= 0 and x < data[].len: data[][x] else: T.default
    
template get*[T](this:HaxeArray[T], pos:Natural):auto =
    block:
        let data = addr this.data
        let x = pos
        if x >= 0 and x < data[].len: data[][x] else: T.default

template `[]=`*[T](this:HaxeArray[T], pos:Natural, v: T) =
    block:
        let x = pos
        if x >= 0 :
            var data = addr this.data
            if x >= data[].len: setLen(data[], x + 1)
            data[][x] = v

template set* [T] (this:HaxeArray[T], pos:Natural, v: T) =
    block:
        let x = pos
        if x >= 0 :
            var data = addr this.data
            if x >= data[].len: setLen(data[], x + 1)
            data[][x] = v

    
template push*[T](this:HaxeArray[T], value:T):int32 =
    block:
        let data = addr this.data
        data[].add(value)
        len(data[]).int32

template pop*[T](this:var HaxeArray[T]): T = this.data.pop()

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

proc getFields* (this: DynamicHaxeObjectRef): HaxeArray[string] =
    result = HaxeArray[string]()
    for f in this.fields:
        discard result.push($f.thash)

proc getFieldByName* (this: DynamicHaxeObjectRef, name:string): Dynamic {.gcsafe.}

proc setFieldByName* (this: DynamicHaxeObjectRef, name:string, value:Dynamic):void 

template checkDynamic*[T:DynamicHaxeObjectRef](value:T) =
    mixin makeDynamic
    if value.fields.len == 0: makeDynamic(value)

template toDynamic*(f: AnonNextGen): Dynamic =
    case f.fanonType :
    of atStaticBool: Dynamic(kind: TBool, fbool: cast[ptr bool](f.fstatic)[])
    of atStaticInt: Dynamic(kind: TInt, fint: cast[ptr int32](f.fstatic)[])
    of atStaticFloat: Dynamic(kind: TFloat, ffloat: cast[ptr float](f.fstatic)[])
    of atStaticString: Dynamic(kind: TString, fstring: cast[ptr string](f.fstatic)[])
    of atStaticArray: nil # TODO 
    of atStaticAnon: Dynamic(kind: TClass, fclass: cast[ptr DynamicHaxeObjectRef](f.fstatic)[])
    of atStaticInstance: nil # TODO
    of atDynamic: f.fdynamic

proc toString[T:DynamicHaxeObjectRef](this:T): string

template `$`*[T:DynamicHaxeObjectRef](this:T): string =
    checkDynamic(this)
    toString(this)

# Dynamic 
    
proc `$`*(this:Dynamic):string =
    if not this.isNil:
        case this.kind
        of TString:
            this.fstring
        of TInt:
            $this.fint
        of TFloat:
            $this.ffloat
        of TBool:
            $this.fbool
        of TAnonObject:
            $this[]
        of TClass:
            toString(this.fclass)
        else:
            "Dynamic unknown"
    else: "null"

proc toString[T:DynamicHaxeObjectRef](this:T): string =
    var isFirst = true
    result = "{"
    for f in this.fields:
        if not isFirst: result &= ", "
        result &= $f.thash & ": " & $f.data.toDynamic
        isFirst = false
    result &= "}"

template newDynamic*(value:bool):Dynamic =
    Dynamic(kind:TBool, fbool: value)

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
    checkDynamic(value)
    Dynamic(kind:TClass, fclass: value)

proc newDynamic*(value:pointer):Dynamic =
    Dynamic(kind:TPointer, fpointer: value)

template newDynamic*(value:ref Exception):Dynamic =
    Dynamic(kind:TString, fstring: value.msg)

proc `{}`*(this:Dynamic, name:string):Dynamic {.gcsafe.} =    
    case this.kind
    of TAnonObject:
        this.fanon{name}
    of TClass:
        this.fclass.getFieldByName(name)
    else:
        nil

proc `{}=`*(this:Dynamic, name:string, value: Dynamic) =    
    case this.kind
    of TAnonObject:
        this.fanon{name}=value
    of TClass:
        this.fclass.setFieldByName(name, value)
    else:
        discard

proc `{}=`*[T](this:Dynamic, name:string, value: T) =    
    case this.kind
    of TAnonObject:
        this.fanon{name}=newDynamic(value)
    of TClass:
        this.fclass.setFieldByName(name, newDynamic(value))
    else:
        discard


proc getFieldNames*(this:Dynamic):HaxeArray[string] =
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
            elif T is bool: this.fint > 0
            else: T.default
        of TString:
            when T is string: this.fstring
            elif T is bool: this.fstring == "true"
            else: T.default # $this
        of TFloat:
            when T is float: this.ffloat
            elif T is int32: int32(this.ffloat)
            elif T is string: $this.ffloat
            elif T is bool: this.ffloat > 0
            else: T.default
        of TBool:
            when T is bool: this.fbool
            elif T is int32: ord(this.fbool).int32
            elif T is float: ord(this.fbool).float
            elif T is string: (if this.fbool: "true" else: "false")
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

proc getFieldByName* (this: DynamicHaxeObjectRef, name:string): Dynamic {.gcsafe.} =
    let f = this.fields.get(name)
    if f != nil :
        return f[].toDynamic
    
proc setFieldByName* (this: DynamicHaxeObjectRef, name:string, value:Dynamic):void = 
    let f = this.fields.setOrInsert(name, AnonNextGen(fanonType: atDynamic, fdynamic: value))
    if f != nil :
        case f[].fanonType :
        of atStaticBool: cast[ptr bool](f[].fstatic)[] = fromDynamic(value, bool)
        of atStaticInt: cast[ptr int32](f[].fstatic)[] = fromDynamic(value, int32)
        of atStaticFloat: cast[ptr float](f[].fstatic)[] = fromDynamic(value, float)
        of atStaticString: cast[ptr string](f[].fstatic)[] = fromDynamic(value, string)
        of atStaticArray: discard # TODO 
        of atStaticAnon: cast[ptr DynamicHaxeObjectRef](f[].fstatic)[] = fromDynamic(value, DynamicHaxeObjectRef)
        of atStaticInstance: discard # TODO
        of atDynamic: f[].fdynamic = value

proc adr* [T](this: DynamicHaxeObjectRef, name:string): ptr T = 
    let f = this.fields.get(name)
    if f != nil :
        case f[].fanonType:
        of atDynamic: 
            case f[].fdynamic.kind:
            of TInt: 
                when T is int32: return cast[ptr int32](addr f[].fdynamic.fint)
            of TFloat:    
                when T is float: return cast[ptr float](addr f[].fdynamic.ffloat)
            of TString:    
                when T is string: return cast[ptr string](addr f[].fdynamic.fstring)
            of TBool:    
                when T is bool: return cast[ptr bool](addr f[].fdynamic.fbool)
            else: discard
        of atStaticBool:
            when T is bool: return cast[ptr T](f[].fstatic)
        of atStaticInt:
            when T is int32: return cast[ptr T](f[].fstatic)
        of atStaticFloat:
            when T is float: return cast[ptr T](f[].fstatic)
        of atStaticString:
            when T is string: return cast[ptr T](f[].fstatic)
        of atStaticAnon:
            when T is DynamicHaxeObjectRef: return cast[ptr T](f[].fstatic)
        of atStaticArray:
            when T is HaxeArray: return cast[ptr T](f[].fstatic)
        of atStaticInstance:
            when T is HaxeObjectRef: return cast[ptr T](f[].fstatic)
    raise newException(NullAccess, "anon has no field " & name & " of type " & T.name)

proc fromField* [T](field: var T): AnonNextGen =
    when T is bool: AnonNextGen(fanonType: atStaticBool, fstatic: addr field)
    elif T is int32: AnonNextGen(fanonType: atStaticInt, fstatic: addr field)
    elif T is float: AnonNextGen(fanonType: atStaticFloat, fstatic: addr field)
    elif T is string: AnonNextGen(fanonType: atStaticString, fstatic: addr field)
    elif T is HaxeArray: AnonNextGen(fanonType: atStaticArray, fstatic: addr field)
    elif T is DynamicHaxeObjectRef: AnonNextGen(fanonType: atStaticAnon, fstatic: addr field)
    elif T is Dynamic: AnonNextGen(fanonType: atDynamic, fdynamic: field)
    elif T is HaxeObjectRef: AnonNextGen(fanonType: atStaticInstance, fstatic: addr field)
