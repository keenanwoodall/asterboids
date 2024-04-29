// This is a little helper struct for performing *something* at an arbitrary rate alongside a game loop running at an arbitrary framerate.
// Probably not super precise.
package game

import "core:fmt"
import "core:math"

Timer :: struct {
    rate : f64,
    ticks : u64,   // Increments at the given rate
    last_tick_delta : u64,
    last_tick_time  : f64,
    time : f64,
}

// ticks a heartbeat. returns the number of "beats" expected at its rate.
tick_timer :: proc(using timer : ^Timer, dt : f32) -> int {
    dt_f64 := f64(dt)
    time += dt_f64
    new_ticks := time - last_tick_time
    last_tick_delta = u64(new_ticks * rate)
    if last_tick_delta > 0 {
        last_tick_time = time
    }
    ticks += last_tick_delta

    return int(last_tick_delta)
}