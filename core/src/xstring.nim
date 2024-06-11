import std/unicode

type
  ScanInfo = distinct byte
  XString* = ref object
    fdata: string
    flen*: int
    fpos: seq[ScanInfo]
  PosInfo = tuple[idx: int, rx: int, xx: int, ipos: int]

template toString*(this: XString): XString =
  this

template width*(this: ScanInfo): int = 
  (this.byte and 0b111).int + 1

template count*(this: ScanInfo): int =
  1 + (this.byte and 0b11111000).int shr 3  

template encode(width: int, count: int): ScanInfo =
  ((count - 1) shl 3 or (width - 1)).ScanInfo

template `$`*(this: XString): string = 
  this.fdata

template isChecked(this: XString): bool =
  block:
    let this1 {.genSym.} = this
    this1.flen > 0 or this1.fdata == ""

template checkLength(this: XString) =
  block:
    let this1 {.genSym.} = this
    if not this1.isChecked : this1.scanLength

template isASCII*(this: XString): bool =
  block:
    let this1 {.genSym.} = this
    this1.flen == this1.fdata.len

proc newASCIIString*(s: string): XString =
  result = XString(fdata: s, flen: s.len)

iterator scanRunes*(this: XString): Rune {.inline.} =
  if not this.isChecked :
    var cnt = 0
    var w = 0
    let blen = this.fdata.len
    var bx = 0
    var ulen = 0
    while bx < blen:
      inc(ulen)
      let xx = bx
      var v {.noinit.}: Rune 
      fastRuneAt(this.fdata, bx, v, true)
      yield v
      let ln = bx - xx
      if ln != w :
        if w > 0: this.fpos.add(encode(w, cnt))
        w = ln
        cnt = 1
      else :
        if cnt == 32 :
          this.fpos.add(encode(w, cnt))
          cnt = 1
        else : inc(cnt)
    if cnt > 0:
      this.fpos.add(encode(w, cnt))
    this.flen = ulen
  else :
    let blen = this.fdata.len
    var bx = 0
    if blen > this.flen:
      while bx < blen:
        var v {.noinit.}: Rune 
        fastRuneAt(this.fdata, bx, v, true)
        yield v
    else :
      while bx < blen:
        yield this.fdata[bx].Rune
        inc bx


proc scanLength(this: XString) =
  if not this.isChecked:
    for r in scanRunes(this):
      discard
  when false:
    var cnt = 0
    var w = 0
    let blen = this.fdata.len
    var bx = 0
    var ulen = 0
    while bx < blen:
      inc(ulen)
      var v {.noinit.}: Rune 
      let xx = bx
      fastRuneAt(this.fdata, bx, v, true)
      let ln = bx - xx
      if ln != w :
        if w > 0: this.fpos.add(encode(w, cnt))
        w = ln
        cnt = 1
      else :
        if cnt == 32 :
          this.fpos.add(encode(w, cnt))
          cnt = 1
        else : inc(cnt)
    if cnt > 0:
      this.fpos.add(encode(w, cnt))
    this.flen = ulen

proc len*(this: XString): int =
  checkLength(this)
  return this.flen

template binaryLen*(this): int =
  if this != nil : this.data.len
  else: 0

