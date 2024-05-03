// This code detects and handles collision between the player and enemies/mines/projectiles

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

            // Screenshake
            add_pool(&screenshakes.pool, ScreenShake { start_time = game_time, decay = 2, freq = 12, force = -knock_back_dir * 8 })

            break
        }
    }

    // Note: Checking the enemies in the same cell as the player is not quite thorough
    // because the player could be overlapping multiple cells.
    // In practice, this has been fine tho
}

// Tick functions are called every frame by the game.
// This checks whether the player is overlapping any enemy projectiles, and deals damage/knockback to the player if so.
tick_player_projectile_collision :: proc(using game : ^Game) {
    if !player.alive do return

    // We are going to use the enemies hgrid to minimize the number of necessary enemy collision checks.
    // Get the coordinate of the enemy cell the player is currently inside.
    player_cell_coord := get_cell_coord(enemies.grid, player.pos)
    
    // Iterate over the enemies in the same cell as the player and apply damage for each collision.
    for i := 0; i < enemy_projectiles.count; i += 1 {
        using proj := &enemy_projectiles.instances[i]
        if hit, point, normal := check_player_line_collision(pos, pos + dir * len, player); hit {
            knock_back_dir := -normal
            particle_dir := -knock_back_dir

            spawn_particles_direction(&pixel_particles, player.pos, particle_dir, count = 32, min_speed = 50, max_speed = 300, min_lifetime = 0.1, max_lifetime = 0.75, color = rl.RAYWHITE, angle = math.PI / 3, drag = 5)
            try_play_sound(&audio, audio.damage)

            player.vel += knock_back_dir * player.knockback * 0.5

            if game_time - player.last_damage_time > PLAYER_DAMAGE_DEBOUNCE
            {
                player.last_damage_time = game_time
                player.hth -= ENEMY_PROJECTILE_DAMAGE
            }

            // Screenshake
            add_pool(&screenshakes.pool, ScreenShake { start_time = game_time, decay = 2.5, freq = 18, force = knock_back_dir * 6 })

            release_projectile(i, &enemy_projectiles)
            i -= 1
    
            break
        }
    }

    // Note: Checking the enemies in the same cell as the player is not quite thorough
    // because the player could be overlapping multiple cells.
    // In practice, this has been fine tho
}

// Tick functions are called every frame. Checks if the player is overlapping a mine
tick_player_mines_collision :: proc(using game : ^Game) {
    player_corners := get_player_corners(player)
    mine_radius_sqr :f32= MINE_RADIUS * MINE_RADIUS
    for &mine in mines.pool.instances[0:mines.pool.count] {
        for corner in player_corners {
            if linalg.length2(corner - mine.pos) < mine_radius_sqr {
                mine.destroyed = true
            }
        }
    }
}

// Checks collision between a player and an enemy.
// The player is a triangle and the enemies are triangles, so we can simply do line-line intersection tests for each line in the player and enemy.
check_player_enemy_collision :: proc(player : Player, enemy : Enemy) -> (hit : bool, point : rl.Vector2) {
    // Note: If the difference in size between a player and enemy is large enough,
    // one could be *inside* the other without collision being detected.
    // In practice, this is not an issue.
    enemy_corners   := get_enemy_corners(enemy)
    player_corners  := get_player_corners(player)
    
    // For each player corner index...
    for pi in 0..<len(player_corners) 
    {
        // The first index is just the iterated index.
        // The second index the first index + 1, but I'm using modulo to loop it back around if it exceeds the number of corners
        player_corner_idx_1 := pi
        player_corner_idx_2 := (pi + 1) % len(player_corners)
        player_corner_1     := player_corners[player_corner_idx_1]
        player_corner_2     := player_corners[player_corner_idx_2]
        // For each enemy corner index
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

// Returns true if the provided line intersects the segments of a player. If true, also returns the intersection point/normal
check_player_line_collision :: proc(line_start, line_end : rl.Vector2, player : Player) -> (hit : bool, point, normal : rl.Vector2) {
    corners := get_player_corners(player)

    // Iterate over each segment
    for i := 0; i < len(corners); i += 1 {
        player_corner_start  := corners[i]
        player_corner_end    := corners[(i + 1) % len(corners)]

        point : rl.Vector2 = {}

        if rl.CheckCollisionLines(line_start, line_end, player_corner_start, player_corner_end, &point) {
            tangent := linalg.normalize(player_corner_start - player_corner_end)
            normal  := rl.Vector2Rotate(tangent, -math.TAU)
            return true, point, normal
        }
    }

    return false, {}, {}
}