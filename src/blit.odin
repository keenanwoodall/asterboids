// Utility class for drawing from one render texture to another with a shader

package game

import "core:fmt"
import rl "vendor:raylib"

ShaderValue :: union { f32, int, [2]f32, [3]f32, [4]f32, [2]i32, [3]i32, [4]i32 }
ShaderProp :: struct {
    uniform_name : cstring,
    value : ShaderValue,
}

blit :: proc(src, dst : rl.RenderTexture, shader : rl.Shader, props : ..ShaderProp) {
    rl.BeginTextureMode(dst)
    rl.BeginShaderMode(shader)
    rl.BeginBlendMode(.CUSTOM_SEPARATE);
    // These blend factors let us overwrite the dst with the src. No blending - just writing pixels
    rl.rlSetBlendFactorsSeparate(rl.RL_ONE, rl.RL_ZERO, rl.RL_ONE, rl.RL_ZERO, rl.RL_FUNC_ADD, rl.RL_FUNC_ADD);
    defer rl.EndBlendMode()
    defer rl.EndShaderMode()
    defer rl.EndTextureMode()

    for &prop in props {
        loc := rl.GetShaderLocation(shader, prop.uniform_name)
        switch _ in prop.value {
            case f32: rl.SetShaderValue(shader, loc, rawptr(&prop.value), .FLOAT)
            case int: rl.SetShaderValue(shader, loc, rawptr(&prop.value), .INT)
            case [2]f32: rl.SetShaderValue(shader, loc, rawptr(&prop.value), .VEC2)
            case [3]f32: rl.SetShaderValue(shader, loc, rawptr(&prop.value), .VEC3)
            case [4]f32: rl.SetShaderValue(shader, loc, rawptr(&prop.value), .VEC4)
            case [2]i32: rl.SetShaderValue(shader, loc, rawptr(&prop.value), .IVEC2)
            case [3]i32: rl.SetShaderValue(shader, loc, rawptr(&prop.value), .IVEC3)
            case [4]i32: rl.SetShaderValue(shader, loc, rawptr(&prop.value), .IVEC4)
        }
    }

    rl.DrawTextureRec(src.texture, rl.Rectangle{ 0, 0, f32(src.texture.width), -f32(src.texture.height) }, { 0, 0 }, rl.WHITE);
}

swap :: proc(a, b : ^$T) {
    tmp := a^
    a^ = b^
    b^ = tmp
}