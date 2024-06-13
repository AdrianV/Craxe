{.experimental: "codeReordering".}

import system/iterators
import tables
import typetraits
import strutils
import tools/tokenhash
import xstring

export tokenhash
export xstring


type
    String* = XString # system.string
    # Objects that can calculate self hash
    Hashable = concept x
        x.hash is proc():int

    # Dynamic
    DynamicType* = enum
        TNone, TAnonWrapper, TString, TInt, TFloat, TBool, TAnon, TClass, TEnum, TDynamic, TStatic, TFunc, TType
    FieldTypeKind* = enum
        ftNone, TField, TProperty, TMethod
    FieldType* = object
        case kind*: FieldTypeKind
        of ftNone: discard
        of TField:
            faddress*: pointer
            fkind*: DynamicType
        of TProperty:
            pgetter*: proc (this: ptr HaxeBaseObject): Dynamic {.cdecl.}
            psetter*: proc (this: ptr HaxeBaseObject): Dynamic {.cdecl.}
        of TMethod:
            mcall*: proc (this: ptr HaxeBaseObject, params: seq[Dynamic]): Dynamic {.cdecl.}
            mparams*: int
            
    # --- AnonNextGen ---

    AnonNextGenType* = enum
        atNone, atStaticBool, atStaticInt, atStaticFloat, atStaticString, atStaticArray, atStaticAnon, atStaticAnonWrapper, atStaticInstance, atDynamic

    AnonNextGen* = object
        case qanonType*: AnonNextGenType
        of atNone: discard 
        of atStaticBool, atStaticInt, atStaticFloat, atStaticString, atStaticArray, atStaticAnon, atStaticAnonWrapper, atStaticInstance:
            qstatic*: pointer
        of atDynamic:
            qdynamic*: Dynamic

    FieldTable* = TokenTable[AnonNextGen]

    # Root object for all haxe objects
    HaxeBaseObject* = object of RootObj
        qkind*: DynamicType

    TypeIndex* = distinct int32
    ClassAbstr*[T] = object
        qcidx*: TypeIndex
    EnumAbstr*[T] = object
        qcidx*: TypeIndex

    AnyClass* = ClassAbstr[HaxeObjectRef]
    AnyEnum* = EnumAbstr[HaxeEnum]

    FieldInfos = seq[tuple[name: string, field: FieldType]]
    # Root object for Static instances
    HaxeStaticObject* = object of HaxeBaseObject
        qparent*: ptr HaxeStaticObject
        # fields*: FieldTable
        qtype*: AnyClass
        qname*: string
        qfields*: FieldInfos
        qstaticFields*: FieldInfos
        # qgetFields*: proc(): seq[string]
        qtoString*: proc(o: HaxeObjectRef): String {.closure.}
        qcempty*: proc(cl: HaxeStaticObjectRef): HaxeObjectRef {.nimcall.}
        qcfun*: proc(cl: HaxeStaticObjectRef, params: seq[Dynamic]): HaxeObjectRef {.nimcall.}

    HaxeStaticObjectRef* = ref HaxeStaticObject

    HaxeEnumParamInfo* = object
        qname*: string
        qoffset*: pointer
        qget*: proc(this: pointer): Dynamic
        qset*: proc(this: pointer, v: Dynamic)
    HaxeEnumValueInfo* = object
        qname*: string
        qidx*: int32
        qparams*: seq[HaxeEnumParamInfo]
        qcval*: proc(): HaxeEnum {.nimcall.}
        qcfun*: proc(params: seq[Dynamic]): HaxeEnum {.nimcall.}

    HaxeEnumInfo* = object
        qtype*: TypeIndex
        qname*: string
        qvalues*: seq[HaxeEnumValueInfo]

    # Main object for all haxe referrence objects
    HaxeObject* = object of HaxeBaseObject
        qstatic* {.cursor.}: HaxeStaticObjectRef

    HaxeObjectRef* = ref HaxeObject

    # Value object
    Struct* = object of HaxeBaseObject


    HaxeValueType* = bool | int32 | float | object 

    Null*[T: HaxeValueType] = ref object of HaxeBaseObject
        value*: T


    NullAbstr*[T] = Null[T]

    # Dynamic object with access to fields by name
    DynamicHaxeObjectBase* = object of HaxeBaseObject
        qfields*: FieldTable

    DynamicHaxeObject* = object of DynamicHaxeObjectBase
        qtodyn*: proc (this: DynamicHaxeObjectRef) {.nimcall.}

    DynamicHaxeObjectRef* = ref DynamicHaxeObject

    DynamicHaxeWrapper* = ref object of DynamicHaxeObjectBase
        qinstance*: ref HaxeBaseObject # DynamicHaxeObjectRef

    # --- Haxe Iterator ---
    HaxeIterator*[T] = ref object of DynamicHaxeObject
        hasNext*:proc():bool
        next*:proc():T

    HaxeIt*[T] = object
        iter*: iterator(): T
        cur*: T

    # --- Haxe Array ---    

    HaxeArrayIterator*[T] = ref object of HaxeIterator[T]
        arr:HaxeArray[T]
        currentPos:int

    HaxeArray*[T] = ref object of HaxeObjectRef
        data*:seq[T]
        kind*: DynamicType

    # --- Haxe Map

    # Base map
    HaxeMap*[K, V] = ref object of HaxeObject
        kind*: DynamicType
        when K is String:
            data*: Table[string, V]
        else:
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
    HaxeStringMap*[T] = HaxeMap[String, T]

    # Haxe Int map
    HaxeIntMap*[T] = HaxeMap[int32, T]

    # Haxe object map
    HaxeObjectMap*[K: ref;V] = HaxeMap[int, tuple[k:K, v:V]]

    # --- Dynamic ---

    AnonField* = ref object
        name*:String
        value*:Dynamic

    # Dynamic proxy for real object
    DynamicHaxeObjectProxy*[T] = object of DynamicHaxeObject
        obj*:T

    DynamicHaxeObjectProxyRef*[T] = ref object of DynamicHaxeObjectProxy[T]

    DynProc* = proc(param: varargs[Dynamic, `toDynamic`]): Dynamic
    Dyn* = object
        case kind*: DynamicType
        of TNone: discard
        of TString: 
            fstring*: String
        of TInt: 
            fint*:int32
        of TFloat: 
            ffloat*:float
        of TBool:
            fbool*: bool
        of TAnonWrapper:
            fwrapper*: DynamicHaxeWrapper
        of TAnon: 
            fanon*: DynamicHaxeObjectRef
        of TClass: 
            fclass*: HaxeObjectRef
        of TEnum:
            fenum: HaxeEnum
        of TDynamic:
            discard
        of TStatic:
            fstatic: ptr HaxeStaticObject
        of TFunc:
            ffunc*: DynProc
        of TType:
            ftype*: TypeIndex

    Dynamic* = ref object of HaxeBaseObject
        q: Dyn

    # --- Haxe Enum ---

    # Haxe enum
    HaxeEnum* = ref object of HaxeBaseObject
        qinfo*: ptr HaxeEnumInfo
        qindex*: int32

    HaxeBaseType* = Dynamic | String | int32 | float | bool | DynamicHaxeWrapper | DynamicHaxeObjectRef | HaxeObjectRef | HaxeEnum

    NullAccess* = object of CatchableError

    Reflect* = object
    Type* = object


template unsafeDowncast*[A, B](v: B): A =
    cast[A](cast[pointer]((B) v))

const NO_TYPE = 0.TypeIndex

proc register* [T: HaxeObjectRef|String, S: HaxeStaticObjectRef](t: typedesc[T], hso: var S): int32 {.discardable.} 

var StringStaticInst* = HaxeStaticObjectRef(qkind: TStatic, qname: "String")
register(String, StringStaticInst)

proc getArrayLength(this: ptr HaxeBaseObject): Dynamic {.cdecl.}

var HaxeArrayStaticInst* = HaxeStaticObjectRef(qkind: TStatic, qname: "Array", 
    qfields: @[("length", FieldType(kind: TProperty, pgetter: getArrayLength))]
    )
register(HaxeArray[Dynamic], HaxeArrayStaticInst)


converter toAnyClass*[T: HaxeObjectRef | String ](v: typedesc[T]): ClassAbstr[T] {.inline.} =
    return ClassAbstr[T](qcidx: register(v).TypeIndex)

