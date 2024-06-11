package test;

import helper.bytes.Compress;
import haxe.io.Bytes;

class TestCompress {
    

    static function main() {
        var bs = Bytes.alloc(14);
        for (i in 0 ... bs.length) bs.set(i, 0xFF);
        var c = Compress.compress(bs);

        trace('original    : ' + bs.toHex());
        trace('compressed: ${c.data.toHex()}  length: ${c.data.length}');
        var d = Compress.expand(c);
        trace('uncompressed: ' + d.toHex());
        trace('original    : ' + bs.toHex());
        trace('equal: ${bs.compare(d)}');
        Compress.compress(Bytes.ofString("blah"));
    }
}