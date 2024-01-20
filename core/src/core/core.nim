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
        THaxe, TAnonWrapper, TString, TInt, TFloat, TBool, TAnon, TClass, TPointer

    # --- AnonNextGen ---

    AnonNextGenType* = enum
        atStaticBool, atStaticInt, atStaticFloat, atStaticString, atStaticArray, atStaticAnon, atStaticAnonWrapper, atStaticInstance, atDynamic

    AnonNextGen* = object
        case fanonType*: AnonNextGenType
        of atStaticBool, atStaticInt, atStaticFloat, atStaticString, atStaticArray, atStaticAnon, atStaticAnonWrapper, atStaticInstance:
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
    DynamicHaxeObjectBase* = object of HaxeObject
        fields*: FieldTable

    DynamicHaxeObject* = object of DynamicHaxeObjectBase

    DynamicHaxeObjectRef* = ref DynamicHaxeObject

    DynamicHaxeWrapper* = ref object of DynamicHaxeObjectBase
        instance*: DynamicHaxeObjectRef

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

    # HaxeKeyValue*[K,V] = ref object of HaxeObject
    #    key*: K
    #    value*: V

    # when false :
    #    HaxeKeyValueWrapper*[K, V] = ref object of DynamicHaxeObject
    #        instance: DynamicHaxeObjectRef
    #        key: ptr K
    #        value: ptr V

    # Haxe String map
    HaxeStringMap*[T] = HaxeMap[string, T]

    # Haxe Int map
    HaxeIntMap*[T] = HaxeMap[int32, T]

    # Haxe object map
    HaxeObjectMap*[K, V] = HaxeMap[K, V]

    # --- Dynamic ---

    AnonField* = ref object
        name*:string
        value*:Dynamic

    # Dynamic proxy for real object
    DynamicHaxeObjectProxy*[T] = object of DynamicHaxeObject
        obj*:T

    DynamicHaxeObjectProxyRef*[T] = ref object of DynamicHaxeObjectProxy[T]

    Dynamic* = ref object 
        case kind*: DynamicType
        of THaxe: discard
        of TString: 
            fstring*: system.string
        of TInt: 
            fint*:int32
        of TFloat: 
            ffloat*:float
        of TBool:
            fbool*: bool
        of TAnonWrapper:
            fwrapper: DynamicHaxeWrapper
        of TAnon: 
            fanon*: DynamicHaxeObjectRef
        of TClass: 
            fclass*: HaxeObjectRef
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

proc toString*[T](this: T):string =
    this.repr

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

template indexOf* (s: string, sub: string): int32 =
    int32(s.find(sub))

template indexOf* (s: string, sub: string, start: int32): int32 =
    int32(s.find(sub), start)

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
    let v1 = v1
    let v2 = v2
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

const TABLE_INIT_SIZE = 32

# Haxe Map
template set*[K, V](this:HaxeMap[K, V], key:K, value:V) =
    this.data[key] = value

proc get*[K](this:HaxeMap[K, ValueType], key:K):Null[ValueType] =    
    if this.data.hasKey(key):
        return Null[ValueType](value: this.data[key])
    else:
        return nil

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
    result.data = initTable[int32, T](TABLE_INIT_SIZE)

proc newObjectMap*[K, V]() : HaxeObjectMap[K, V] =
    result = HaxeObjectMap[K, V]()
    result.data = initTable[K, V](TABLE_INIT_SIZE)

    
# --- Dynamic ---

when false:
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

proc getFields* (this: DynamicHaxeObjectRef): HaxeArray[string] =
    result = HaxeArray[string]()
    for f in this.fields:
        discard result.push($f.thash)

proc getFieldByName* (this: DynamicHaxeObjectRef | DynamicHaxeWrapper, name:string): Dynamic {.gcsafe.}

proc setFieldByName* (this: DynamicHaxeObjectRef | DynamicHaxeWrapper, name:string, value:Dynamic):void 