converter toAnyEnum*[T: HaxeEnum](v: typedesc[T]): EnumAbstr[T] {.inline.} =
    return EnumAbstr[T](qcidx: register(v).TypeIndex)


# Core procedures

template getKind*[T:HaxeBaseType](this: typedesc[T]): DynamicType =
    when T is Dynamic : TDynamic
    elif T is DynamicHaxeWrapper : TAnonWrapper
    elif T is String : TString
    elif T is int32 : TInt
    elif T is float : TFloat
    elif T is bool : TBool
    elif T is DynamicHaxeObjectRef : TAnon
    elif T is HaxeObjectRef : TClass
    elif T is HaxeEnum : TEnum
    else : {.fatal "Invalid T for getKind: " & this.name .}

template getKind*[T:Null[HaxeValueType]](this: typedesc[T]): DynamicType =
    getKind(this.T)

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

proc getDynamic(this: pointer, f: FieldType): Dynamic

proc `$`*(this:Dynamic): string


proc getFieldValuePairs(this: pointer, astatic: var HaxeStaticObject, useStatic: bool): string = 
    var res = ""
    if astatic.qparent != nil: 
        res = getFieldValuePairs(this, astatic.qparent[], useStatic)
    var first = res.len == 0
    proc buildPair(name: string, f: FieldType) =
        if f.kind != TMethod :
            let d = getDynamic(this, f)
            if not first : res &= ", "
            res &= name & ": " & (if d != nil : $d else: "nil")    
    if useStatic :
        for f in astatic.qstaticFields:
            buildPair(f.name, f.field)
    else:
        for f in astatic.qfields:
            buildPair(f.name, f.field)
    return res

proc toString*[T: HaxeObjectRef and not HaxeArray](this: T): String =
    if this == nil : return toXString("null")
    if not this.qstatic.isNil :
        if not this.qstatic.qtoString.isNil :
            return this.qstatic.qtoString(this)
        return this.qstatic[].qname & "(" & getFieldValuePairs(cast[pointer](this), this.qstatic[], false) & ")"
    return this.repr.toXString

when false:
    proc toString*[T](this: T): String =
        this.repr.toXString

# String
template length*(this: String) : int32 =
    len(this).int32

converter toValue* [T: HaxeValueType] (v:Null[T]): T {.inline.} =
    if not v.isNil: result = v.value

converter fromValue* [T: HaxeValueType](v:T): Null[T] {.inline.} =
    Null[T](value: v, qkind: 
        when T is bool: TBool
        elif T is int32: TInt
        elif T is float: TFloat
        elif T is object: TStatic
    ) 

converter fromValue* (v:int): Null[int32] {.inline.} =
    Null[int32](value: v.int32, qkind: TInt) 

when false:
    # String
    template charAt*(this:string, pos:int) : string =
        $this[pos]


    template indexOf* (s: String, sub: String): int32 =
        int32(s.find(sub))

    template indexOf* (s: String, sub: String, start: int32): int32 =
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

template `==`* (v1: String, n: typeof(nil)): bool =
    v1.isNil

#template `.`* [T](v: Null[T], f: untyped) =
#    v.value.f

#template `.=`* [T,V](v: var Null[T], f: untyped, val: V) =
#    v.value.`f` = val

#from macros import unpackVarargs

#template `.()`* [T](v: Null[T]; f: untyped, args: varargs[untyped]): untyped =
#  unpackVarargs(s.value.f, args)


#template `==`* [T] (v1:Null[T], n: typeof(nil)): bool =
#    isNil(v1.value)

template `==`* [T:HaxeValueType] (v1:Null[T], n: typeof(nil)): bool =
    v1.isNil

template `==`* [T:HaxeValueType](v1:Null[T], v2:T):bool =
    not v1.isNil and v1.value == v2

template `==`* [T:ref HaxeBaseObject](v1: T, n: typeof(nil)): bool =
    v1.isNil

template `==`* (v1: DynamicHaxeWrapper, v2: DynamicHaxeWrapper): bool =
    v1.qinstance == v2.qinstance

template `==`* [T: DynamicHaxeObjectRef | HaxeObjectRef](v1: DynamicHaxeWrapper, v2: T): bool =
    v1.qinstance == v2

template `==`* [T: DynamicHaxeObjectRef | HaxeObjectRef](v1: T, v2: DynamicHaxeWrapper): bool =
    v2.qinstance == v1

proc `$`* [T:HaxeValueType] (this:Null[T]):string =
    if this.isNil: "null"  else: $(this.value)

proc `==`*(v1:Hashable, v2:Hashable):bool =
    v1.hash() == v2.hash()

template hash*(this:HaxeObjectRef):int =
    cast[int](this)

proc `==`*[T:HaxeObjectRef](v1:T, v2:T):bool =
    v1.hash() == v2.hash()

template `==`*[T: HaxeValueType](v1:Null[T], v2:Null[T]):bool =
    let v1 = v1
    let v2 = v2
    return if not v1.isNil and not v2.isNil : v1.value == v2.value else : v1.isNil and v2.isNil


# Scoped block
template valueBlock*(body : untyped) : untyped = 
    (proc() : auto {.gcsafe.} = 
        body
    )()

# --- Operators ---

proc `|=`* (this: var int32, right: int32) {.inline.} =
    this = this or right

# --- Haxe Array ---

# HaxeArray

proc newHaxeArray*[T](kind: DynamicType, data: seq[T] = @[]): HaxeArray[T] {.inline.} = 
    HaxeArray[T](qkind: TClass, qstatic: HaxeArrayStaticInst ,kind: kind, data: data)
    
template `[]`*[T](this:HaxeArray[T], pos:int32): T =
    block:
        let data = addr this.data
        let x = pos
        if x >= 0 and x < data[].len: data[][x] else: T.default
    
template get*[T](this:HaxeArray[T], pos:int32):auto =
    block:
        let data = addr this.data
        let x = pos
        if x >= 0 and x < data[].len: data[][x] else: T.default

template `[]=`*[T](this:HaxeArray[T], pos:int32, v: T) =
    block:
        let x = pos
        if x >= 0 :
            var data = addr this.data
            if x >= data[].len: setLen(data[], x + 1)
            data[][x] = v

template set* [T] (this:HaxeArray[T], pos:int32, v: T) =
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

template pop*[T](this: HaxeArray[T]): T = 
    this.data.pop()

#template get*[T](this:HaxeArray[T], pos:int): T =
#    this.data[pos]

template length*[T](this:HaxeArray[T]): int32 =    
    this.data.len.int32

template `length=`*[T](this:HaxeArray[T], v: int32) =    
    this.data.setLen(v)

template resize*[T](this: HaxeArray[T], v: int32) = 
    this.data.setLen(v)

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

template kind*(this: Dynamic): DynamicType =
    this.q.kind

template dyn*(this: Dynamic): Dyn =
    this.q

template call*(this: Dynamic, args: varargs[Dynamic, `toDynamic`]): Dynamic =
    case this.q.kind :
    of TFunc: this.q.ffunc(args)
    else : raise newException(ValueError, "Dynamic is not a function")

proc getFields* (this: DynamicHaxeObjectRef): seq[string] =
    result = @[]
    for f in this.qfields:
        result.add($f.thash)

proc getFieldByName* (this: DynamicHaxeObjectRef | DynamicHaxeWrapper, name: string): Dynamic {.gcsafe.}
proc getFieldByName* (this: HaxeObjectRef, name: string): Dynamic 

proc setFieldByName* (this: DynamicHaxeObjectRef | DynamicHaxeWrapper, name:string, value:Dynamic):void 

when false:
    template typ[T](v: DynamicHaxeWrapper[T]): typedesc = T

    template makeDynamic*(value:DynamicHaxeWrapper[T]) =
        if value.instance.fields.len == 0: 
            makeDynamic(cast[T](value.instance))
            # fields = value.instance.fields

template checkDynamic*[T:DynamicHaxeObjectRef](value:T) =
    if value.qfields.len == 0 and not value.qtodyn.isNil: value.qtodyn(value)

