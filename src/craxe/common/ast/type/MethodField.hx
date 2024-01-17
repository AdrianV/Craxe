package craxe.common.ast.type;

import haxe.macro.Type.ClassField;

enum VirtualInfoBase {
    Virtual;
    Override;
}

abstract VirtualInfo(VirtualInfoBase) from VirtualInfoBase to VirtualInfoBase {
    inline public function new(v) this = v;
    public var isVirtual(get, never): Bool;
        inline function get_isVirtual() return this != null;
    public var isOverride(get, never): Bool;
        inline function get_isOverride() return this != null && this == Override;
    public var isBase(get, never): Bool;
        inline function get_isBase() return this != null && this == Virtual;
    
}

typedef MethodField = {
    > ClassField,
    ? virt: VirtualInfo,
}