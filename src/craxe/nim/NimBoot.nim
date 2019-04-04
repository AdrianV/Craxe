proc apOperator*[T](val:var T):T {.discardable, inline.} =        
    result = val
    inc(val)

proc bpOperator*[T](val:var T):T {.discardable, inline.} =        
    inc(val)
    result = val

template `+`*(s:string, i:untyped): string =
    s & $i

template `+`*(i:untyped, s:string): string =
    $i & s

template `+`*(s1:string, s2:string): string =
    s1 & s2

type
    StdStatic* = ref object of RootObj
    LogStatic* = ref object of RootObj

    HaxeEnum* = ref object of RootObj
        index*:int

    HaxeArray*[T] = ref object of RootObj
        data*:seq[T]

let LogStaticInst* = LogStatic()
let StdStaticInst* = StdStatic()

template trace*(this:LogStatic, v:untyped, e:varargs[string, `$`]):void =
    write(stdout, e[0] & " " & e[1] & ": ")
    echo v

template string*(this:StdStatic, v:untyped): string =
    $v    

proc `$`*(this:HaxeEnum) : string =
    result = $this[]

proc `==`*(e1:HaxeEnum, e2:int) : bool {.inline.} =
    result = e1.index == e2

proc newHaxeArray*[T]() : HaxeArray[T] =
    result = HaxeArray[T]()

template push*[T](this:HaxeArray[T], value:T) =
    this.data.add(value)

template pop*[T](this:HaxeArray[T]): T =
    let last = this.data.len - 1
    let res = this.data[last]
    delete(this.data, last)
    res

template get*[T](this:HaxeArray[T], pos:int): T =
    this.data[pos]

template length*[T](this:HaxeArray[T]): int =    
    this.data.len

proc `$`*[T](this:HaxeArray[T]) : string {.inline.} =
    result = $this.data

converter toHaxeArray*[T](s:seq[T]) : HaxeArray[T] =
    return HaxeArray[T](data: s)