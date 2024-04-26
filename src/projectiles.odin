// This code manages the state of all player projectiles: creating, destroying, simulating and drawing them
package game

import "core:fmt"
import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"

MAX_PROJECTILES :: 8192

// This is the state of a single projectile.
Projectile :: struct {
    pos     : rl.Vector2,   // Position
    dir     : rl.Vector2,   // Direction
    spd     : f32,          // Speed
    len     : f32,          // Length
    bounces : int,          // Bounces remaining,
    col     : rl.Color
}

// The projectiles struyct stores the state of all projectiles in a pool.
Projectiles :: struct {
    homing_speed        : f32,  // How fast projectiles turn towards their homing target
    homing_dist         : int,  // How far (in grid cells) projectiles search for a homing target
    deflect_off_window  : bool, // When true, projectiles will bounce of the edges of the game window
    count               : int,  // The number of active projectile instances in the pool
    instances           : [MAX_PROJECTILES]Projectile,
}

// Init functions are called when the game first starts.
// Here we can assign default values
init_projectiles :: proc(using projectiles : ^Projectiles) {
    count = 0
    homing_speed = 0
    homing_dist = 0
    deflect_off_window = false
}

// Tick functions are called every frame by the game.
// Move each projectile forward based on their speed.
tick_projectiles :: proc(using projectiles : ^Projectiles, enemies : Enemies, dt : f32) {
    #no_bounds_check for &proj in projectiles.instances {
        proj.pos += proj.dir * proj.spd * dt
    }

    if homing_dist > 0 {
        #no_bounds_check for &proj, proj_idx in projectiles.instances[0:count] {
            closest_enemy_distance  : f32 = max(f32)
            closest_enemy_idx       : int = -1

            cell_coord              := get_cell_coord(enemies.grid, proj.pos)

            for x_offset := -homing_dist; x_offset < homing_dist; x_offset += 1 {
                for y_offset := -homing_dist; y_offset < homing_dist; y_offset += 1 {
                    enemy_indices, exists := get_cell_data(enemies.grid, cell_coord + { x_offset, y_offset })
                    if exists {
                        for enemy_idx in enemy_indices {
                            enemy   := enemies.instances[enemy_idx]
                            dir     := linalg.normalize(enemy.pos - proj.pos)

                            // Only track enemies that are in front of the projectile
                            if linalg.dot(dir, proj.dir) < 0.5 do continue

                            dist    := linalg.distance(enemy.pos, proj.pos)

                            if dist < closest_enemy_distance {
                                closest_enemy_distance = dist
                                closest_enemy_idx = enemy_idx
                            }
                        }
                    }
                }
            }

            if closest_enemy_idx < 0 do continue

            closest_enemy   := enemies.instances[closest_enemy_idx]
            target_dir      := linalg.normalize(closest_enemy.pos - proj.pos)

            proj.dir = linalg.vector_slerp(proj.dir, target_dir, dt * homing_speed)
        }
    }
}

// Draw functions are called at the end of each frame by the game.
// Each projectile is just a line from its position along its direction of movement
draw_projectiles :: proc(using projectiles : ^Projectiles) {
    rl.rlSetLineWidth(2)
    #no_bounds_check for i in 0..<count {
        using inst := instances[i]
        rl.DrawLineV(pos, pos + dir * len, col)
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