package game

import "core:fmt"
import "core:time"
import "core:math"
import "core:math/rand"
import "core:math/linalg"
import rl "vendor:raylib"

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
@(optimization_mode="speed")
tick_projectiles_enemy_collision :: proc(projectiles : ^Projectiles, enemies : ^Enemies, ps : ^ParticleSystem, audio : ^Audio) {
    instances := projectiles.instances
    #no_bounds_check projectile_loop : for proj_idx := 0; proj_idx < projectiles.count; proj_idx += 1 {
        proj := projectiles.instances[proj_idx]

        enemy_cell_check_origin := get_cell_coord(enemies.grid, proj.pos)
        enemy_cell_check_radius := int(math.ceil(proj.len / enemies.grid.cell_size))

        for cell_x_offset in -enemy_cell_check_radius..=enemy_cell_check_radius {
            for cell_y_offset in -enemy_cell_check_radius..=enemy_cell_check_radius {
                cell_coord := enemy_cell_check_origin + {cell_x_offset, cell_y_offset}
                if cell_data, ok := get_cell_data(enemies.grid, cell_coord); ok {
                    for enemy_idx in cell_data {
                        enemy := &enemies.instances[enemy_idx]
                        hit, hit_point, hit_normal := check_enemy_line_collision(proj.pos, proj.pos + proj.dir * proj.len, enemy^)
                        if hit {
                            hit_normal := linalg.normalize(hit_point - enemy.pos)
                            enemy.vel += proj.dir * 1000 / enemy.siz
                            enemy.hp -= 1
                            proj.bounces -= 1
                            
                            proj.dir = linalg.normalize(linalg.reflect(proj.dir, hit_normal))
                            projectiles.instances[proj_idx] = proj
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

                            if enemy.hp <= 0 {
                                try_play_sound(audio, audio.explosion, debounce = 0.1)
                                enemy.kill = true
                            }
                            
                            try_play_sound(audio, audio.impact, debounce = 0.1)

                            if proj.bounces < 0 {
                                release_projectile(proj_idx, projectiles)
                                proj_idx -= 1
                                continue projectile_loop
                            }
                            else do try_play_sound(audio, audio.deflect)
                        }
                    }
                }
            }
        }
    }
}

@(private)
position_offscreen :: proc(pos : rl.Vector2) -> bool {
    width   := f32(rl.GetScreenWidth())
    height  := f32(rl.GetScreenHeight())
    if pos[0] < 0 || pos[0] > width do return true
    if pos[1] < 0 || pos[1] > height do return true
    
    return false
}