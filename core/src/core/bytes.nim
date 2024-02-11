{.experimental: "codeReordering".}


import core

type
    HaxeBytesData* = ptr seq[byte]
    # Haxe bytes
    HaxeBytes* = ref object of HaxeObject
        b*: seq[byte]

    HaxeBytesStatic = object of HaxeStaticObject

# Bytes

#proc toString(this: HaxeBytesStatic, o: HaxeObjectRef): String =
#    return 

proc toHex*(this: HaxeBytes): HaxeString

let HaxeBytesStaticInst* = HaxeBytesStatic(fparent: nil, fname: "haxe.io.Bytes",
                                ftoString: proc(o: HaxeObjectRef): HaxeString {.closure} = return cast[HaxeBytes](o).toHex)


template alloc*(this:typedesc[HaxeBytes], size:int) : HaxeBytes =
    HaxeBytes(fstatic: addr HaxeBytesStaticInst,b: newSeq[byte](size));

proc ofString*(this:typedesc[HaxeBytes], s: HaxeString) : HaxeBytes =
    result = HaxeBytes(b: newSeq[byte](s.len))
    for i in 0 ..< s.len: 
        result.b[i] = s[i].byte

template get*(this:HaxeBytesData, pos:int):int32 =
    this[][pos].int32

template get*(this:HaxeBytes, pos:int):int32 =
    this.b[pos].int32

template set*(this:HaxeBytesData, pos:int, v:Natural): int32 =
    this[][pos] = v.byte
    v.int32

template set*(this:HaxeBytes, pos:int, v:Natural): void =
    this.b[pos] = v.byte

template length*(this:HaxeBytes): int32 =    
    len(this.b).int32

template `[]`*(this:HaxeBytes, pos:int): int32 =    
    this.b[pos].int32

template `[]=`*(this:HaxeBytes, pos:int, value:int) =    
    this.b[pos] = value.byte  

template length*(this:HaxeBytesData): int32 =    
    len(this[]).int32

{.push checks: off.}
template `[]`*(this:HaxeBytesData, pos:int): int32 =    
    this[][pos].int32
{.pop.}

{.push checks: off.}
template `[]=`*(this:HaxeBytesData, pos:int, value:int) =    
    this[][pos] = value.byte  
{.pop.}

template getData*(this: HaxeBytes): HaxeBytesData = 
    addr this.b

{.push checks: off.}
template fastGet*(this:typedesc[HaxeBytes], b: HaxeBytesData, pos: Natural): auto =
    b[pos].int32
{.pop.}

proc blit*(this: HaxeBytes, pos:int32, src:HaxeBytes, srcpos:int32, len:int32) =
    let tlen = this.length
    let len = if pos + len > tlen: tlen - pos else : len
    if len > 0:
        #if pos + len > this.len: this.setLen(pos + len)
        moveMem(addr this.b[pos], addr src.b[srcpos], len)

template addByte*(this: HaxeBytesData, b:int32) =
    this[].add(b.byte)

proc addInt32*(this: HaxeBytesData, b:int32) {.inline.} =
    this[].add((b and 0xFF).byte)
    this[].add(((b shr 8) and 0xFF).byte)
    this[].add(((b shr 16) and 0xFF).byte)
    this[].add(((b shr 24) and 0xFF).byte)

proc addInt64*(this: HaxeBytesData, b:int64) {.inline.} =
    this.addInt32((b and 0xFFFF_FFFF).int32)
    this.addInt32(((b shr 32) and 0xFFFF_FFFF).int32)

proc addFloat*(this: HaxeBytesData, v:float) {.inline.} = 
    let v: float32 = v.float32;
    let b: int32 = cast[int32](v)
    addInt32(this, b)

proc addDouble*(this: HaxeBytesData, v:float) {.inline.} = 
    let b: int64 = cast[int64](v)
    addInt64(this, b)

proc addBytes*(this: HaxeBytesData, src: HaxeBytes, pos: int32, len: int32) {.inline.} =
    this[].add(src.b[pos..<pos+len])

template add*(this: HaxeBytesData, bs:HaxeBytes) =
    this.add(bs.b)    

template add*(this: HaxeBytesData, bs:system.string) =
    this.add(bs)        

template getBytes*(this: HaxeBytesData): HaxeBytes =
    HaxeBytes(b:this[])
    
const hexChars = ['0','1','2','3','4','5','6','7','8','9','a','b','c','e','e','f']

proc toHex*(this: openArray[byte]): HaxeString =
    result.setLen(this.len * 2)
    for i in 0 ..< this.len:
        let v = this[i]
        result[i * 2 + 1] = hexChars[v and 0xF]
        result[i * 2] = hexChars[(v shr 4) and 0xF]

template toHex*(this: HaxeBytesData): HaxeString =
    toHex(this[])

proc toHex*(this: HaxeBytes): HaxeString =
    return this.fstatic.fname & "(" & toHex(this.b) & ")"

# proc newHaxeBytes*()

proc compare*(this, other: HaxeBytes): int32 =
    let alen = this.b.len
    let blen = other.b.len
    let r = cmpMem(addr this.b[0], addr other.b[0], min(this.b.len, other.b.len))
    return 
        if r != 0 : r.int32
        else : (alen - blen).int32

proc getString*(this: HaxeBytesData; pos, len: int32): HaxeString =
    var l2 = min(pos + len, this[].len)
    if l2 > pos:
        l2 = l2 - pos
        result = newString(l2)
        moveMem(addr result[0], addr this[pos], l2)

template getString*(this: HaxeBytes; pos, len: int32): HaxeString =
    getData(this).getString(pos, len)

#template `$`(this: HaxeBytes): string =
#    this.b.repr