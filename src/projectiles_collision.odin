package game

import fmt      "core:fmt"
import time     "core:time"
import math     "core:math"
import rand     "core:math/rand"
import linalg   "core:math/linalg"
import rl       "vendor:raylib"

tick_projectiles_collision :: proc(projectiles : ^Projectiles, particle_system : ^ParticleSystem, enemies : ^Enemies) {
    for enemy_idx := 0; enemy_idx < enemies.count; enemy_idx += 1 {
        enemy := enemies.instances[enemy_idx]
        for proj_idx := 0; proj_idx < projectiles.count; proj_idx += 1 {
            proj := projectiles.instances[proj_idx]

            hit, hit_point, hit_normal := check_enemy_line_collision(proj.pos, proj.pos + proj.dir * proj.len, enemy)

            if hit {
                hit_normal := linalg.normalize(hit_point - enemy.pos)
                enemy.vel += proj.dir * 1000 / enemy.siz
                enemy.hp -= 1
                if enemy.hp <= 0 {
                    rl.PlaySound(sounds.explosion)
                    release_enemy(enemy_idx, enemies)
                    enemy_idx -= 1
                }
                else {
                    rl.PlaySound(sounds.impact)
                    enemies.instances[enemy_idx] = enemy;
                }

                proj.dir = linalg.normalize(linalg.reflect(proj.dir, hit_normal))
                projectiles.instances[proj_idx] = proj
                spawn_particles_burst(particle_system, hit_point, 16, 50, 250, 0.05, 0.2, rl.YELLOW)
                //release_projectile(proj_idx, projectiles)
                //proj_idx -= 1
            }
        }
    }
}