proc toDynamic*(f: AnonNextGen): Dynamic =
    case f.qanonType :
    of atStaticBool: Dynamic(qkind: TDynamic, q: Dyn(kind: TBool, fbool: cast[ptr bool](f.qstatic)[]))
    of atStaticInt: Dynamic(qkind: TDynamic, q:Dyn(kind: TInt, fint: cast[ptr int32](f.qstatic)[]))
    of atStaticFloat: Dynamic(qkind: TDynamic, q:Dyn(kind: TFloat, ffloat: cast[ptr float](f.qstatic)[]))
    of atStaticString: Dynamic(qkind: TDynamic, q:Dyn(kind: TString, fstring: cast[ptr String](f.qstatic)[]))
    of atStaticArray: nil # TODO 
    of atStaticAnon: Dynamic(qkind: TDynamic, q:Dyn(kind: TAnon, fanon: cast[ptr DynamicHaxeObjectRef](f.qstatic)[]))
    of atStaticAnonWrapper: Dynamic(qkind: TDynamic, q:Dyn(kind: TAnonWrapper, fwrapper: cast[ptr DynamicHaxeWrapper](f.qstatic)[]))
    of atStaticInstance: nil # TODO
    of atDynamic: f.qdynamic
    of atNone: raise newException(ValueError, "cannot convert to Dynamic")

proc toString* [T:DynamicHaxeObjectRef](this: T): String
proc toString* [T:DynamicHaxeWrapper](this:T): String 
proc toString* [T: HaxeEnum](this: T): String 


# proc toString*[T:HaxeArray](this: T): String 
proc toString*[V](this: HaxeArray[V]): String 

template `$`*[T:DynamicHaxeObjectRef](this:T): String =
    checkDynamic(this)
    toString(this)


# Dynamic 

proc castArray[V;T: HaxeArray[V]](this: HaxeObjectRef, kind: DynamicType): T 
proc `[]`*(this: Dynamic, idx: int32): Dynamic 
proc adr* [T](this: DynamicHaxeObjectRef | DynamicHaxeWrapper, name:string): ptr T    

proc toStrImpl(this:Dynamic): string =
    if not this.isNil:
        case this.q.kind
        of TString:
            $this.q.fstring
        of TInt:
            $this.q.fint
        of TFloat:
            $this.q.ffloat
        of TBool:
            $this.q.fbool
        of TAnonWrapper:
            $toString(this.q.fwrapper)
        of TAnon:
            $toString(this.q.fanon)
        of TClass:
            let o = this.q.fclass 
            if not o.isNil:
                if o.qstatic.qtype.qcidx != HaxeArrayStaticInst.qtype.qcidx:
                    $toString(o)
                else :
                    let a = cast[HaxeArray[int32]](o)
                    case a.kind :
                    of TInt: $toString(cast[HaxeArray[int32]](o))
                    of TFloat: $toString(cast[HaxeArray[float]](o))
                    of TString: $toString(cast[HaxeArray[String]](o))
                    of TClass: $toString(cast[HaxeArray[HaxeObjectRef]](o))
                    of TAnonWrapper: $toString(cast[HaxeArray[DynamicHaxeWrapper]](o))
                    of TAnon: $toString(cast[HaxeArray[DynamicHaxeObjectRef]](o))
                    of TBool: $toString(cast[HaxeArray[bool]](o))
                    of TEnum: $toString(cast[HaxeArray[HaxeEnum]](o))
                    of TDynamic: $toString(cast[HaxeArray[Dynamic]](o))
                    of TStatic: "[...]"
                    of TFunc: "[...]"
                    of TType: "[..]"
                    of TNone: "[???]"
            else: "null"
        of TEnum:
            $toString(this.q.fenum)
        of TNone:
            "none"
        else:
            "Dynamic unknown"
    else: "null"

template toString*(this:Dynamic): String =
    toString(d.toStrImpl)

proc `$`*(this:Dynamic): string =
    return toStrImpl(this)

proc toString* [T:DynamicHaxeObjectRef](this: T): String =
    checkDynamic(this)
    var isFirst = true
    var res = "{"
    for f in this.qfields:
        if not isFirst: res &= ", "
        res &= $f.thash & ": " 
        let d = f.data.toDynamic
        res &= $d
        isFirst = false
    res &= "}"
    result = res.toXString

proc toString* [T:DynamicHaxeWrapper](this:T): String =
    #return toString(cast[typ(this)](this.instance))
    var isFirst = true
    var res = "{"
    for f in this.qfields:
        if not isFirst: res &= ", "
        res &= $f.thash & ": " & $f.data.toDynamic
        isFirst = false
    res &= "}"
    result = res.toXString

proc toString*[V](this: HaxeArray[V]): String =
    mixin toString
    var res = "["
    for x, v in this.data.pairs :
        if x > 0 : res &= ", "
        when compiles(toString(v)) :
            res &= $toString(v)
        else:
            res &= $v
    res &= "]"
    return res.toXString


template newDynamic*(value:bool):Dynamic =
    Dynamic(qkind: TDynamic, q:Dyn(kind:TBool, fbool: value))

template newDynamic*(value:String):Dynamic =
    Dynamic(qkind: TDynamic, q:Dyn(kind:TString, fstring: value))

template newDynamic*(value:int32):Dynamic =
    Dynamic(qkind: TDynamic, q:Dyn(kind:TInt, fint: value))

template newDynamic*(value:int):Dynamic =
    Dynamic(qkind: TDynamic, q:Dyn(kind:TInt, fint: value.int32))

template newDynamic*(value:float):Dynamic =
    Dynamic(qkind: TDynamic, q:Dyn(kind:TFloat, ffloat: value))

template newDynamic*(value:ptr HaxeStaticObject):Dynamic =
    Dynamic(qkind: TDynamic, q:Dyn(kind:TStatic, fstatic: value))

template newDynamic*(value: TypeIndex):Dynamic =
    Dynamic(qkind: TDynamic, q:Dyn(kind:TType, ftype: value))

#template newDynamic*(value: DynamicHaxeWrapper):Dynamic =
#    checkDynamic(value)
#    Dynamic(q:Dyn(kind:TAnonWrapper, fwrapper: value))

template newDynamic*[T: ref HaxeBaseObject](value: T):Dynamic =
    when T is Dynamic :
        value
    elif T is DynamicHaxeObjectRef:
        checkDynamic(value)
        # echo "TAnon"
        Dynamic(qkind: TDynamic, q:Dyn(kind:TAnon, fanon: value))
    elif T is DynamicHaxeWrapper:
        Dynamic(qkind: TDynamic, q:Dyn(kind:TAnonWrapper, fwrapper: value))
    elif T is HaxeEnum:
        Dynamic(qkind: TDynamic, q:Dyn(kind: TEnum, fenum: value))
    elif T is HaxeObjectRef :
        # echo "TClass ", value.isNil
        Dynamic(qkind: TDynamic, q:Dyn(kind:TClass, fclass: value))
    else :
        {.fatal "cannot convert T " & typedesc[T].name & " to Dynamic" .}


# template newDynamic*[T:DynamicHaxeObjectRef](value: T):Dynamic =

proc newDynamic*(value: DynProc):Dynamic =
    Dynamic(qkind: TDynamic, q:Dyn(kind:TFunc, ffunc: value))

template newDynamic*(value:ref Exception):Dynamic =
    Dynamic(qkind: TDynamic, q:Dyn(kind:TString, fstring: value.msg))


proc getFieldNames*(this:Dynamic): seq[string] =
    case this.q.kind
    of TAnon:
        return this.q.fanon.getFields()
    of TAnonWrapper:
        if this.q.fwrapper.qinstance of DynamicHaxeObjectRef:
            return cast[DynamicHaxeObjectRef](this.q.fwrapper.qinstance).getFields()
    of TClass:
        if this.q.fclass.qstatic != nil: 
            result = @[]
            for f in this.q.fclass.qstatic.qfields: result.add(f.name)
    else:
        discard

when false:
    template call*[T](this:Dynamic, tp:typedesc[T], args:varargs[untyped]):untyped =    
        case this.q.kind
        of TPointer:
            var pr:T = cast[tp](this.fpointer)
            pr(args)
        else:
            raise newException(ValueError, "Dynamic wrong type")

    template call*[T](this:Dynamic, name:string, tp:typedesc[T], args:varargs[untyped]):untyped =    
        case this.q.kind:
        of TAnon, TClass:
            this{name}.call(tp, args)
        else:
            raise newException(ValueError, "Dynamic wrong type")