when false:
    template typ[T](v: DynamicHaxeWrapper[T]): typedesc = T

    template makeDynamic*(value:DynamicHaxeWrapper[T]) =
        if value.instance.fields.len == 0: 
            makeDynamic(cast[T](value.instance))
            # fields = value.instance.fields

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
    of atStaticAnon: Dynamic(kind: TAnon, fanon: cast[ptr DynamicHaxeObjectRef](f.fstatic)[])
    of atStaticAnonWrapper: Dynamic(kind: TAnonWrapper, fwrapper: cast[ptr DynamicHaxeWrapper](f.fstatic)[])
    of atStaticInstance: nil # TODO
    of atDynamic: f.fdynamic

proc toString* [T:DynamicHaxeObjectRef](this:T): string

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
        of TAnon:
            toString(this.fanon)
        of TClass:
            toString(this.fclass)
        else:
            "Dynamic unknown"
    else: "null"

proc toString* [T:DynamicHaxeObjectRef](this:T): string =
    var isFirst = true
    result = "{"
    for f in this.fields:
        if not isFirst: result &= ", "
        result &= $f.thash & ": " & $f.data.toDynamic
        isFirst = false
    result &= "}"

proc toString* [T:DynamicHaxeWrapper](this:T): string =
    #return toString(cast[typ(this)](this.instance))
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

template newDynamic*(value: DynamicHaxeWrapper):Dynamic =
    checkDynamic(value)
    Dynamic(kind:TAnonWrapper, fwrapper: value)

template newDynamic*[T:HaxeObjectRef](value: T):Dynamic =
    when T is DynamicHaxeObjectRef:
        checkDynamic(value)
        Dynamic(kind:TAnon, fanon: value)
    else:
        Dynamic(kind:TClass, fclass: value)

# template newDynamic*[T:DynamicHaxeObjectRef](value: T):Dynamic =

proc newDynamic*(value:pointer):Dynamic =
    Dynamic(kind:TPointer, fpointer: value)

template newDynamic*(value:ref Exception):Dynamic =
    Dynamic(kind:TString, fstring: value.msg)


proc getFieldNames*(this:Dynamic):HaxeArray[string] =
    case this.kind
    of TAnon:
        this.fanon.getFields()
    of TClass:
        #this.fclass.getFields()
        nil
    else:
        nil

when false:
    template call*[T](this:Dynamic, tp:typedesc[T], args:varargs[untyped]):untyped =    
        case this.kind
        of TPointer:
            var pr:T = cast[tp](this.fpointer)
            pr(args)
        else:
            raise newException(ValueError, "Dynamic wrong type")

    template call*[T](this:Dynamic, name:string, tp:typedesc[T], args:varargs[untyped]):untyped =    
        case this.kind:
        of TAnon, TClass:
            this{name}.call(tp, args)
        else:
            raise newException(ValueError, "Dynamic wrong type")

converter toDynamic*[T: DynamicHaxeObjectRef](v:T): Dynamic {.inline.} = 
    newDynamic(v)

converter toDynamic*[T: DynamicHaxeWrapper](v: T): Dynamic {.inline.} = 
    return newDynamic(v)

template toDynamic*(this:untyped):untyped =
    newDynamic(this)

proc fromDynamic*[T](this:Dynamic, t:typedesc[T]) : T =
    if this == nil:
        echo "null ! ", t.name
        return T.default
    else :  
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
        of TAnon:
            when T is DynamicHaxeObjectRef: 
                #echo this.fclass == nil
                cast[T](this.fanon)
            elif T is DynamicHaxeObject:
                if this.fanon != nil: cast[T](this.fanon) else: 
                    echo "null acces"
                    T.default
            else: 
                echo "warning ", t.name
                T.default
        of TAnonWrapper:
            when T is DynamicHaxeWrapper:
                cast[T](this.fwrapper)
            else :
                echo "warning ", t.name
                T.default
        else:
            echo "Dynamic wrong type"
            # raise newException(ValueError, "Dynamic wrong type")
            T.default

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

macro extractName*(name: untyped): auto =
    if name.kind in {nnkStrLit, nnkIdent} :
        let n = name.strVal
        return quote do : `n`
    macros.error("not a string literal", name)

