import std/[strutils, uri]
import strformat
export startsWith
import core/core

type
  StringTools* = distinct object

proc urlEncode*(this:typedesc[StringTools], s:HaxeString): HaxeString =
  return encodeUrl(s)
    
proc urlDecode*(this:typedesc[StringTools], s:HaxeString): HaxeString =
  return decodeUrl(s)

template endsWith*(this:typedesc[StringTools], s:HaxeString, send: HaxeString): bool =
  strutils.endsWith(s, send)

template contains*(this:typedesc[StringTools], s:HaxeString, sub: HaxeString): bool =
  strutils.contains(s, sub)

proc hex*(this:typedesc[StringTools], n:int32, digits:int32): HaxeString =
  let s = toHex(n)
  if digits >= s.len:
    return alignString(s, digits, '>', '0')
  else:
    let max = s.len - digits
    for i in 0 ..< s.len:
      if i >= max: return s[i ..< s.len]
      if s[i] != '0':
        return if i == 0: s else: s[i ..< s.len]
    return "0"

proc hex*(this:typedesc[StringTools], n:int32): HaxeString =
  let s = toHex(n)
  for i in 0 ..< s.len:
    if s[i] != '0':
      return if i == 0: s else: s[i ..< s.len]
  return "0"

template fastCodeAt*(this:typedesc[StringTools], s:HaxeString, index:int32): int32 =
  s[index].int32

proc ltrim*(this:typedesc[StringTools], s:HaxeString): HaxeString =
  var l = s.len
  var r = 0
  while r < l and s[r] < ' ' :
    inc(r)
  if (r > 0) :
    return s.substr(r, l - r)
  else :
    return s

proc rtrim*(this:typedesc[StringTools], s: HaxeString): HaxeString =
  var l = s.length
  var r = 0
  while (r < l and s[l - r - 1] < ' ') :
    inc(r)
  if (r > 0) :
    return s.substr(0, l - r)
  else :
    return s