template getRunePosImpl(this: XString, x: Natural, result: typed, asInfo: bool) =
  block impl:
    if x == 0: 
      result = when asInfo: (idx: 0, rx: 0, xx: 0, ipos: 0) else: 0
      break impl
    if x < 0 : 
      result = when asInfo: (idx: -1, rx: 0, xx: 0, ipos: 0) else: -1
      break impl
    checkLength(this)
    if this.isASCII : 
      # pure ASCII string
      if x < this.flen : 
        when asInfo :
          result = (idx: x, rx: 0, xx: 0, ipos: 0)
        else :
          result = x
        break impl
    else :
      let top = this.flen - x
      if top > 0:
        # if this.flen == this.fdata.len: 
        #  result = when asInfo: (idx: x, rx: 0, xx: 0, ipos: -1) else: x
        #  break impl
        let plen = this.fpos.len
        if x <= top:
          var rx = 0
          var xx = 0
          for ip in 0 ..< plen:
            let p = this.fpos[ip]
            let c = p.count
            let w = p.width
            if x <= xx + c :
              let idx = rx + (x - xx) * w
              result = when asInfo: (idx: idx, rx: rx, xx: xx, ipos: ip)  else: idx
              break impl
            inc(rx, c * w)
            inc(xx, c)
        else :
          var rx = this.fdata.len
          var xx = this.flen
          for ip in countdown(plen - 1, 0):
            let p = this.fpos[ip]
            let c = p.count
            let w = p.width
            if x >= xx - c :
              let idx = rx - (xx - x) * w
              result =  when asInfo: (idx: idx, rx: rx, xx: xx, ipos: ip) else: idx
              break impl
            dec(rx, c * w)
            dec(xx, c)
    result = when asInfo: (idx: -1, rx: 0, xx: 0, ipos: 0) else: -1

proc getRunePosInfo*(this: XString, x: Natural): PosInfo =
  getRunePosImpl(this, x, result, true)

proc moveBy*(this: XString, info: PosInfo, startIndex: int, distance: int): PosInfo =
  var distance = distance
  if distance == 0: return info
  let x = startIndex + distance
  if this.isASCII:
    if x >= 0 and x < this.flen :
      return (idx: x, rx: 0, xx: 0, ipos: 0)
  else :
    var (_, rx, xx, ipos) = info
    if distance < 0:
      for ip in countdown(ipos, 0):
        let p = this.fpos[ip]
        let c = p.count
        let w = p.width
        let xx0 = xx - c
        if x >= xx0 :
          return (idx: rx - (xx - x) * w, rx: rx, xx: xx, ipos: ip)
        dec(rx, c * w)
        xx = xx0
    else :    
      for ip in ipos ..< this.fpos.len:
        let p = this.fpos[ip]
        let c = p.count
        let w = p.width
        if x < xx + c :
          return (idx: rx + (x - xx) * w, rx: rx, xx: xx, ipos: ip)  
        inc(rx, c * w)
        inc(xx, c)
  return (idx: -1, rx: 0, xx: 0, ipos: 0)

proc getRunePos*(this: XString, x: Natural): int =
  ## Returns binary index of x'th (zero based) UTF8 Rune in `this`
  ## If x is out of bounds `-1` is returned.
  ## The position infos of `this` will be build if not available yet
  getRunePosImpl(this, x, result, false)

proc getRuneAtBytePos*(this: XString, index: int): Rune {.inline.} =
  fastRuneAt(this.fdata, index, result, false)

proc copy*(this: XString): XString {.inline.} =
  return XString(fdata: this.fdata, flen: this.flen, fpos: this.fpos)

proc `==`*(this: XString, v: string): bool {.inline.} =
  return this.fdata == v

proc `==`*(this: XString, v: XString): bool {.inline.} =
  return this.fdata == v.fdata

proc `:=`*(this: var XString; v: string) {.inline.} =
  this = XString(fdata: v)


proc `&`*(a: XString; b: string): XString {.inline} =
  return XString(fdata: a.fdata & b)

proc `&`*(a: string; b: XString): XString {.inline.} =
  XString(fdata: a & b.fdata)

proc `&`*(a, b: XString): XString =
  return if a.isChecked and b.isChecked:
    XString(fdata: a.fdata & b.fdata, flen: a.flen + b.flen, fpos: a.fpos & b.fpos)
  else :
    XString(fdata: a.fdata & b.fdata)

proc `&=`*(this: var XString; v: string) =
  if not this.isNil:
    this = XString(fdata: this.fdata & v)
  else :
    this = XString(fdata: v)

