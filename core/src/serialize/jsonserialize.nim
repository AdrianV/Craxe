import json
import tables
import sequtils
import core/[core]

type    
    JsonParser* = object
        value:string

    JsonPrinterStatic* = object

let JsonPrinterStaticInst* = JsonPrinterStatic()

proc printObject(obj:Dynamic):string =    
    let fields = obj.getFieldNames()
    if fields.len < 1:    
        return "{}"
    
    result = "{"
    for i in 0..<fields.len:
        if result.len > 1: result.add(", ")

        let fieldName = fields[i]
        result.addQuoted(fieldName)
        result.add(": ")
        let val = obj{$fieldName}
        case val.kind
        of TString:
            result.add("\"" & $val & "\"")
        else:
            result.add($val)
        
    result.add("}")

proc parseNode(node:JsonNode):Dynamic =
    case node.kind
    of JObject:
        var res = DynamicHaxeWrapper() # DynamicHaxeObjectRef()
        # var keys = toSeq(node.fields.keys)        
        # var res = newAnonObject(keys)
        # var i = 0        
        for key, val in node.fields.pairs():
            res.setFieldByName(key, parseNode(val))
            # inc(i)
        return res.toDynamic
    of JString:
        return toDynamic(node.getStr().toXString)
    of JInt:
        return toDynamic(node.getInt().int32)
    of JFloat:
        return toDynamic(node.getFloat())
    else:
        discard

proc newJsonParser*(value:string):JsonParser =
    JsonParser(value:value)

proc doParse*(this:JsonParser):Dynamic =
    let rootNode = parseJson(this.value)
    return parseNode(rootNode)

proc print*(this:JsonPrinterStatic, value:Dynamic, replacer:pointer = nil, space:pointer = nil):string =    
    case value.kind
    of TAnon, TClass:
        return printObject(value)
    else:
        raise newException(ValueError, "Unsupported Dynamic type")