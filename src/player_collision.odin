package game

import "core:fmt"
import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"

ENEMY_DPS :: 300

tick_player_enemy_collision_:: proc(using player : ^Player, enemies : ^Enemies, ps : ^ParticleSystem, dt : f32) {
    if !alive do return

    player_cell_coord       := get_cell_coord(enemies.grid, pos)
    enemy_indices, exists   := get_cell_data(enemies.grid, player_cell_coord)
    if !exists do return
    for enemy_idx in enemy_indices {
        using enemy := &enemies.instances[enemy_idx]
        if hit, point := check_player_enemy_collision(player, enemy); hit {
            hth -= dt * ENEMY_DPS
        }
    }

    if hth <= 0 {
        alive = false
        hth = 0

        spawn_particles_burst(ps, pos, vel, 128, 200, 1000, 0.2, 1.5, rl.RAYWHITE, drag = 5)
    }
}

check_player_enemy_collision :: proc(player : ^Player, enemy : ^Enemy) -> (hit : bool, point : rl.Vector2) {
    enemy_corners   := get_enemy_corners(enemy^)
    player_corners  := get_player_corners(player)
    
    for pi in 0..<len(player_corners) {
        player_corner_idx_1 := pi
        player_corner_idx_2 := (pi + 1) % len(player_corners)
        player_corner_1     := player_corners[player_corner_idx_1]
        player_corner_2     := player_corners[player_corner_idx_2]
        for ei in 0..<len(enemy_corners) {
            enemy_corner_idx_1  := ei
            enemy_corner_idx_2  := (ei + 1) % len(enemy_corners)
            enemy_corner_1      := enemy_corners[enemy_corner_idx_1]
            enemy_corner_2      := enemy_corners[enemy_corner_idx_2]

            collision_point     := rl.Vector2{}
            if rl.CheckCollisionLines(player_corner_1, player_corner_2, enemy_corner_1, enemy_corner_2, &collision_point) {
                return true, collision_point
            }
        }   
    }

    return false, {}
}