proc asDynamic*(v: DynamicHaxeObjectRef): Dynamic {.inline.} = 
    Dynamic(qkind: TDynamic, q:Dyn(kind: TAnon, fanon: v))

converter toDynamic*[T: DynamicHaxeObjectRef](v:T): Dynamic {.inline.} = 
    newDynamic(v)

converter toDynamic*[T: DynamicHaxeWrapper](v: T): Dynamic {.inline.} = 
    return newDynamic(v)

converter toDynamic*(v: HaxeValueType or String or TypeIndex): Dynamic {.inline.} = 
    newDynamic(v)

converter toDynamic*(v: string): Dynamic = 
    newDynamic(v.toXString)

converter toDynamic*[T:HaxeObjectRef](value: T):Dynamic {.inline.} =
    newDynamic(value)

converter toDynamic*[T:HaxeEnum](value: T):Dynamic {.inline.} =
    newDynamic(value)

converter toDynamic*[T:var HaxeStaticObject](value: T):Dynamic {.inline.} =
    newDynamic(addr value)

converter toDynamic*[T:ptr HaxeStaticObject](value: T):Dynamic {.inline.} =
    newDynamic(value)


template toDynamic*(v: Dynamic): Dynamic = v

#template toDynamic*(this:untyped):untyped =
#    newDynamic(this)

template fromDynamic(this:Dynamic, T: typed, result: typed) =
    result = if this != nil : 
        case this.q.kind :
        of TInt: this.q.fint.T
        of TFloat: T(this.q.ffloat)
        of TBool: ord(this.q.fbool).T
        else: T.default
    else: T.default

proc fromDynamic*(this:Dynamic, t:typedesc[int32]) : int32 =
    fromDynamic(this, int32, result)

proc fromDynamic*(this:Dynamic, t:typedesc[float]) : float =
    fromDynamic(this, float, result)

proc fromDynamic*(this:Dynamic, t:typedesc[bool]) : bool =
    fromDynamic(this, bool, result)

proc fromDynamic*[V: bool | int32 | float](this:Dynamic, t:typedesc[Null[V]]) : V =
    fromDynamic(this, V, result)

proc fromDynamic*(this:Dynamic, t:typedesc[String]) : String =
    result = if this != nil : 
        case this.q.kind :
        of TString: this.q.fstring
        of TInt: ($this.q.fint).toXString
        of TFloat: ($this.q.ffloat).toXString
        of TBool: ($this.q.fbool).toXString
        else: nil
    else: nil

proc fromDynamic*[T:DynamicHaxeObjectRef|DynamicHaxeObject|DynamicHaxeWrapper](this:Dynamic, t:typedesc[T]) : T 

proc fromDynamic*[V;T: HaxeArray[V]](this:Dynamic, t:typedesc[T]) : T =
    # type T = typeof(t)
    result = if this != nil : 
        case this.q.kind :
        of TClass:
            castArray[V](this.q.fclass, this.q.kind)
        else: nil
    else: nil

proc fromDynamic*[T:HaxeObjectRef](this:Dynamic, t:typedesc[T]) : T =
    # type T = typeof(t)
    result = if this != nil : 
        case this.q.kind :
        of TClass:
            when T is HaxeArray:
                castArray[T.T, T](this.q.fclass, this.q.kind)
            else:
                cast[T](this.q.fclass)
        else: nil
    else: nil

proc fromDynamic*[T:HaxeEnum](this:Dynamic, t:typedesc[T]) : T =
    # type T = typeof(t)
    result = if this != nil : 
        case this.q.kind :
        of TEnum:
            cast[T](this.q.fenum)
        else: nil
    else: nil

proc fromDynamic* [T](this: Dynamic, t: typedesc[ClassAbstr[T]|EnumAbstr[T]]): TypeIndex = 
    return case this.q.kind :
    of TClass: this.q.fclass.qstatic.qtype.qcidx
    of TString: StringStaticInst.qtype.qcidx
    of TEnum: this.q.fenum.qinfo[].qtype
    of TStatic: this.q.fstatic[].qtype.qcidx
    of TType: this.q.ftype
    else: NO_TYPE

proc fromDynamic*[T:proc] (this: Dynamic, t: typedesc[T]): T =
    raise newException(Defect, "not implemented")
    

when false:
    proc fromDynamic*[T](this:Dynamic, t:typedesc[T]) : T =
        if this == nil:
            echo "null ! ", t.name
            return T.default
        else :  
            case this.kind
            of TInt:
                when T is int32: this.fint
                elif T is float: this.fint.float
                elif T is String: ($this.fint).toXString
                elif T is bool: this.fint > 0
                else: T.default
            of TString:
                when T is String: this.fstring
                elif T is bool: this.fstring == "true"
                else: T.default # $this
            of TFloat:
                when T is float: this.ffloat
                elif T is int32: int32(this.ffloat)
                elif T is String: ($this.ffloat).toXString
                elif T is bool: this.ffloat > 0
                else: T.default
            of TBool:
                when T is bool: this.fbool
                elif T is int32: ord(this.fbool).int32
                elif T is float: ord(this.fbool).float
                elif T is String: (if this.fbool: "true" else: "false").toXString
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
            of TClass:
                cast[T](this.fclass)
            of TEnum:
                cast[T](this.fenum)
            else:
                echo "Dynamic wrong type"
                # raise newException(ValueError, "Dynamic wrong type")
                T.default

proc castArray[V;T: HaxeArray[V]](this: HaxeObjectRef, kind: DynamicType): T =
    if this.qstatic.qtype.qcidx == HaxeArrayStaticInst.qtype.qcidx:
        result = case kind :
            of TBool: (when V is bool: cast[HaxeArray[V]](this) else: nil)
            of TInt: (when V is int32: cast[HaxeArray[V]](this) else: nil)
            of TFloat: (when V is float : cast[HaxeArray[float]](this) else: nil)
            of TString: (when V is String: cast[HaxeArray[V]](this) else: nil)
            of TClass: (when V is HaxeObjectRef: cast[HaxeArray[V]](this) else: nil)
            of TAnonWrapper: (when V is DynamicHaxeWrapper: cast[HaxeArray[V]](this) else: nil)
            of TAnon: (when V is DynamicHaxeObjectRef: cast[HaxeArray[V]](this) else: nil)
            of TEnum: (when V is HaxeEnum: cast[HaxeArray[V]](this) else: nil)
            of TDynamic: (when V is Dynamic: cast[HaxeArray[V]](this) else: nil)
            of TStatic: nil
            of TFunc: nil
            of TType: nil
            of TNone: nil
        if result.isNil: 
            if not (kind in {TStatic, TFunc, TType, TNone}):
                let a {.cursor.} = cast[HaxeArray[int32]](this)
                var res = newSeqOfCap[V](a.length)
                let d = Dynamic(qkind: TDynamic, q:Dyn(kind: TClass, fclass: this))
                for i in  0 ..< a.length:
                    let el = fromDynamic(d[i], V)
                    res.add(el)
                result = newHaxeArray[V](kind, res)

proc getDynamic(this: pointer, f: FieldType): Dynamic =
    case f.kind
    of TField: 
        var adr = cast[int](this) + cast[int](f.faddress)
        case f.fkind
        of TInt: return cast[ptr int32](adr)[].toDynamic
        of TBool: return cast[ptr bool](adr)[].toDynamic
        of TFloat: return cast[ptr float](adr)[].toDynamic
        of TAnon: 
            return Dynamic(qkind: TDynamic, q:Dyn(kind: TAnon, fanon: cast[ptr DynamicHaxeObjectRef](adr)[]))
        of TAnonWrapper: return cast[ptr DynamicHaxeWrapper](adr)[].toDynamic
        of TString: return cast[ptr String](adr)[].toDynamic
        of TClass: return cast[ptr HaxeObjectRef](adr)[].toDynamic
        of TEnum: return cast[ptr HaxeEnum](adr)[].toDynamic
        of TStatic: return cast[ptr HaxeStaticObject](adr)[].toDynamic
        of TDynamic: return cast[ptr Dynamic](adr)[]
        of TFunc: discard
        of TNone: discard
        of TType: return cast[ptr TypeIndex](adr)[].toDynamic
    of TProperty: 
        if not f.pgetter.isNil: 
            return f.pgetter(cast[ptr HaxeBaseObject](this))
    else: discard

