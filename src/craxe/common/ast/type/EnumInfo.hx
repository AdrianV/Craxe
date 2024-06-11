package craxe.common.ast.type;

import haxe.macro.Type;
import haxe.macro.Type.EnumType;

/**
 * Enum information
 */
typedef EnumInfo = {
    /**
     * Enum type info
     */
    var enumType:EnumType;

    /**
     * Params of type
     */
    var params:Array<Type>;

    /**
     * Nimified Name
     */
    var enumName: String;

    /**
     * Flag if enum is build
     */
    var isBuild: Bool;
}
