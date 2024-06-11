import xstring
import std/[strutils, uri]
import strformat
import core/core
import nimiter

type
  StringTools* = distinct object

proc urlEncode*(this:typedesc[StringTools], s:String): String =
  return encodeUrl($s)
    
proc urlDecode*(this:typedesc[StringTools], s:String): String =
  return decodeUrl($s)

template endsWith*(this:typedesc[StringTools], s:String, send: String| string): bool =
  strutils.endsWith($s, $send)

proc replace*(this:typedesc[StringTools]; s: String; sub, by: String|string): String =
  strutils.replace($s, $sub, $by)

template startsWith*(this:typedesc[StringTools], s:String; sstart: String|string): bool =
  strutils.startsWith($s, $sstart)

template contains*(this:typedesc[StringTools], s:String, sub: String): bool =
  s.indexOf(sub) >= 0

proc hex*(this:typedesc[StringTools], n:int32, digits:int32): String =
  var res: string
  block impl:
    let s = toHex(n)
    if digits >= s.len:
      res = alignString(s, digits, '>', '0')
      break impl
    else:
      let max = s.len - digits
      for i in 0 ..< s.len:
        if i >= max: return s[i ..< s.len]
        if s[i] != '0':
          res = if i == 0: s else: s[i ..< s.len]
          break impl
      res = "0"
  return newASCIIString(res)

proc hex*(this:typedesc[StringTools], n:int32): String =
  let s = toHex(n)
  for i in 0 ..< s.len:
    if s[i] != '0':
      return (if i == 0: s else: s[i ..< s.len]).newASCIIString
  return "0".newASCIIString

{.push checks:off.}
template fastCodeAt*(this:typedesc[StringTools], s:String, index:int32): int32 =
  s[index].int32
{.pop.}

proc ltrim*(this:typedesc[StringTools], s:String): String =
  var l = s.len
  var r = 0
  while r < l and s[r] < ' ' :
    inc(r)
  if (r > 0) :
    return s.substr(r, l - r)
  else :
    return s

proc rtrim*(this:typedesc[StringTools], s: String): String =
  var l = s.length
  var r = 0
  while (r < l and s[l - r - 1] < ' ') :
    inc(r)
  if (r > 0) :
    return s.substr(0, l - r)
  else :
    return s

proc isSpace*(this:typedesc[StringTools], s: String, pos: int32): bool {.inline.} =
  let c = s[pos]
  return c in {9..13, 32}

proc iter*(this:typedesc[StringTools], s: String): HaxeIt[int32] {.inline.} =
  result.iter = iterator (): int32 = 
    for r in s.scanRunes : yield r.int32

proc keyValueIterator*(this:typedesc[StringTools], s: String): HaxeIt[HaxeKeyValue[int32,int32]] {.inline.} =
  result.iter = iterator (): auto = 
    var idx = 0'i32
    for r in s.scanRunes : 
      yield HaxeKeyValue[int32, int32](qkind: TAnon, key: idx, value: r.int32)
      inc idx

  
template rpad*(this:typedesc[StringTools]; s,c: String; l: int32): String =
  s.rpad(c, l)

template lpad*(this:typedesc[StringTools]; s,c: String; l: int32): String =
  s.lpad(c, l)
