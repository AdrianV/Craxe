# Fast Expression Benchmark

Fast expression evaluation. This benchmark simulates an interpreted for loop like this:

- nested loop

```haxe
var i = 0;
for (a in 0...1000) {
    for(b in 0...1000) {
        for(c in 0...1000){
            i++;
        }
    }
}
```

- single loop

```haxe
var i = 0;
for (a in 0...1000000000) {
    i++;
}
```

so the variable `i` is incremented `10^9` times. The fastest target nim does this in ~5sec on my machine, followed by the JVM with ~5.5sec. 
The next fastest is C++ with about 15sec which is about 3 times slower than nim. All these values are still very fast for interpreted code. 
Remember that there is no JIT involved. 

The same loop executed directly in the haxe interpreter takes about 27sec.