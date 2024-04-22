// This code detects and handles collision between projectiles and enemies/walls.

package game

import "core:fmt"
import "core:time"
import "core:math"
import "core:math/rand"
import "core:math/linalg"
import rl "vendor:raylib"

// Releases any offscreen projectiles.
@(optimization_mode="speed")
tick_projectiles_screen_collision :: proc(projectiles : ^Projectiles) {
    instances := projectiles.instances
    for proj_idx := 0; proj_idx < projectiles.count; proj_idx += 1 {
        proj := projectiles.instances[proj_idx]

        if position_offscreen(proj.pos) {
            release_projectile(proj_idx, projectiles)
            proj_idx -= 1
            continue
        }
    }
}

// Handles collisions between projectiles and enemies.
// Deals damage to enemies, spawns hit vfx, player hit sfx etc
@(optimization_mode="speed")
tick_projectiles_enemy_collision :: proc(projectiles : ^Projectiles, enemies : ^Enemies, ps : ^ParticleSystem, audio : ^Audio) {
    instances := projectiles.instances
    // Iterate over all projectiles
    #no_bounds_check projectile_loop : for proj_idx := 0; proj_idx < projectiles.count; proj_idx += 1 {
        // Get a copy of the current projectile.
        proj := projectiles.instances[proj_idx]

        // Get the coordinate of the enemy cell that the projectile is over.
        // To learn more about the enemy grid, check out the enemies.odin and hgrid.odin files.
        enemy_cell_check_origin := get_cell_coord(enemies.grid, proj.pos)
        // The projectile's length may surpass the size of an enemy grid cell.
        // This calculates the number of neighboring cells we need to check to properly check for collisions along the entire length of the projectile.
        enemy_cell_check_radius := int(math.ceil(proj.len / enemies.grid.cell_size))

        // Iterate over neighboring enemy grid cells...
        for cell_x_offset in -enemy_cell_check_radius..=enemy_cell_check_radius {
            for cell_y_offset in -enemy_cell_check_radius..=enemy_cell_check_radius {
                // Get the cell coordinate of the current cell we want to check.
                cell_coord := enemy_cell_check_origin + {cell_x_offset, cell_y_offset}
                // See if there are any enemies in the current cell.
                cell_data, ok := get_cell_data(enemies.grid, cell_coord);
                // If not, continue to the next cell.
                if !ok do continue

                // Iterate over all enemy (indices) in the current cell
                for enemy_idx in cell_data {
                    // Get a reference to the current enemy and check if the projectile hit it
                    enemy := &enemies.instances[enemy_idx]
                    hit, hit_point, hit_normal := check_enemy_line_collision(proj.pos, proj.pos + proj.dir * proj.len, enemy^)
                    
                    if !hit do continue 

                    // The projectile hit the enemy, so let's do stuff
                    enemy.vel += proj.dir * 1000 / enemy.siz    // Add knockback to the enemy
                    enemy.hp -= 1                               // Damage the enemy
                    proj.bounces -= 1                           // Decrement the projectile bounce counter
                    
                    // Set the projectile's direction to reflect off of the enemy edge
                    proj.dir = linalg.normalize(linalg.reflect(proj.dir, hit_normal))

                    // Reassign the modified projectile to the array
                    projectiles.instances[proj_idx] = proj

                    // Spawn particles from the hit point along the projectile's direction
                    spawn_particles_direction(
                        particle_system = ps,
                        center          = hit_point,
                        direction       = proj.dir,
                        count           = 32,
                        min_speed       = 50, 
                        max_speed       = 250,
                        min_lifetime    = 0.05,
                        max_lifetime    = 0.5,
                        color           = enemy.col,
                        angle           = 0.4,
                        drag            = 1,
                    )

                    // If the enemy hp 0, mark them as killed and play sfx
                    if enemy.hp <= 0 {
                        try_play_sound(audio, audio.explosion, debounce = 0.1)
                        enemy.kill = true
                    }
                    
                    // Play projectile impact sfx
                    try_play_sound(audio, audio.impact, debounce = 0.1)

                    // If the projectile doesn't have any bounces left, release it
                    if proj.bounces < 0 {
                        release_projectile(proj_idx, projectiles)
                        proj_idx -= 1
                        continue projectile_loop
                    } // Otherwise, play projectile deflection sfx
                    else do try_play_sound(audio, audio.deflect)
                }
            }
        }
    }
}

// Utility function to check if a position is offscreen
@(private)
position_offscreen :: proc(pos : rl.Vector2) -> bool {
    width   := f32(rl.GetScreenWidth())
    height  := f32(rl.GetScreenHeight())
    if pos[0] < 0 || pos[0] > width do return true
    if pos[1] < 0 || pos[1] > height do return true
    
    return false
}