proc getRef*(this: Dynamic) : ref HaxeBaseObject =
    if not this.isNil :
        case this.q.kind :
        of TDynamic: result = this
        of TAnon: result = this.q.fanon
        of TAnonWrapper: result = this.q.fwrapper
        of TClass: result = this.q.fclass
        of TEnum: result = this.q.fenum
        else: result = nil

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

proc `[]`*(this: Dynamic, idx: int32): Dynamic =
    #echo "[", idx, "] of ", this.q.repr
    case this.q.kind:
    of TClass:
        if this.q.fclass.qstatic == HaxeArrayStaticInst:
            let a {.cursor.} = cast[HaxeArray[int32]](this.q.fclass) 
            #echo idx
            case a.kind:
            of TInt: return a[idx]
            of TFloat: return cast[HaxeArray[float]](a)[idx]
            of TString: return cast[HaxeArray[String]](a)[idx]
            of TClass: return cast[HaxeArray[HaxeObjectRef]](a)[idx]
            of TAnonWrapper: return cast[HaxeArray[DynamicHaxeWrapper]](a)[idx]
            of TAnon: 
                let v = cast[HaxeArray[DynamicHaxeObjectRef]](a)[idx]
                checkDynamic(v)
                return v.toDynamic
            of TBool: return cast[HaxeArray[bool]](a)[idx]
            of TEnum: return cast[HaxeArray[HaxeEnum]](a)[idx]
            of TDynamic: return cast[HaxeArray[Dynamic]](a)[idx]
            #of TPointer: discard #return cast[HaxeArray[pointer]](a)[idx]
            #of THaxe: discard
            else: discard
            
    else: discard

template toFloat*(v:SomeInteger): float = float(v)
template toFloat*(vp:Null[int32]): float = 
    let v {.gensym.} = vp
    if not v.isNil : float(v.value) else : float.default

#template toFloat*(v: Dynamic): float = v.fromDynamic(float)

template toFloat*(v: float): float = v

# --- Haxe Enum ---

# Enum

template getValueInfo(this: ptr HaxeEnumInfo, idx: int32): ptr HaxeEnumValueInfo =
    if idx >= 0 and idx < this[].qvalues.len and this[].qvalues[idx].qidx == idx :
        addr this[].qvalues[idx]
    else : nil

proc getValueInfo(this: ptr HaxeEnumInfo, name: string): ptr HaxeEnumValueInfo =
    for vi in this[].qvalues.mitems:
        if vi.qname == name : return addr vi

proc toString*[T: HaxeEnum](this: T): String =
    if (this.qinfo != nil) :
        let vinfo = getValueInfo(this.qinfo, this.qindex)
        if vinfo == nil : return "<Error>".toXString
        var res = vinfo[].qname & (if cast[pointer](vinfo[].qcval) == nil: "(" else: "")
        var isFirst = true
        for i, p in vinfo[].qparams.mpairs :
            if p.qget.isNil : continue
            if not isFirst : res &= ", "
            isFirst = false
            #res &= p.qname & ": "
            let pfield = cast[pointer](cast[int](this) + cast[int](p.qoffset))
            let dyn = p.qget(pfield)
            res &= $fromDynamic(dyn, String)
        if cast[pointer](vinfo[].qcval) == nil:
            res &= ")"
        return res.toXString
    return this.repr.toXString

proc `$`*(this:HaxeEnum) : string =
    result = $toString(this)

proc `==`*(e1:HaxeEnum, e2:int32) : bool {.inline.} =
    result = e1.qindex == e2

# --- closure hack ----
proc rawClosure* [T: proc {.closure.}](prc: pointer, env: pointer): T {.noSideEffect, inline.} =
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
                    when `f`.`n` is ptr :
                        `f`.`n`[]
                    else:
                        `f`.`n`
                else :
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
                # echo "by set"
                setFieldByName(`f`, extractName(`name`), `value`.toDynamic)

template `{}`* [T: DynamicHaxeWrapper | DynamicHaxeObjectRef | DynamicHaxeObject](f: T, name: static[string]): auto =
    bind dot
    # echo "by dot"
    dot(f, name)

template `{}`* [T](f: HaxeIt[T], name: static[string]): auto =
    bind dot
    # echo "by dot"
    dot(f, name)

template `{}=`* [T:DynamicHaxeWrapper | DynamicHaxeObjectRef](f: T, name: static[string], value: typed) =
    bind dotSet
    dotSet(f, name, value)


proc `{}`*(this:Dynamic, name:string):Dynamic  =    
    # echo "by Dynamic ", name, " ", this.q.kind
    case this.q.kind
    of TAnonWrapper :
        this.q.fwrapper.getFieldByName(name)
    of TAnon:
        #this.q.fanon{name}
        this.q.fanon.getFieldByName(name)
    of TClass:
        when compiles(this.q.fclass.getFieldByName(name)):
            this.q.fclass.getFieldByName(name)
        else: nil
    else:
        nil

template `[]`*(this:Dynamic, name:string):Dynamic =
    bind `{}`
    `{}`(this, name)

proc `{}=`*(this:Dynamic, name:string, value: Dynamic) =    
    case this.q.kind
    of TAnon:
        #this.q.fanon{name}=value
        this.q.fanon.setFieldByName(name, value)
    of TClass:
        when compiles(this.q.fclass.setFieldByName(name, value)):
            this.q.fclass.setFieldByName(name, value)
        else: discard
    else:
        discard

proc `{}=`*[T](this:Dynamic, name:string, value: T) =    
    case this.q.kind
    of TAnon:
        #this.q.fanon{name}=newDynamic(value)
        this.q.fanon.setFieldByName(name, newDynamic(value))
    of TClass:
        when compiles(this.q.fclass.setFieldByName(name, newDynamic(value))):
            this.q.fclass.setFieldByName(name, newDynamic(value))
        else: discard
    else:
        discard


proc fromDynamic*[T:DynamicHaxeObjectRef|DynamicHaxeObject|DynamicHaxeWrapper](this:Dynamic, t:typedesc[T]) : T =
    #type T = typeof(t)
    if this != nil : 
        case this.q.kind :
        of TAnon: 
            when T is DynamicHaxeObjectRef: 
                result = cast[T](this.q.fanon)
            elif T is DynamicHaxeObject:
                if this.q.fanon != nil: result = cast[T](this.q.fanon) else: 
                    echo "null acces"
        of TAnonWrapper:
            when T is DynamicHaxeWrapper:
                result = cast[T](this.q.fwrapper)
            elif T is DynamicHaxeObjectRef:
                # is the qinstance of the wrapper a T Anon ?
                if not this.q.fwrapper.qinstance.isNil and this.q.fwrapper.qinstance of T:
                    result = cast[T](this.q.fwrapper.qinstance)
                else:
                    #echo "not working ", t.name
                    # build the Anon from the Wrapper
                    result = T(qkind: TAnon)
                    for k, v in result[].fieldPairs:
                        when typeof(v) is (HaxeValueType | String | ref HaxeBaseObject ) :
                            result.a = 132
                            let f = this.q.fwrapper.qfields.get(k)
                            if not f.isNil:
                                #echo k, " = ", f[].toDynamic
                                result.qfields.insert(k, fromField(result{k}))
                                result{k} = f[].toDynamic.fromDynamic(typeof(v))
                                #echo k, ": ", v
            else :
                if cast[DynamicHaxeObjectBase](this.q.fwrapper) of T:
                    result = cast[T](this.q.fwrapper)
                else:
                    echo "warning ", t.name
        else: discard

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

proc get(this: var HaxeStaticObject, name: string): ptr FieldType =
    for f in iterators.mitems(this.qfields):
        if f.name == name : return addr f.field

proc getFieldByName* (this: DynamicHaxeObjectRef | DynamicHaxeWrapper, name:string): Dynamic {.gcsafe.} =
    let f = this.qfields.get(name)
    if f != nil :
        return f[].toDynamic