proc `&=`*(this: var XString; v: XString) =
  if not this.isNil:
    if this.isChecked and v.isChecked:
      this = XString(fdata: this.fdata & v.fdata, flen: this.flen + v.flen, fpos: this.fpos & v.fpos)
    else :
      this = XString(fdata: this.fdata & v.fdata)
  else :
    this = v.copy

proc setLen*(this: var XString; len: Natural) =
  if this == nil :
    this = XString(flen: len)
    this.fdata.setLen(len)
  elif len == 0 :
    if this.fdata.len > 0: 
      this = XString()
  else :
    this = this.copy
    checkLength(this)
    if len > this.flen:
      var remain = len - this.flen
      this.fdata.setLen(this.fdata.len + remain)
      this.flen = len
      while remain > 0:
        let c = min(32, remain)
        this.fpos.add(encode(1, c))
        dec remain, c
    elif len < this.flen:
      var remain = this.flen - len
      this.flen = len
      var cntb = 0
      var x = this.fpos.high
      while remain > 0 and x >= 0:
        let p = this.fpos[x]
        let c = p.count
        let cr = min(c, remain)
        dec remain, cr
        let w = p.width
        inc cntb, w * cr
        if cr == c :
          this.fpos.setLen(x)
        else :
          this.fpos[x] = encode(w, c - cr)
          break
        dec x
      if cntb <= this.fdata.len: 
        this.fdata.setLen(this.fdata.len - cntb)

template toXString*(s: string): XString =
  XString(fdata: s)

converter fromString*(s: string): XString {.inline.} =
  result = s.toXString()

proc getAt*(this: XString, x: Natural): Rune =
  let bx = getRunePos(this, x)
  if bx >= 0:
    fastRuneAt(this.fdata, bx, result, false)

template `[]`*(this: XString, x: int|int32): Rune =
  bind `[]`
  block:
    let this1 = this
    #let x = x
    if this1.isASCII : 
      Rune(uint(this1.fdata[x]))
    else : getAt(this1, x)

proc fromCharCode*(this: typedesc[XString], code: int32): XString =
  result = XString(fdata: "")
  var pos = 0
  fastToUTF8Copy(code.Rune, result.fdata, pos, true)
  result.flen = 1

proc charAt*(this: XString, index: Natural): XString {.inline.} =
  XString.fromCharCode(this[index].int32)

proc indexOfBrute* (s: openArray[char]; sub: openArray[char]; startIndex: int32 = 0): int32 =
  let subLen = sub.len  
  let m = s.len - subLen
  for i in startIndex .. m.int32 :
    var k = subLen - 1
    while true :
      if k >= 0 : 
        if s[i+k] != sub[k] : break
        dec k
      else : return i
  return -1'i32

{.push checks: off .}
proc indexOf* (s: openArray[char]; sub: openArray[char]): int32 =
  let subHigh = sub.len - 1
  if subHigh < 2 : return indexOfBrute(s, sub)
  let m = s.len
  if m > subHigh :      
    var shash: uint = 0
    for i in 0 .. subHigh: 
      shash = shash + sub[i].uint
    var hash: uint = 0 
    for i in 0 ..< subHigh: hash = hash + s[i].uint
    var i = subHigh
    while i < m:
      hash = hash + s[i].uint
      let ii = i - subHigh
      if hash == shash :
        var k = subHigh
        while true:
          if k >= 0:  
            if sub[k] != s[ii + k]: break
            dec k
          else : return ii.int32
      hash -= s[ii].uint # shl subHigh
      inc i
  return -1
{.pop.}

