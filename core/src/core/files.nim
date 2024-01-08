type
    FileStatic = object

let FileStaticInst* = FileStatic()

# File
template getContent*(this:typedesc[FileStatic], path:string): string =
    readFile(path)