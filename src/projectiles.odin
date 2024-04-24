// This code manages the state of all player projectiles: creating, destroying, simulating and drawing them
package game

import "core:math"
import rl "vendor:raylib"

MAX_PROJECTILES :: 8192

// This is the state of a single projectile.
Projectile :: struct {
    pos : rl.Vector2,   // Position
    dir : rl.Vector2,   // Direction
    spd : f32,          // Speed
    len : f32,          // Length
    bounces : int       // Bounces remaining
}

// The projectiles struyct stores the state of all projectiles in a pool.
Projectiles :: struct {
    count     : int,
    instances : [MAX_PROJECTILES]Projectile,
}

// Init functions are called when the game first starts.
// Here we can assign default values
init_projectiles :: proc(using projectiles : ^Projectiles) {
    count = 0
}

// Tick functions are called every frame by the game.
// Move each projectile forward based on their speed.
tick_projectiles :: proc(using projectiles : ^Projectiles, dt : f32) {
    #no_bounds_check for i := 0; i < count; i += 1 {
        instances[i].pos += instances[i].dir * instances[i].spd * dt
    }
}

// Draw functions are called at the end of each frame by the game.
// Each projectile is just a line from its position along its direction of movement
draw_projectiles :: proc(using projectiles : ^Projectiles) {
    rl.rlSetLineWidth(2)
    #no_bounds_check for i in 0..<count {
        using inst := instances[i]
        rl.DrawLineV(pos, pos + dir * len, rl.ORANGE)
    }
}

// Adds a new projectile to the pool
add_projectile :: proc(newProjectile : Projectile, using projectiles : ^Projectiles) {
    if count == MAX_PROJECTILES {
        return
    }
    instances[count] = newProjectile 
    count += 1
}

// Removes a projectile from the pool
release_projectile :: proc(index : int, using projectiles : ^Projectiles) {
    instances[index] = instances[count - 1]
    count -= 1
}