macro `dot`* (f: untyped, name: untyped): auto =
    if name.kind in {nnkStrLit, nnkIdent} :
        let n = ident(name.strVal)
        return quote do:
            when compiles(`f`.`n`) :
                when `f` is DynamicHaxeWrapper:
                    `f`.`n`[]
                else:
                    `f`.`n`
            else :
                getFieldByName(`f`, extractName(`name`))

macro `dotSet`* (f: untyped, name: untyped, value: untyped): auto =
    # echo "dot= ", value.treeRepr
    if name.kind in {nnkStrLit, nnkIdent} :
        let n = ident(name.strVal)
        return quote do:
            when compiles(`f`.`n`) :
                block :                    
                    when `f` is DynamicHaxeWrapper:
                        let fp = `f`.`n`
                        if not fp.isNil: fp[] = `value` else: setFieldByName(`f`, extractName(`name`), `value`.toDynamic)
                    else:
                        `f`.`n` = `value`
            else :
                echo "by set"
                setFieldByName(`f`, extractName(`name`), `value`.toDynamic)

template `{}`* [T: DynamicHaxeWrapper | DynamicHaxeObjectRef | DynamicHaxeObject](f: T, name: static[string]): auto =
    bind dot
    # echo "by dot"
    dot(f, name)

template `{}=`* [T:DynamicHaxeWrapper | DynamicHaxeObjectRef](f: T, name: static[string], value: typed) =
    bind dotSet
    dotSet(f, name, value)


proc `{}`*(this:Dynamic, name:string):Dynamic {.gcsafe.} =    
    echo "by Dynamic ", name
    case this.kind
    of TAnonWrapper :
        this.fwrapper.getFieldByName(name)
    of TAnon:
        #this.fanon{name}
        this.fanon.getFieldByName(name)
    of TClass:
        when compiles(this.fclass.getFieldByName(name)):
            this.fclass.getFieldByName(name)
        else: nil
    else:
        nil

proc `{}=`*(this:Dynamic, name:string, value: Dynamic) =    
    case this.kind
    of TAnon:
        #this.fanon{name}=value
        this.fanon.setFieldByName(name, value)
    of TClass:
        when compiles(this.fclass.setFieldByName(name, value)):
            this.fclass.setFieldByName(name, value)
        else: discard
    else:
        discard

proc `{}=`*[T](this:Dynamic, name:string, value: T) =    
    case this.kind
    of TAnon:
        #this.fanon{name}=newDynamic(value)
        this.fanon.setFieldByName(name, newDynamic(value))
    of TClass:
        when compiles(this.fclass.setFieldByName(name, newDynamic(value))):
            this.fclass.setFieldByName(name, newDynamic(value))
        else: discard
    else:
        discard


when false:
    template `{}`*(f: typed, name: untyped): auto =
        when compiles(cast[typ(f)](f.instance).`name`):
            cast[typ(f)](f.instance).`name` 
        else: 
            getFieldByName(f, `name`)

when false:
    macro `{}`*(f: typed, name: static string): auto =
        let xn = ident(name)
        let isdyn = ident("kind")
        let ft = getType(f)
        echo ft.lispRepr    
        var tn = ft[1].strVal
        #let ttn = ident(tn.substr(0, tn.find(":") - 1) & "Wrapper")
        let x = quote do:
            block:
                let f = `f`
                # echo f.`isdyn` 
                when compiles(cast[typ(f)](f.instance).`xn`):
                    cast[typ(f)](f.instance).`xn`
                else: 
                    getFieldByName(f, `xn`)
        # echo x.treeRepr
        return x

when false:
    template `{}=`*(f: typed, name: untyped, value: typed) =
        when compiles(cast[typ(f)](f.instance).`name`):
            cast[typ(f)](f.instance).`name` = value
        else: 
            setFieldByName(f, `name`, value)
        