proc setFieldByName* (this: DynamicHaxeObjectRef | DynamicHaxeWrapper, name:string, value:Dynamic):void = 
    let f = this.qfields.setOrInsert(name, AnonNextGen(qanonType: atDynamic, qdynamic: value))
    if f != nil :
        case f[].qanonType :
        of atStaticBool: cast[ptr bool](f[].qstatic)[] = fromDynamic(value, bool)
        of atStaticInt: cast[ptr int32](f[].qstatic)[] = fromDynamic(value, int32)
        of atStaticFloat: cast[ptr float](f[].qstatic)[] = fromDynamic(value, float)
        of atStaticString: cast[ptr String](f[].qstatic)[] = fromDynamic(value, String)
        of atStaticArray: discard # TODO 
        of atStaticAnon: cast[ptr DynamicHaxeObjectRef](f[].qstatic)[] = fromDynamic(value, DynamicHaxeObjectRef)
        of atStaticAnonWrapper: cast[ptr DynamicHaxeWrapper](f[].qstatic)[] = fromDynamic(value, DynamicHaxeWrapper)
        of atStaticInstance: discard # TODO
        of atDynamic: f[].qdynamic = value
        of atNone: raise newException(ValueError, name & " has no Dynamic type")

proc adr* [T](this: DynamicHaxeObjectRef | DynamicHaxeWrapper, name:string): ptr T = 
    let f = this.qfields.get(name)
    if f != nil :
        case f[].qanonType:
        of atDynamic: 
            case f[].qdynamic.kind:
            of TInt: 
                when T is int32: return cast[ptr int32](addr f[].qdynamic.q.fint)
            of TFloat:    
                when T is float: return cast[ptr float](addr f[].qdynamic.q.ffloat)
            of TString:    
                when T is String: return cast[ptr String](addr f[].qdynamic.q.fstring)
            of TBool:    
                when T is bool: return cast[ptr bool](addr f[].qdynamic.q.fbool)
            else: raise newException(ValueError, "Dynamic wrong type") 
        of atStaticBool:
            when T is bool: return cast[ptr T](f[].qstatic)
        of atStaticInt:
            when T is int32: return cast[ptr T](f[].qstatic)
        of atStaticFloat:
            when T is float: return cast[ptr T](f[].qstatic)
        of atStaticString:
            when T is String: return cast[ptr T](f[].qstatic)
        of atStaticAnon:
            when T is DynamicHaxeObjectRef: return cast[ptr T](f[].qstatic)
        of atStaticAnonWrapper:
            when T is DynamicHaxeWrapper: return cast[ptr T](f[].qstatic)
        of atStaticArray:
            when T is HaxeArray: return cast[ptr T](f[].qstatic)
        of atStaticInstance:
            when T is HaxeObjectRef: return cast[ptr T](f[].qstatic)
        of atNone:
            raise newException(ValueError, "unknown Dynamic has no address")
    echo "anon has no field " & name & " of type " & T.name
    #return nil
    raise newException(NullAccess, "anon has no field " & name & " of type " & T.name)

proc fromField* [T](field: var T): AnonNextGen =
    when T is bool: AnonNextGen(qanonType: atStaticBool, qstatic: addr field)
    elif T is int32: AnonNextGen(qanonType: atStaticInt, qstatic: addr field)
    elif T is float: AnonNextGen(qanonType: atStaticFloat, qstatic: addr field)
    elif T is String: AnonNextGen(qanonType: atStaticString, qstatic: addr field)
    elif T is HaxeArray: AnonNextGen(qanonType: atStaticArray, qstatic: addr field)
    elif T is DynamicHaxeObjectRef: AnonNextGen(qanonType: atStaticAnon, qstatic: addr field)
    elif T is DynamicHaxeWrapper: AnonNextGen(qanonType: atStaticAnonWrapper, qstatic: addr field)
    elif T is Dynamic: AnonNextGen(qanonType: atDynamic, qdynamic: field)
    elif T is HaxeObjectRef: AnonNextGen(qanonType: atStaticInstance, qstatic: addr field)
    else: raise newException(ValueError, "Anon wrong type " & typeof(T).name)


# ------------------------- Reflect ---------------------------------------------------------
# TODO: handle changed names properly

var nimFixed: Table[string, string]

template fix*(k: string, v: string) =
    nimFixed[k] = v
    
proc fixName*(name: string): string =
    let name = name
    let fix = nimFixed.getOrDefault(name)
    return if fix == "" : name else : fix

template fixName*(name: String): string =
    fixName($name)

proc native*(name: string): string =
    let fix = nimFixed.getOrDefault(":" & name)
    return if fix == "" : name else : fix

proc hasField*(this: typedesc[Reflect], o: DynamicHaxeObjectRef | DynamicHaxeWrapper, name: String): bool =
    when o is DynamicHaxeObjectRef:
        checkDynamic(o)
    return o.qfields.get(fixName(name)) != nil

proc field*(this: typedesc[Reflect], o: DynamicHaxeObjectRef | DynamicHaxeWrapper, name: String): Dynamic =
    when o is DynamicHaxeObjectRef:
        checkDynamic(o)
    return getFieldByName(o, fixName(name))

proc fields*(this: typedesc[Reflect], o: DynamicHaxeObjectRef | DynamicHaxeWrapper): HaxeArray[String] =
    when o is DynamicHaxeObjectRef:
        checkDynamic(o)
    var res = newSeqOfCap[String](o.qfields.len)
    for f in o.qfields: 
        let s = native($f.thash)
        res.add(newASCIIString(s))
    result = newHaxeArray[String](TString, res)

proc setField*(this: typedesc[Reflect], o: DynamicHaxeObjectRef | DynamicHaxeWrapper, name: String, value:Dynamic): void =
    when o is DynamicHaxeObjectRef:
        checkDynamic(o)
    setFieldByName(o, name.fixName, value)

proc compare*(this: typedesc[Reflect], a,b: int32): int32 {.inline.} = 
    return a - b

proc compare*(this: typedesc[Reflect], a,b: String|string): int32 {.inline.} = 
    return cmp($a, $b).int32

proc compare*(this: typedesc[Reflect], a,b: float): int32 {.inline.} = 
    return cmp(a, b).int32

proc compare*(this: typedesc[Reflect], a,b: bool): int32 {.inline.} = 
    return cmp(a, b).int32

proc compare*(this: typedesc[Reflect], a,b: Dynamic): int32 = 
    template cantCompare(): int32 = -1
    case a.kind:
    of TInt: 
        if b.kind == TInt : return cmp(a.q.fint, b.q.fint).int32
        if b.kind == TFloat : return cmp(a.q.fint.float, b.q.ffloat).int32
    of TFloat:    
        if b.kind == TFloat : return cmp(a.q.ffloat, b.q.ffloat).int32
        if b.kind == TInt : return cmp(a.q.ffloat, b.q.fint.float).int32
    of TString:    
        if b.kind == TString : return cmp(a.q.fstring, b.q.fstring).int32
    of TBool:    
        if b.kind == TBool : return cmp(a.q.fbool, b.q.fbool).int32
    of TEnum:
        if b.kind == TEnum and a.q.fenum.qinfo == b.q.fenum.qinfo :
            return cmp(a.q.fenum.qindex, b.q.fenum.qindex).int32
    else: 
        discard
    return cantCompare()


proc getFieldByName* (this: HaxeObjectRef, name:string): Dynamic =
    let f = this.qstatic[].get(name)
    if f != nil :
        return getDynamic(cast[pointer](this), f[])



when false:
    type
        EnumAbstr*[T: HaxeEnum|Dynamic] = T
        ClassAbstrBase* = HaxeObjectRef|Dynamic|String
        ClassAbstr*[T: ClassAbstrBase] = distinct int32


type

    ValueType* = ref object of HaxeEnum

    ValueTypeTUnknown* = ref object of ValueType
    ValueTypeTObject* = ref object of ValueType
    ValueTypeTNull* = ref object of ValueType
    ValueTypeTInt* = ref object of ValueType
    ValueTypeTFunction* = ref object of ValueType
    ValueTypeTFloat* = ref object of ValueType
    ValueTypeTEnum* = ref object of ValueType
        e* : TypeIndex

    ValueTypeTClass* = ref object of ValueType
        c* : TypeIndex

    ValueTypeTBool* = ref object of ValueType

    HaxeTypeInfo = ref object
        name: string
        case kind: DynamicType 
        of TClass:
            qstatic: ptr HaxeStaticObjectRef
        of TEnum:
            fenum: ptr HaxeEnumInfo
        else: discard

