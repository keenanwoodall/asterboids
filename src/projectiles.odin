package game

import "core:math"
import rl "vendor:raylib"

MAX_PROJECTILES :: 8192

Projectile :: struct {
    pos : rl.Vector2,
    dir : rl.Vector2,
    spd : f32,
    len : f32,
    bounces : int
}

Projectiles :: struct {
    count     : int,
    instances : #soa[MAX_PROJECTILES]Projectile
}

init_projectiles :: proc(using projectiles : ^Projectiles) {
    count = 0
}

tick_projectiles :: proc(using projectiles : ^Projectiles, dt : f32) {
    #no_bounds_check for i := 0; i < count; i += 1 {
        instances[i].pos += instances[i].dir * instances[i].spd * dt
    }
}

draw_projectiles :: proc(using projectiles : ^Projectiles) {
    rl.rlSetLineWidth(2)
    #no_bounds_check for i in 0..<count {
        using inst := instances[i]
        rl.DrawLineV(pos, pos + dir * len, rl.ORANGE)
    }
}

add_projectile :: proc(newProjectile : Projectile, using projectiles : ^Projectiles) {
    if count == MAX_PROJECTILES {
        return
    }
    instances[count] = newProjectile 
    count += 1
}

release_projectile :: proc(index : int, using projectiles : ^Projectiles) {
    instances[index] = instances[count - 1]
    count -= 1
}