iterator allPosOf* (s: XString; sub: string; startIndex: int32 = 0): tuple[x: int32, pos: int32] {.inline.} =
  let subLen = sub.len  
  var i = getRunePos(s, startIndex)
  if subLen == 0 or i < 0: 
    if i >= 0 : 
      var pos = startIndex
      while i < s.fdata.len :
        yield (x: i.int32, pos: pos)
        var r {.noinit.}: Rune
        fastRuneAt(s.fdata, i, r, true)
        inc pos
  else :
    let m = s.fdata.len - subLen
    var iu = startIndex
    while i <= m:
      var k = 0
      var iNext {.noinit.} : int
      while k < subLen:
        var a {.noinit.}, b {.noinit.} : Rune
        fastRuneAt(s.fdata, i, a, true)
        if k == 0: 
          iNext = i
        fastRuneAt(sub, k, b, true)
        if a != b : 
          k = 0
          break
      if k == subLen :
        yield (x: (i - k).int32, pos: iu)
      i = iNext
      inc iu

proc indexOfBrute* (s: XString; sub: string; startIndex: int32 = 0): int32 =
  for inf in s.allPosOf(sub, startIndex):
    return inf.pos
  return -1'i32

proc indexOfBrute* (s: XString; sub: XString; startIndex: int32 = 0): int32 {.inline.} =
  return indexOfBrute(s, sub.fdata, startIndex)


{.push checks: off .}
proc indexOf* (s: XString; sub: XString ; startIndex: int32 = 0): int32 =
  var subHigh = sub.fdata.len - 1 # binary data high
  if subHigh < 2 : return indexOfBrute(s, sub, startIndex)
  let m = s.fdata.len
  if m > subHigh :     
    var shash: uint = 0
    for r in sub.scanRunes:  # we scan and build runePosition Info together with hash 
      shash = shash + r.uint32
    var hash: uint = 0 
    var rx = startIndex  # current Rune pos
    var x = s.getRunePos(rx)
    var xx = x             # bytePos of rx
    var xxNext {.noinit.} : int
    var rAtrx {.noinit.}: Rune
    subHigh = sub.flen - 1 # now subHigh is logical high
    for i in 0 ..< subHigh: 
      var r {.noinit.}: Rune
      fastRuneAt(s.fdata, x, r, true)
      if i == 0: 
        rAtrx = r
        xxNext = x
      hash = hash + r.uint32
    # rx = rx + subHigh
    while x < m:
      var r {.noinit.}: Rune
      fastRuneAt(s.fdata, x, r, true)
      hash = hash + r.uint32
      #echo rx, " ", xx, " ", rAtrx.toUTF8, "  |  ", x, " ", r.toUTF8, "  |  ", hash, " ", shash
      if hash == shash :
        var ib = 0
        var b {.noinit.} : Rune
        fastRuneAt(sub.fdata, ib, b, true)
        xx = xxNext
        var ia = xxNext
        if rAtrx == b:          
          for k in 0 ..< subHigh:
            var a {.noinit.}: Rune
            fastRuneAt(s.fdata, ia, a, true)
            fastRuneAt(sub.fdata, ib, b, true)
            if a != b: 
              ia = 0
              break
          if ia > 0: return rx
      r = rAtrx
      xx = xxNext
      hash -= r.uint32
      fastRuneAt(s.fdata, xxNext, rAtrx, true)
      inc rx
      
  return -1
{.pop.}

proc lastIndexOf* (s: XString; sub: string; startIndex: int32 = -1): int32 =
  checkLength(s)
  let subLen = sub.len
  var iu = if startIndex == -1 : (s.flen - 1).int32 else : startIndex
  var info = getRunePosInfo(s, iu)
  var i = info.idx
  while i > s.fdata.len - subLen:
    info = moveBy(s, info, iu, -1)
    i = info.idx
    dec iu
  if subLen == 0 or i < 0: 
    if i >= 0 : return iu
    return -1'i32
  while i >= 0:
    # echo iu, " ", info
    var k = subLen
    var ia = i
    var ib = 0
    while k > 0:
      if s.fdata[ia] != sub[ib] :
        break
      dec k
      inc ib
      inc ia
    if k == 0 :
      return iu
    info = moveBy(s, info, iu, -1)
    dec iu
    i = info.idx
  return -1'i32