proc `==` *(x, y: TypeIndex): bool {.borrow.}

template `==`* [T: HaxeObjectRef](x: TypeIndex, y: ClassAbstr[T]): bool =
    x.int32 == y.qcidx.int32

template `==`* [T: HaxeObjectRef](x: ClassAbstr[T], y: ClassAbstr[T]): bool =
    x.qcidx.int32 == y.qcidx.int32

template `==`* [T:HaxeObjectRef](x: ClassAbstr[T], y: typeof(nil)): bool =
    x.qcidx.int32 == NO_TYPE.int32

template `==`* [T:HaxeEnum](x: EnumAbstr[T], y: typeof(nil)): bool =
    x.qcidx.int32 == NO_TYPE.int32

var allTypes*: seq[HaxeTypeInfo]

proc addType(): int32 =
    let res = if allTypes.len == 0: 
        allTypes = newSeqOfCap[HaxeTypeInfo](100)
        1'i32 
    else: allTypes.len.int32
    allTypes.setLen(res + 1)
    # allTypes.add(HaxeTypeInfo(name: name, kind: TClass))
    return res

proc register* [T: HaxeObjectRef|String|HaxeEnum](t: typedesc[T]): int32 =
    var id {.global.} = addType()
    # echo id, " => ", t.name
    return id

proc register* [T: HaxeObjectRef|String, S: HaxeStaticObjectRef](t: typedesc[T], hso: var S): int32 {.discardable.} =
    let id = register(t)
    allTypes[id] = HaxeTypeInfo(name: t.name, kind: TClass, qstatic: cast[ptr HaxeStaticObjectRef](addr hso))
    hso[].qtype.qcidx = id.TypeIndex
    hso[].qkind = TStatic
    #hso[].qname = allTypes[id].name
    return id

proc register*[T: HaxeEnum] (t: typedesc[T], hei: ptr HaxeEnumInfo): int32 {.discardable.} =
    let id = register(t)
    allTypes[id] = HaxeTypeInfo(name: t.name, kind: TEnum, fenum: hei)
    hei[].qtype = id.TypeIndex
    return id

proc getTypeInfo*(id: int32): HaxeTypeInfo {.inline.} =
    if id > 0 and id < allTypes.len : result = allTypes[id]
    else : result = nil

proc getStatic*(id: int32): HaxeStaticObjectRef {.inline.} =
    if id > 0 and id < allTypes.len and allTypes[id].kind == TClass : result = allTypes[id].qstatic[]
    else : result = nil

proc getEnum*(id: int32): ptr HaxeEnumInfo {.inline.} =
    if id > 0 and id < allTypes.len and allTypes[id].kind == TEnum : result = allTypes[id].fenum
    else : result = nil

proc newValueTypeTUnknown() : ValueTypeTUnknown {.inline.} =
    ValueTypeTUnknown(qindex: 8)

proc `$`(this: ValueTypeTUnknown) : string {.inline.} =
    return $this[]

proc `==`(e1:ValueTypeTUnknown, e2:ValueTypeTUnknown) : bool {.inline.} =
    result = e1[] == e2[]

proc newValueTypeTObject() : ValueTypeTObject {.inline.} =
    ValueTypeTObject(qindex: 4)

proc `$`(this: ValueTypeTObject) : string {.inline.} =
    return $this[]

proc `==`(e1:ValueTypeTObject, e2:ValueTypeTObject) : bool {.inline.} =
    result = e1[] == e2[]

proc newValueTypeTNull() : ValueTypeTNull {.inline.} =
    ValueTypeTNull(qindex: 0)

proc `$`(this: ValueTypeTNull) : string {.inline.} =
    return $this[]

proc `==`(e1:ValueTypeTNull, e2:ValueTypeTNull) : bool {.inline.} =
    result = e1[] == e2[]

proc newValueTypeTInt() : ValueTypeTInt {.inline.} =
    ValueTypeTInt(qindex: 1)

proc `$`(this: ValueTypeTInt) : string {.inline.} =
    return $this[]

proc `==`(e1:ValueTypeTInt, e2:ValueTypeTInt) : bool {.inline.} =
    result = e1[] == e2[]

proc newValueTypeTFunction() : ValueTypeTFunction {.inline.} =
    ValueTypeTFunction(qindex: 5)

proc `$`(this: ValueTypeTFunction) : string {.inline.} =
    return $this[]

proc `==`(e1:ValueTypeTFunction, e2:ValueTypeTFunction) : bool {.inline.} =
    result = e1[] == e2[]

proc newValueTypeTFloat() : ValueTypeTFloat {.inline.} =
    ValueTypeTFloat(qindex: 2)

proc `$`(this: ValueTypeTFloat) : string {.inline.} =
    return $this[]

proc `==`(e1:ValueTypeTFloat, e2:ValueTypeTFloat) : bool {.inline.} =
    result = e1[] == e2[]

proc newValueTypeTEnum(e: TypeIndex) : ValueTypeTEnum {.inline.} =
    ValueTypeTEnum(qindex: 7, e: e)

proc `$`(this: ValueTypeTEnum) : string {.inline.} =
    return $this[]

proc `==`(e1:ValueTypeTEnum, e2:ValueTypeTEnum) : bool {.inline.} =
    result = e1[] == e2[]

proc newValueTypeTClass* (c: TypeIndex) : auto =
    ValueTypeTClass(qindex: 6, c: c)

proc `$`(this: ValueTypeTClass) : string {.inline.} =
    return $this[]

proc `==`(e1:ValueTypeTClass, e2:ValueTypeTClass) : bool {.inline.} =
    result = e1[] == e2[]

proc newValueTypeTBool() : ValueTypeTBool {.inline.} =
    ValueTypeTBool(qindex: 3)

proc `$`(this: ValueTypeTBool) : string {.inline.} =
    return $this[]

proc `==`(e1:ValueTypeTBool, e2:ValueTypeTBool) : bool {.inline.} =
    result = e1[] == e2[]

template getClass*[T: HaxeObjectRef](this: typedesc[Type], c: T): ClassAbstr[T] =
    if c != nil :
        cast[ClassAbstr[T]](c.qstatic[].qtype)
    else :
        ClassAbstr[T](qcidx: 0.TypeIndex)

template getClass*[T: HaxeObjectRef](this: typedesc[Type], c: typedesc[T]): ClassAbstr[T] =
    ClassAbstr[T](qcidx: register(c).TypeIndex)

proc allEnums*[T: HaxeEnum](this: typedesc[Type], e: EnumAbstr[T]): HaxeArray[HaxeEnum] =
    let stat = getEnum(e.qcidx.int32)
    if not stat.isNil :
        result = newHaxeArray[HaxeEnum](TEnum)
        for vi in stat[].qvalues.mitems :
            if cast[pointer](vi.qcval) != nil :
                discard result.push(vi.qcval())

proc getEnumConstructs*(this: typedesc[Type], c: AnyEnum): HaxeArray[String] =
    var res: seq[String] = @[]
    let stat = getEnum(c.qcidx.int32)
    if not stat.isNil :
        for f in stat[].qvalues.mitems:
            res.add(newASCIIString(f.qname))
    newHaxeArray[String](TString, res)

#proc allEnums*[T: HaxeEnum](this: typedesc[Type], e: typedesc[T]): HaxeArray[HaxeEnum] =
#    return Type.allEnums(register(e).TypeIndex)

when false:
    proc createEmptyInstance*[T: HaxeObjectRef](this: typedesc[Type], cl: ClassAbstr[T]): T =
        let c = register(cl)
        let stat = getStatic(cl.qcidx.int32)
        if stat != nil :
            result = cast[T](stat[].qcempty(stat))

proc createEmptyInstance* [T: HaxeObjectRef](this: typedesc[Type], cl: ClassAbstr[T]): T =
    let stat {.cursor.} = getStatic(cl.qcidx.int32)
    if not stat.isNil :
        result = cast[T](stat[].qcempty(stat))

