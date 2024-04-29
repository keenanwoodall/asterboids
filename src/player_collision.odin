// This code detects and handles collision between the player and enemies

package game

import "core:fmt"
import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"

PLAYER_DAMAGE_DEBOUNCE  :: 0.75

// Tick functions are called every frame by the game.
// This checks whether the player is overlapping any enemies, and deals damage to the player if so.
tick_player_enemy_collision :: proc(using game : ^Game) {
    if !player.alive do return

    if game_time - player.last_damage_time < PLAYER_DAMAGE_DEBOUNCE do return

    // We are going to use the enemies hgrid to minimize the number of necessary enemy collision checks.
    // Get the coordinate of the enemy cell the player is currently inside.
    player_cell_coord       := get_cell_coord(enemies.grid, player.pos)
    // Then get the indices of the enemies which are in the same cell as the player.
    enemy_indices, exists   := get_cell_data(enemies.grid, player_cell_coord)
    // If there isn't a cell at the player's position, there aren't any enemies nearby and we can return.
    if !exists do return

    
    // Iterate over the enemies in the same cell as the player and apply damage for each collision.
    for enemy_idx in enemy_indices {
        using enemy := &enemies.instances[enemy_idx]
        if hit, point := check_player_enemy_collision(player, enemy^); hit {
            knock_back_dir := linalg.normalize(player.pos - enemy.pos)
            particle_dir := linalg.normalize(enemy.pos - player.pos)

            spawn_particles_direction(&pixel_particles, player.pos, particle_dir, count = 32, min_speed = 50, max_speed = 300, min_lifetime = 0.1, max_lifetime = 0.75, color = rl.RAYWHITE, angle = math.PI / 3, drag = 5)
            try_play_sound(&audio, audio.damage)

            player.vel = knock_back_dir * player.knockback
            player.last_damage_time = game_time
            player.hth -= enemy.dmg

            enemy.vel = -knock_back_dir * player.knockback

            break
        }
    }

    // Note: Checking the enemies in the same cell as the player is not quite thorough
    // because the player could be overlapping multiple cells.
    // In practice, this has been fine tho

    // If the players health is 0, indicate they are no longer alive and spawn some death particles.
    if player.hth <= 0 {
        player.alive = false
        player.hth = 0

        spawn_particles_triangle_segments(&line_trail_particles, get_player_corners(player), rl.RAYWHITE, player.vel, 0.4, 5.0, 50, 150, 2, 2, 3)
        spawn_particles_burst(&line_trail_particles, player.pos, player.vel, 128, 200, 1200, 0.2, 1.5, rl.RAYWHITE, drag = 3)
        spawn_particles_burst(&line_particles, player.pos, player.vel, 64, 100, 1500, 0.3, 1.5, rl.SKYBLUE, drag = 2)
        try_play_sound(&audio, audio.die)
    }
}

// Checks collision between a player and an enemy.
// The player is a square and the enemies are triangles, so we can simply do line-line intersection tests for each line in the player and enemy.
check_player_enemy_collision :: proc(player : Player, enemy : Enemy) -> (hit : bool, point : rl.Vector2) {
    // Note: If the difference in size between a player and enemy is large enough,
    // one could be *inside* the other without collision being detected.
    // In practice, this is not an issue.
    enemy_corners   := get_enemy_corners(enemy)
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