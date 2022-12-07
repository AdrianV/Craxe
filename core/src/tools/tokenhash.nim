type
  THash = distinct int32
  TokenField*[V] = object
    thash*: THash
    data*: V
  TokenTable* [V] = seq[TokenField[V]]
  ErrorDuplicateToken = object of Defect
  SearchResult = distinct int

proc `==`*(a: THash, b: THash): bool {.borrow.}
proc `<`*(a: THash, b: THash): bool {.borrow.}

proc `+`* (a: SearchResult, b: int): int {.borrow.}

{.push checks: off.}
proc tokenhash*(token: string): THash = 
  var thash: int32
  for t in token:
    thash = (231'i32 * thash) + cast[int32](ord(t)) 
  return thash.THash
{.pop.}

#converter name(arguments): return type =
  
template val* (x: SearchResult): int = cast[int](x)
template index* (x: int): SearchResult = SearchResult(- x - 1)
template index* (x: SearchResult): int = - x.val - 1
template found* (x: SearchResult): bool = x.val >= 0

proc binSearch* [T](hay: TokenTable[T], v: THash): SearchResult =
  var res: int
  var H = hay.len - 1
  var delta = H
  var I = delta shr 2
  while delta >= 8 : 
    if hay[I].thash < v:
      res = I + 1
      delta = H - res
      I = res + delta shr 2
    elif hay[I].thash == v:
      return SearchResult(I)
    else:
      H = I - 1
      delta = H - res
      I = H - delta shr 2
  while delta >= 0:
    if hay[res].thash < v :
      dec(delta)
      inc(res)
    elif hay[res].thash == v:
      return SearchResult(res)
    else:
      break
  return index(res)

var allTokens*: TokenTable[string]

proc get* [V](hay: TokenTable[V], token: string): ptr V = 
  let thash: THash = tokenhash(token)
  var  pos = binSearch(hay, thash)
  if pos.found: return unsafeAddr hay[pos.int].data

template insertImpl(hay: typed, token: string, doInsert, done: untyped) =
  let thash{.inject.}: THash = tokenhash(token)
  var pos{.inject.} = binSearch(hay, thash)
  if not pos.found: 
    pos = SearchResult(pos.index)
    doInsert(thash, pos.val)
    #hay.insert(TokenField[V](thash: thash), pos)
    var p2 = binSearch(allTokens, thash)
    if not p2.found: 
      allTokens.insert(TokenField[string](thash: thash, data: token), p2.index)
    elif allTokens[p2.val].data != token : raise newException(ErrorDuplicateToken, token & " and " & allTokens[p2.val].data & " share the same hash " & $int32(thash))
  done

proc getOrInsert* [V](hay: var TokenTable[V], token: string): ptr V {.discardable.}= 
  template doInsert(thash, pos) =
    hay.insert(TokenField[V](thash: thash), pos)
  insertImpl(hay, token, doInsert):
    return addr hay[pos.val].data

template setOrInsert* [V](hay: var TokenTable[V], token: string, value: V): ptr V = 
  var isSet = false
  template doInsert(thash, pos) =
    hay.insert(TokenField[V](thash: thash, data: value), pos)
    isSet = true
  insertImpl(hay, token, doInsert):
    let result = if not isSet: addr hay[pos.val].data else: nil
  result

proc insert* [V](hay: var TokenTable[V], token: string, v: V) = 
  template doInsert(thash, pos) =
      hay.insert(TokenField[V](thash: thash, data: v), pos)
  insertImpl(hay, token, doInsert): discard

proc `$`* (v: THash): string =
  let pos = allTokens.binSearch(v)
  return if pos.found : allTokens[pos.val].data else: ""

when isMainModule:

  var test: TokenTable[int]

  test.getOrInsert("a")[] = 1
  test.getOrInsert("b")[] = 2
  test.getOrInsert("c")[] = 3

  proc `$`[T](v: ptr T): string = return if v != nil: $v[] else: "nil"

  echo test.get("a")
  echo test.get("b")
  echo test.get("c")
  echo test.get("d")

  echo test.repr

  echo allTokens