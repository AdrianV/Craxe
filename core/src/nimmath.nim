import math
import random

export math.PI, math.isNaN
export system.abs, system.NaN

const
  NEGATIVE_INFINITY* = system.NegInf
  POSITIVE_INFINITY* = system.Inf


template floori*(v: float): int32 =
  floor(v).int32

template floori*(v: int): int32 =
  v.int32

template min*(a: typed, b: typed): auto =
  system.min(a, b)

template max*(a: typed, b: typed): auto =
  system.max(a, b)

template random*():float =
  rand(1.0)

func isFinite*(v: float): bool = 
  let cf = classify(v)
  return not (cf in {fcNan, fcInf, fcNegInf})

template ceil*(v: float): int32 =
  math.ceil(v).int32
  