proc lastIndexOf* (s: XString; sub: XString; startIndex: int32 = -1): int32 {.inline.} =
  result = lastIndexOf(s, sub.fdata, startIndex)

proc split*(this: XString; delimiter: string): seq[XString] =
  result = @[]
  var p0 = 0'i32
  for inf in this.allPosOf(delimiter, 0):
    result.add(this.fdata.substr(p0, inf.x - 1).toXString())
    p0 = inf.x
    if delimiter.len > 0:
      p0 = p0 + this.fdata.graphemeLen(p0).int32
  result.add(this.fdata.substr(p0).toXString)

proc substr*(this: XString; pos: int32; len: int32 = int32.high): XString =
  let pos = max(0, if pos < 0 : this.len + pos else : pos)
  let len = min(len, this.len - pos)
  if len < 0: 
    result = nil
  elif len == 0:
    return XString(fdata: "")
  else:
    let plast = pos + len - 1
    if this.flen != this.fdata.len :
      let inf1 = this.getRunePosInfo(pos)
      let inf2 = if len > this.len - plast :  
          this.getRunePosInfo(plast) 
        else : 
          this.moveBy(inf1, pos, len - 1)
      var fpos = this.fpos[inf1.ipos .. inf2.ipos]
      let p1 = this.fpos[inf1.ipos]
      let w1 = p1.width
      let c1 = p1.count
      fpos[0] = encode(w1, c1 - (pos - inf1.xx))
      let p2 = this.fpos[inf2.ipos]
      let w2 = p2.width
      fpos[fpos.len - 1] = encode(w2, plast - inf2.xx)
      #echo inf1
      #echo inf2
      #echo fpos.repr
      result = XString(fdata: this.fdata.substr(inf1.idx, inf2.idx + w2 - 1), fpos: fpos, flen: len)
    else :
      result = XString(fdata: this.fdata.substr(pos, plast), flen: len)

proc substring*(this: XString; pos: int32; endIndex: int32 = int32.high): XString =
  var pos = max(0, pos)
  var endIndex = max(0, endIndex)
  if pos > endIndex : swap(pos, endIndex)
  return this.substr(pos, endIndex - pos)

proc toLower*(this: XString): XString =
  var data = newStringOfCap(this.fdata.len)
  var x = 0
  let len = this.fdata.len
  var same = not (this.flen == 0 and len > 0)
  while x < len :
    var a {.noinit.}: Rune
    fastRuneAt(this.fdata, x, a, true)
    if a.isUpper:
      var other = a.toLower
      data.add(other)
      same = same and a.size == other.size
    else:
      data.add(a)
  return if same : XString(fdata: data, flen: this.flen, fpos: this.fpos) 
    else : XString(fdata: data)

proc toUpper*(this: XString): XString =
  var data = newStringOfCap(this.fdata.len)
  var x = 0
  let len = this.fdata.len
  var same = not (this.flen == 0 and len > 0)
  while x < len :
    var a {.noinit.}: Rune
    fastRuneAt(this.fdata, x, a, true)
    if a.isLower:
      var other = a.toUpper
      data.add(other)
      same = same and a.size == other.size
    else:
      data.add(a)
  return if same : XString(fdata: data, flen: this.flen, fpos: this.fpos) 
    else : XString(fdata: data)

