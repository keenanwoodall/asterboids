package game

import fmt      "core:fmt"
import time     "core:time"
import math     "core:math"
import rand     "core:math/rand"
import linalg   "core:math/linalg"
import rl       "vendor:raylib"

@(optimization_mode="speed")
tick_projectiles_collision :: proc(projectiles : ^Projectiles, enemies : ^Enemies) {
    instances := projectiles.instances
    for proj_idx := 0; proj_idx < projectiles.count; proj_idx += 1 {
        proj := projectiles.instances[proj_idx]

        if position_offscreen(proj.pos) {
            release_projectile(proj_idx, projectiles)
            proj_idx -= 1
            continue
        }

        for enemy_idx := 0; enemy_idx < enemies.count; enemy_idx += 1 {
            enemy := enemies.instances[enemy_idx]
            hit, hit_point, hit_normal := check_enemy_line_collision(proj.pos, proj.pos + proj.dir * proj.len, enemy)

            if hit {
                hit_normal := linalg.normalize(hit_point - enemy.pos)
                enemy.vel += proj.dir * 1000 / enemy.siz
                enemy.hp -= 1

                proj.dir = linalg.normalize(linalg.reflect(proj.dir, hit_normal))
                projectiles.instances[proj_idx] = proj
                spawn_particles_burst(particle_system, hit_point, 16, 50, 250, 0.05, 0.2, rl.YELLOW)

                if enemy.hp <= 0 {
                    try_play_sound(audio, audio.explosion, debounce = 0.1)
                    release_enemy(enemy_idx, enemies)
                    enemy_idx -= 1
                    continue
                }
                else {
                    try_play_sound(audio, audio.impact, debounce = 0.1)
                    enemies.instances[enemy_idx] = enemy;
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