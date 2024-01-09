import core.core
import times
import std/[cmdline,envvars]

export times.cpuTime
export putEnv

proc time*(): float = getTime().toUnixFloat()

template args*(): seq[string] = commandLineParams()

template string*(v: Dynamic): system.string = $v

template int*(v: float): int32 = v.int32

template print*(v: Dynamic): void = write stdout, v

template println*(v: Dynamic): void = writeLine stdout, v

proc getEnv*(s: string): Null[system.string] =
  let v = envvars.getEnv(s)
  if v > "" or existsEnv(s): return Null[system.string](value: v)
  else : return nil  