template pad(s: XString, c: XString, l: int32, result: var XString, left: bool) =
  template addASCII(xlen: int) =
    var x = 0
    while x < xlen :
      let cnt = min(32, xlen - x)
      result.fpos.add(encode(1, cnt))
      inc x, cnt
  block impl:
    let slen = s.len
    if slen >= l or c.isNil or c.fdata.len == 0: 
      result = s.copy
      break impl
    let clen = c.len
    var rlen = slen
    var res = when left: "" else : s.fdata
    var count = 0
    while rlen < l :
      res &= c.fdata
      inc rlen, clen
      inc count
    when left :
      res &= s.fdata
    result = XString(fdata: res, flen: rlen)
    template appendC() = 
      for i in 1 .. count :
        result.fpos &= c.fpos
    if s.isASCII and c.isASCII:
      discard
    elif s.isASCII :
      result.fpos = newSeqOfCap[ScanInfo](s.flen div 32 + 1 + count * c.fpos.len)
      when not left : addASCII(slen)
      appendC()
      when left : addASCII(slen)
    elif c.isASCII :
      result.fpos = newSeqOfCap[ScanInfo](s.fpos.len + count div 32 + 1)
      when left : addASCII(clen)
      result.fpos &= s.fpos
      when not left : addASCII(clen)
    else:
      result.fpos = newSeqOfCap[ScanInfo](s.fpos.len + count * c.fpos.len)
      when left : appendC()
      result.fpos &= s.fpos
      when not left : appendC()
  
proc rpad*(this,c: XString; l: int32): XString =
  pad(this, c, l, result, false)

proc lpad*(this,c: XString; l: int32): XString =
  pad(this, c, l, result, true)


when isMainModule:
  var a = "Mütter und Väter, aber nicht rettüM oder retäV und tütet, sind auch Kinder von Müttern und Vätern Hüte"
  echo a.len , " ", a
  for x, c in a.pairs:
    echo x, " " ,a.runeAt(x)
    echo a.graphemeLen(x)

  var ax = a.toXString
  echo ax, " ", ax.len
  for i in 0 ..< ax.len:
    echo i, ": ", ax[i], " at: ", ax.getRunePos(i)
  echo ": ", XString.fromCharCode(-1).len
  echo "-----------------------------------------"
  echo ax.indexOfBrute("ütte".toXString, 0)
  echo "-----------------------------------------"
  echo ax.indexOfBrute("ütte".toXString, 3)
  echo "-----------------------------------------"
  echo ax.indexOfBrute("ütte")
  echo "-----------------------------------------"
  echo ax.indexOfBrute("ütte", 3)
  echo "-----------------------------------------"
  echo ax.indexOf("ütte".toXString, 0)
  echo "-----------------------------------------"
  echo ax.indexOf("ütte".toXString, 13)  
  echo "-----------------------------------------"
  echo ax.indexOf("Hüte".toXString)  
  echo "-----------------------------------------"
  echo ax.indexOfBrute("Hüte".toXString)  
  echo "-----------------------------------------"
  echo ax.lastIndexOf("Hüte")  
  echo "-----------------------------------------"
  echo ax.lastIndexOf("ütte")
  echo "-----------------------------------------"
  echo ax.lastIndexOf("ütte", 13)  
  
  for inf in ax.allPosOf("üt") :
    echo inf
  echo ax.split("üt")
  echo ax.split("ß")
  echo ax.split("")
  echo ax.indexOfBrute("ß")
  echo ax.toLower()
  echo ax.toUpper()
  echo ax.toLower().repr
  echo ax.toUpper().repr
  var a2 = ax.substr(1, ax.len.int32 - 2)
  echo a2
  echo a2.indexOf("Hüt".toXString)
  echo a2.indexOfBrute("Hüt")
  echo "-----------------------------------------"

  ax = "aabbbbaabbbbaa".toXString
  echo ax.split("a")
  echo ax.split("b")

  a2 = "012345678".toXString
  echo "(-1) ", a2.substring(-1)
  echo "(-1, -1) ", a2.substring(-1, -1)
  echo "(1, 8) ", a2.substring(1, 8)  
  echo "(8, 1) ", a2.substring(8, 1)
  echo "(15, 8) ", a2.substring(15, 8)

  var tested = 0
  for r in 0 .. 0xFFFF:
    var rr = r.Rune
    if rr.isLower :
      inc tested
      let up = rr.toUpper
      if rr.size != up.size :
        echo rr.toUTF8, " has different len than ", up.toUTF8
  echo "tested ", tested, " runes"