proc createEnum*[T: HaxeEnum](this: typedesc[Type], cl: EnumAbstr[T], constr:String, params: HaxeArray[Dynamic] = nil):T =
    let stat = getEnum(cl.qcidx.int32)
    if stat != nil :
        let vi = getValueInfo(stat, $constr)
        if cast[pointer](vi.qcval) != nil : return cast[T](vi.qcval())
        else:
            return cast[T](vi.qcfun(params.data))

proc createEnumIndex*[T: HaxeEnum](this: typedesc[Type], cl: typedesc[T], index: int32, params: HaxeArray[Dynamic] = nil):T =
    let e = register(cl)
    let ti = allTypes[e.int32]
    if ti.kind == TEnum :
        let vi = getValueInfo(ti.fenum, index)
        if cast[pointer](vi.qcval) != nil : return cast[T](vi.qcval())
        else:
            return cast[T](vi.qcfun(params.data))

when false:
    converter toType*[T: HaxeObjectRef](cl: typedesc[T]): ClassAbstr[T] {.inline.} =
        ClassAbstr[T](qcidx: register(cl).TypeIndex)

proc createInstance*[T: HaxeObjectRef](this: typedesc[Type], cl: ClassAbstr[T], args: HaxeArray[Dynamic]):T =
    let stat = getStatic(cl.qcidx.int32)
    if not stat.isNil :
        result = cast[T](stat[].qcfun(stat, if args == nil: @[] else: args.data))

template createInstance*[T: HaxeObjectRef](this: typedesc[Type], cl: typedesc[T], args: HaxeArray[Dynamic]):T =
    Type.createInstance(Type.getClass(cl), args)
    

proc enumConstructor*(this: typedesc[Type], e:HaxeEnum): String =
    if e != nil : 
        result = e.qinfo[].qvalues[e.qindex].qname

proc enumIndex*(this: typedesc[Type], e:HaxeEnum): int32 {.inline.} =
    return e.qindex

proc enumParameters*(this: typedesc[Type], e:HaxeEnum): HaxeArray[Dynamic] =
    let vinfo = getValueInfo(e.qinfo, e.qindex)
    if vinfo == nil : return nil
    var res = newSeqOfCap[Dynamic](vinfo[].qparams.len)
    for p in vinfo[].qparams.mitems :
        if p.qget.isNil : continue
        let pfield = cast[pointer](cast[int](e) + cast[int](p.qoffset))
        let dyn = p.qget(pfield)
        res.add(dyn)
    return newHaxeArray[Dynamic](TDynamic, res)


proc enumEq*(this: typedesc[Type], a: HaxeEnum, b: HaxeEnum): bool =
    if a == b : return true
    if a == nil or b == nil : return false
    if a.qinfo == b.qinfo and a.qindex == b.qindex :
        let vinfo = getValueInfo(a.qinfo, a.qindex)
        if vinfo == nil : return false
        for p in vinfo[].qparams.mitems :
            if p.qget.isNil : return false
            let afield = cast[pointer](cast[int](a) + cast[int](p.qoffset))
            let bfield = cast[pointer](cast[int](b) + cast[int](p.qoffset))
            let adyn = p.qget(afield)
            let bdyn = p.qget(bfield)
            if adyn != nil and bdyn != nil :
                if adyn.q.kind == TEnum and bdyn.q.kind == TEnum :
                    if not Type.enumEq(adyn.q.fenum, bdyn.q.fenum) : return false
                else :
                    if Reflect.compare(adyn, bdyn) != 0 : return false
            elif adyn != nil or bdyn != nil : return false
        return true
    return false


proc getTypeof*(this: typedesc[Type], v: Dynamic) : ValueType =
    if v == nil : return newValueTypeTNull()
    return case v.kind :
    of TString: 
        let cidx = StringStaticInst.qtype.qcidx
        newValueTypeTClass(cidx)
    of TInt: newValueTypeTint()
    of TFloat: newValueTypeTFloat()
    of TBool: newValueTypeTBool()
    of TAnonWrapper: newValueTypeTObject()
    of TAnon:  newValueTypeTObject()
    of TStatic: newValueTypeTObject()
    of TClass: 
        let cidx = if v.q.fclass != nil and v.q.fclass.qstatic != nil: v.q.fclass.qstatic.qtype.qcidx else: NO_TYPE
        newValueTypeTClass(cidx)
    of TEnum: 
        let cidx = if v.q.fenum.qinfo != nil : v.q.fenum.qinfo.qtype else : NO_TYPE
        newValueTypeTEnum(cidx)
    of TDynamic : newValueTypeTUnknown()
    of TFunc : newValueTypeTFunction()
    of TNone : newValueTypeTUnknown()
    of TType :
        let stat = getTypeInfo(v.q.ftype.int32)
        if stat.isNil : newValueTypeTNull()
        else :
            if stat[].kind == TClass: newValueTypeTClass(v.q.ftype)
            elif stat[].kind == TEnum: newValueTypeTEnum(v.q.ftype)
            else: newValueTypeTUnknown()

proc typeof*(this: typedesc[Type], v: Dynamic) : ValueType =
    getTypeof(this, v)

proc getClassFields* [T:HaxeObjectRef](this: typedesc[Type], c: ClassAbstr[T]): HaxeArray[String] =
    var res: seq[String] = @[]
    let stat = getStatic(c.qcidx.int32)
    if stat != nil :
        for f in stat[].qstaticFields:
            if f.field.kind == TField :
                res.add(newASCIIString(f.name))
    newHaxeArray[String](TString, res)

proc getInstanceFields*[T:HaxeObjectRef](this: typedesc[Type], c: ClassAbstr[T]): HaxeArray[String] =
    var res: seq[String] = @[]
    var stat = getStatic(c.qcidx.int32)
    while not stat.isNil :
        for f in stat[].qfields:
            if f.field.kind == TField :
                res.add(newASCIIString(f.name))
        stat = stat[].qparent
    newHaxeArray[String](TString, res)

proc getClassName*[T](this: typedesc[Type], v: ClassAbstr[T]) : String =
    let stat = getStatic(v.qcidx.int32)
    if stat != nil: return stat[].qname

proc getClassName*(this: typedesc[Type], v: Dynamic) : String =
    if v.kind == TClass :
        let fclass = v.q.fclass
        let cidx = if fclass != nil and fclass.qstatic != nil: fclass.qstatic.qtype.qcidx else: NO_TYPE
        let stat = getStatic(cidx.int32)
        if stat != nil: return stat[].qname

proc getEnumName*(this: typedesc[Type], v: TypeIndex) : String =
    let enu = getEnum(v.int32)
    if enu != nil: return enu[].qname

proc getEnumName*(this: typedesc[Type], v: Dynamic) : String =
    if v.kind == TClass :
        let fclass = v.q.fclass
        let cidx = if fclass != nil and fclass.qstatic != nil: fclass.qstatic.qtype else: NO_TYPE
        let enu = getEnum(cidx.int32)
        if enu != nil: return enu[].qname

proc getSuperClass*[T: HaxeObjectRef](this: typedesc[Type], c: ClassAbstr[T]) : AnyClass =
    let stat = getStatic(c.qcidx.int32)
    if stat != nil and stat.qparent != nil: 
        result = stat[].qparent[].qtype
    else : 
        result = AnyClass(qcidx: NO_TYPE)

proc resolveClass*(this: typedesc[Type], name: String) : AnyClass =
    for i in 1 ..< allTypes.len :
        let ti = allTypes[i]
        if ti.kind == TClass and ti.qstatic[].qname == $name : return AnyClass(qcidx: i.TypeIndex)
    return AnyClass(qcidx: NO_TYPE)

proc resolveEnum*(this: typedesc[Type], name: String) : AnyEnum =
    for i in 1 ..< allTypes.len :
        let ti = allTypes[i]
        if ti.kind == TEnum and ti.fenum[].qname == $name : return AnyEnum(qcidx: i.TypeIndex)
    return AnyEnum(qcidx: NO_TYPE)

proc charCodeAt*(this: XString, index: int32): Null[int32] =
    let bx = this.getRunePos(index)
    if bx >= 0 :
        result = Null[int32](value: this.getRuneAtBytePos(bx).int32)

proc getArrayLength(this: ptr HaxeBaseObject): Dynamic {.cdecl.} = 
    return cast[HaxeArray[int32]](this).length.toDynamic

