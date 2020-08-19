# Some benchmarks

To show the potential of a nim target for Haxe, I have done some benchmarks:

## fibtree

A garbage collector stress test. This shows the potential of the nim garbage collector. Nim is only beaten by the JVM here, but this has costs. The JVM takes more than 2 times of memory and uses much more CPU. This benchmark is a killer for the hashlink target.

## fasteval

Nim is winner here, but only close followed by the JVM again. The next fastest C++ is 3 times slower.

## mandelbrot

The unfameous mandelbrot benchmark from the Haxe repository. It is again a memory allocation heavy benchmark. JVM and C++ are winners here, nim follows closely.


