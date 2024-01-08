type
    LogStatic* = object

let LogStaticInst* = LogStatic()

# Log
template trace*(this:typedesc[LogStatic], v:byte, e:varargs[string, `$`]):void =
    write(stdout, e[0] & " " & e[1] & ": ")
    echo cast[int](v)

template trace*(this:typedesc[LogStatic], v:typed, e:varargs[string, `$`]):void =
    mixin toDynamic
    write(stdout, e[0] & " " & e[1] & ": ")
    when compiles($v):
        echo v
    else:
        echo $toDynamic(v)