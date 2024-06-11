import core/core

# Log

proc showExtra(e:varargs[string, `$`]):void =
    write(stdout, e[0] & " " & e[1] & ": ")

proc LogStatic_trace*( v:byte, e:varargs[string, `$`]):void =
    showExtra(e)
    echo v.uint

proc LogStatic_trace*[T: HaxeValueType|string](v: T, e:varargs[string, `$`]):void =
    showExtra(e)
    echo v

proc LogStatic_trace*(v: String, e:varargs[string, `$`]):void =
    showExtra(e)
    echo if not v.isNil: $v else: "null"

proc LogStatic_trace*[](v: Dynamic, e:varargs[string, `$`]):void =
    showExtra(e)
    echo if not v.isNil: $v else: "null"

proc LogStatic_trace*[T: DynamicHaxeObjectRef](v: T, e:varargs[string, `$`]):void =
    showExtra(e)
    if not v.isNil:
        checkDynamic(v)
        echo $toString(v)
    else: echo "null"

template LogStatic_trace*(v:typed, e:varargs[string, `$`]):void =
    when compiles(toString(v)) :
        LogStatic_trace(toString(v), e)
    elif compiles(toDynamic(v)) :
        LogStatic_trace(toDynamic(v), e)
    else :
        LogStatic_trace(v.repr, e)
