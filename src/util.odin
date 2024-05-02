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