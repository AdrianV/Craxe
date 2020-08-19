import core.core
import times

export times.cpuTime

proc time*(): float = getTime().toUnixFloat()

template string*(v: Dynamic): system.string = $v

template int*(v: float): int32 = v.int32