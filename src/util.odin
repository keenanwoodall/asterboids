// This file contains general utility methods.
// There are currently utility methods scattered throughout the codebase.
// I will move them here as I rediscover them.

package game

import "core:math"
import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"

inv_sqr_interp :: proc(inner_val, outer_val, t: f32) -> f32 {
    if t < 0.0  do return inner_val // If t is negative, return the inner value as is.
    else if t > 1.0 do return outer_val // If t exceeds 1, return the outer value.
    else {
        // Compute the interpolated value using inverse square law applied to the interpolation factor
        factor := 1.0 - t;
        return (inner_val - outer_val) * (factor * factor) + outer_val;
    }
}

rand_dir :: proc() -> rl.Vector2 {
    return rl.Vector2Rotate(rl.Vector2 {0, 1}, rand.float32_range(0, math.TAU))
}

// set the length of a vector
set_length :: proc(v : rl.Vector2, length : f32) -> rl.Vector2 {
    return linalg.normalize(v) * length
}

// Limit the length of a vector
limit_length :: proc(v : rl.Vector2, limit : f32) -> rl.Vector2 {
    len := linalg.length(v)
    if len == 0 || len <= limit {
        return v
    }

    dir := v / len
    return dir * limit
}

// Safely normalize a vector
safe_normalize :: proc(v : rl.Vector2) -> (rl.Vector2, bool) {
    length := linalg.length(v)
    if length > 0 do return v / length, true
    else do return 0, false
}

on_screen :: proc(p : rl.Vector2) -> bool {
    res         := rl.Vector2{f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}
    half_res    := res * 0.5

    center_offset := linalg.abs(p - half_res)

    return center_offset.x > half_res.x || center_offset.y > half_res.y
}