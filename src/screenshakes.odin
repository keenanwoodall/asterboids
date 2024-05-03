package game

import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"

ScreenShakes :: struct {
    pool : Pool(32, ScreenShake)
}

ScreenShake :: struct {
    start_time : f64,
    decay      : f32,
    freq       : f32,
    force      : rl.Vector2,
}

init_screenshakes :: proc(using screenshakes : ^ScreenShakes) {
    init_pool(&pool)
}

unload_screenshakes :: proc(using screenshakes : ^ScreenShakes) {
    delete_pool(&pool)
}

shake :: proc(using screenshake : ScreenShake, time : f64) -> (amplitude : rl.Vector2, energy : f32) {
    shake_time := f32(time - start_time)
    amplitude = force * math.sin(freq * shake_time) // Oscillating shake effect
    energy = math.exp(-decay * shake_time) // Exponential decay (https://www.desmos.com/calculator/ko3q2jgnu
    return
}

// Sums the shakes into a single 2d camera offset. Releases any screenshake instances which have decayed.
// Optional release_decay parameter can be used to set when screenshakes are automatically released back to the pool
// A decay of 0.01 means 1% of the input shake force.
sum_shake :: proc(using screenshakes : ^ScreenShakes, time : f64, release_decay : f32 = 0.01) -> rl.Vector2 {
    sum := rl.Vector2{}

    for i := 0; i < pool.count; i += 1 {
        screenshake := &pool.instances[i]
        amp, decay := shake(screenshake^, time)
        sum += amp * decay
        if decay < release_decay {
            release_pool(&pool, i)
            i -= 1
        }
    }

    return sum
}