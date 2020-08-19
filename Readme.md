# Warning. Still just an experiment. Lot of bugs!!!

This is fork of https://github.com/RapidFingers/Craxe
I have changed the code a lot. So many things are working and many more are broken

## Transpiler from haxe to nim (http://nim-lang.org/)

## The main goal for now is:
* High performance.
* Low memory footprint.
* Stable garbage collector, or maybe no GC at all (owned/unowned ref).
* Make most Haxe Code compile
* Start working on a standard library

## What it's all good for?

Backend, micro services, iot, calculations, haxe compiler :)

## Why nim?

* Because nim does all the heavy stuff like garbage collection and is very advanced here. 
  See the memory heavy benchmarks.
* It is very easy to use nim code from Haxe
* Nim allows you to choose the right garabge collectors for your need
* Fast and easy compilation

## What it can do:

I changed a lot. So the list might have changed:

* Classes: 
    - inheritance
    - constructors
    - super call
    - static and instance methods
    - instance fields
* Interfaces
* Typedefs
* Anonymous - maybe broken now
* Basic types: 
    - Int
    - Float
    - String
    - Bool
    - Generic Array<T>
    - IntMap, StringMap, ObjectMap
* Enums and ADT
* Abstracts and enum abstracts
* Generics
* GADTs
* Expressions: 
    - for
    - while
    - if
    - switch
* Closures
* Externs
* Basic file reading by File.getContent
* haxe.Json
* Stdin output by trace

## How to use it

* Install nim compiler with https://github.com/dom96/choosenim
* Install craxecore library by "nimble install https://github.com/AdrianV/Craxe?subdir=core"
* Install latest haxe build from https://build.haxe.org/builds/haxe/
* Install craxe with `haxelib git craxe https://github.com/AdrianV/Craxe`
* Add build.hxml with following strings:\
-cp src\
--macro craxe.Generator.generate()\
--no-output\
-lib craxe\
-main Main\
-D nim\
-D nim-out=main.nim
* Add some simple code to Main.hx
* Launch "haxe build.hxml"\
It will generate code and will launch the nim compiler\
"nim c -d:release filename.nim"


## Examples

https://github.com/RapidFingers/CraxeExamples

## Roadmap

- [x] Switch expression
- [x] Inheritance
- [x] Interfaces
- [?] BrainF**k benchmark
- [x] Basic externs implementation
- [x] Closures
- [x] Typedefs
- [x] Anonymous
- [x] Abstracts
- [x] Enum abstracts
- [x] Generics
- [x] GADT
- [x] Map/Dictionary
- [?] Method override
- [x] Place all nim code to nimble library
- [x] Extern for CraxeCore's http server
- [x] Benchmark of async http server
- [x] Possibility to add raw nim code
- [?] Dynamic type
- [ ] haxe.Json
- [ ] Extern for native nim iterators
- [ ] Mysql database driver
- [ ] Craxe http server benchmark with json and mysql
- [ ] Dynamic method
- [ ] Try/Catch
- [ ] Reflection
- [ ] Auto import nimble libs
- [ ] Craxe console util for setup, create project, etc
- [ ] Type checking (operator is)
- [ ] Async/Await
- [ ] Some kind of std lib
