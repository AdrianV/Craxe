import math
import random

export math.PI
export system.abs

template floori*(v: float): int32 =
  floor(v).int32

template random*():float =
  rand(1.0)