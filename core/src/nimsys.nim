import core.core
import times
import std/[cmdline, envvars, random, typetraits, parseutils]


export times.cpuTime
export putEnv

proc time*(): float = getTime().toUnixFloat()

template args*(): seq[string] = commandLineParams()

template string*(v: Dynamic): system.string = $v

template int*(v: float): int32 = v.int32

template random*(max: int32): int32 =
  rand(max).int32
  
proc parseFloat*(v: String): float =
  discard parseFloat($v, result, 0)

template print*(v: Dynamic): void = write stdout, v

template println*(v: Dynamic): void = writeLine stdout, v

proc getEnv*(s: string): String =
  let v = envvars.getEnv(s)
  if v > "" or existsEnv(s): return v.toXString
  else : return nil  


proc isOfType*(a: HaxeObjectRef; b: AnyClass): bool = 
    var ac = addr a.qstatic[]
    while not ac.isNil :
        if ac.qtype.qcidx == b.qcidx : return true
        ac = ac.qparent
    return false
  
proc isOfType*(a: Dynamic; b: AnyClass): bool = 
  return case a.kind :
  of TString:
    b.qcidx == StringStaticInst.qtype.qcidx
  of TClass: 
    isOfType(a.dyn.fclass, b)
  else: false

proc isOfType*(a: Dynamic; b: DynamicType): bool = 
  return a.kind == b

proc isOfType*[S](a: Dynamic; b: typedesc[S]): bool = 
  return case a.kind :
  of THaxe: false
  of TString: 
      a.fstring is b
  of TInt: 
      a.fint is b
  of TFloat: 
      a.ffloat is b
  of TBool:
      a.fbool is b
  of TAnonWrapper:
    when b is DynamicHaxeObjectRef:
      a.fwrapper.instance of b
    else: false
  of TAnon: 
    when b is DynamicHaxeObjectRef:
      a.fanon of b
    else : false
  of TClass: 
    when b is HaxeObjectRef :
      a.fclass of b
    else : false
  of TEnum:
    when b is HaxeEnum:
      a.fenum of b
    else: false
  of TPointer:
      a.fpointer is b


template isOfType*[S](a: HaxeValueType; b: typedesc[S]): bool = 
  a is b

template isOfType*[T,S](a: T; b: typedesc[S]): bool = 
  when compiles(a of b) :
    a of b
  else : a is b


when false:
  proc isOfType*(a,b: HaxeObjectRef): bool = 
      var bc = b.qstatic
      if bc != nil: return isOfType(a, bc[])
      return a.qstatic.isNil