when false:
    macro `{}=`* [T](f: typed, name: static string, value: T) =
        let xn = ident(name)
        let isdyn = ident("kind")
        let ft = getType(f)
        echo ft.lispRepr, name    
        #var tn = ft[1].strVal
        #let ttn = ident(tn.substr(0, tn.find(":") - 1) & "Wrapper")
        echo getType(value)
        let res = value.sameType(bindSym"int")
        if res:
            let xx = quote do:
                block:
                    let v = `value`.int32
                    let f = `f`
                    when compiles(cast[typ(f)](f.instance).`xn`):
                        cast[typ(f)](f.instance).`xn` = v
                    else: 
                        setFieldByName(f, `name`, newDynamic(v))
            return xx
        else:
            let xx = quote do:
                block:
                    let v = `value`
                    let f = `f`
                    when compiles(cast[typ(f)](f.instance).`xn`):
                        cast[typ(f)](f.instance).`xn` = v
                    else: 
                        setFieldByName(f, `name`, newDynamic(v))
            return xx
when false:
    template `{}`* (this: untyped, name: string): Dynamic =
        this.getFieldByName(name)

proc getFieldByName* (this: DynamicHaxeObjectRef | DynamicHaxeWrapper, name:string): Dynamic {.gcsafe.} =
    let f = this.fields.get(name)
    if f != nil :
        return f[].toDynamic
    
proc setFieldByName* (this: DynamicHaxeObjectRef | DynamicHaxeWrapper, name:string, value:Dynamic):void = 
    let f = this.fields.setOrInsert(name, AnonNextGen(fanonType: atDynamic, fdynamic: value))
    if f != nil :
        case f[].fanonType :
        of atStaticBool: cast[ptr bool](f[].fstatic)[] = fromDynamic(value, bool)
        of atStaticInt: cast[ptr int32](f[].fstatic)[] = fromDynamic(value, int32)
        of atStaticFloat: cast[ptr float](f[].fstatic)[] = fromDynamic(value, float)
        of atStaticString: cast[ptr string](f[].fstatic)[] = fromDynamic(value, string)
        of atStaticArray: discard # TODO 
        of atStaticAnon: cast[ptr DynamicHaxeObjectRef](f[].fstatic)[] = fromDynamic(value, DynamicHaxeObjectRef)
        of atStaticAnonWrapper: cast[ptr DynamicHaxeWrapper](f[].fstatic)[] = fromDynamic(value, DynamicHaxeWrapper)
        of atStaticInstance: discard # TODO
        of atDynamic: f[].fdynamic = value

proc adr* [T](this: DynamicHaxeObjectRef | DynamicHaxeWrapper, name:string): ptr T = 
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
        of atStaticAnonWrapper:
            when T is DynamicHaxeWrapper: return cast[ptr T](f[].fstatic)
        of atStaticArray:
            when T is HaxeArray: return cast[ptr T](f[].fstatic)
        of atStaticInstance:
            when T is HaxeObjectRef: return cast[ptr T](f[].fstatic)
    echo "anon has no field " & name & " of type " & T.name
    #return nil
    raise newException(NullAccess, "anon has no field " & name & " of type " & T.name)

proc fromField* [T](field: var T): AnonNextGen =
    when T is bool: AnonNextGen(fanonType: atStaticBool, fstatic: addr field)
    elif T is int32: AnonNextGen(fanonType: atStaticInt, fstatic: addr field)
    elif T is float: AnonNextGen(fanonType: atStaticFloat, fstatic: addr field)
    elif T is string: AnonNextGen(fanonType: atStaticString, fstatic: addr field)
    elif T is HaxeArray: AnonNextGen(fanonType: atStaticArray, fstatic: addr field)
    elif T is DynamicHaxeObjectRef: AnonNextGen(fanonType: atStaticAnon, fstatic: addr field)
    elif T is DynamicHaxeWrapper: AnonNextGen(fanonType: atStaticAnonWrapper, fstatic: addr field)
    elif T is Dynamic: AnonNextGen(fanonType: atDynamic, fdynamic: field)
    elif T is HaxeObjectRef: AnonNextGen(fanonType: atStaticInstance, fstatic: addr field)

