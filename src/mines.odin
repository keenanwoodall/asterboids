// Manages mine state and logic. Mines are hazards which can explode when hit by the player
package game

import "core:fmt"
import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"

MINE_RADIUS             :: 10
MINE_RADIUS_SQR         :: MINE_RADIUS * MINE_RADIUS
MINE_DAMAGE_RADIUS      :: 175
MINE_DAMAGE_RADIUS_SQR  :: MINE_DAMAGE_RADIUS * MINE_DAMAGE_RADIUS
MINE_DAMAGE             :: 100
MINE_KNOCKBACK          :: 2000
MINE_HP                 :: 1

Mines :: struct {
    pool : Pool(500, Mine),     // Pool of mine instances
    grid : HGrid(int),          // Hash grid used to speed up finding mines
}

Mine :: struct {
    pos         : rl.Vector2,
    hp          : int,
    destroyed   : bool,
    time        : f32,          // How long the mine has been alive
    radius      : f32,          // Current radius of the mine.
}

init_mines :: proc(mines : ^Mines) {
    init_pool(&mines.pool)
    init_grid(&mines.grid, MINE_DAMAGE_RADIUS)
}

unload_mines :: proc(mines : ^Mines) {
    delete_pool(&mines.pool)
}

// Tick functions are called every frame. Rebuilds the mines' hashgrid, increments each mines internal timer and animates its radius.
tick_mines :: proc(using game : ^Game) {
    player_corners := get_player_corners(player)
    mine_radius_sqr :f32= MINE_RADIUS * MINE_RADIUS

    clear_grid(&mines.grid)

    // Rebuild hash grid
    for i :int= 0; i < game.mines.pool.count; i += 1 {
        mine := &mines.pool.instances[i]
        cell_coord := get_cell_coord(mines.grid, mine.pos)
        insert_grid_data(&mines.grid, cell_coord, i)

        mine.time += game_delta_time
        mine.radius = math.lerp(mine.radius, MINE_RADIUS, 1 - math.exp(-game.game_delta_time * 5))
    }
}

// Spawns explosion particles and deals damage/knockback to nearby enemies/player/other mines
tick_destroyed_mines :: proc(using game : ^Game) {
    // Destruction
    for i :int= 0; i < mines.pool.count; i += 1 {
        mine := &mines.pool.instances[i]

        if !mine.destroyed && mine.hp > 0 do continue

        // Damage other nearby mines
        {
            mine_cell_coord := get_cell_coord(mines.grid, mine.pos)

            for x : int = -1; x <= 1; x += 1 {
                for y : int = -1; y <= 1; y += 1 {
                    cell_coord              := mine_cell_coord + { x, y }
                    mine_indices, exists    := get_cell_data(mines.grid, cell_coord)

                    if !exists do continue

                    for mine_idx in mine_indices {
                        // if mine_idx == i do continue // Not worth checking. The current mine is destroyed anyways
                        other_mine := &mines.pool.instances[mine_idx]

                        if linalg.length2(other_mine.pos - mine.pos) > MINE_DAMAGE_RADIUS_SQR {
                            continue
                        }

                        other_mine.hp = 0
                    }
                }   
            }
        }

        // Damage nearby enemies
        {
            // The cell coord the mine occupies on the enemy grid
            mine_enemy_cell_coord := get_cell_coord(enemies.grid, mine.pos)

            enemy_cell_check_radius := int(math.ceil(MINE_DAMAGE_RADIUS / enemies.grid.cell_size))

            for x : int = -enemy_cell_check_radius; x <= enemy_cell_check_radius; x += 1 {
                for y : int = -enemy_cell_check_radius; y <= enemy_cell_check_radius; y += 1 {
                    cell_coord              := mine_enemy_cell_coord + { x, y }
                    enemy_indices, exists   := get_cell_data(enemies.grid, cell_coord)
                    
                    if !exists do continue

                    for enemy_idx in enemy_indices {
                        enemy := &enemies.instances[enemy_idx]

                        dist := linalg.distance(enemy.pos, mine.pos)
                        if dist > MINE_DAMAGE_RADIUS {
                            continue
                        }

                        n_dist := dist / MINE_DAMAGE_RADIUS
                        // Enemy damage is tuned differently since they have way less health than the player.
                        // Note: They should instead have health that's comparable to the player so that this is not necessary.
                        // Damage falloff is done by using the inverse square law
                        n_damage := inv_sqr_interp(1, 0, n_dist) // 1 -> 0
                        damage := int(math.floor(n_damage * 10)) // 10 -> 0
                        enemy.hp -= damage
                        enemy.vel += linalg.normalize(enemy.pos - mine.pos) * MINE_KNOCKBACK * n_damage

                        fmt.printfln("HP: %i, DMG: %i", enemy.hp, damage)
                    }
                }   
            }
        }

        spawn_particles_burst(&pixel_particles, mine.pos, 
            velocity = 0, 
            count = 64, 
            min_speed = 100, 
            max_speed = 700, 
            min_duration = 0.1, 
            max_duration = .3, 
            color = rl.ORANGE, 
            drag = 6,
            size = 4,
        )

        spawn_particles_burst(&line_particles, mine.pos, 
            velocity = 0,
            count = 32, 
            min_speed = 200, 
            max_speed = 900,
            min_duration = 0.1, 
            max_duration = .4,
            color = rl.YELLOW,
            drag = 4,
            size = { 1, 30 },
            angle_offset = math.PI / 2,
        )

        release_pool(&mines.pool, i)
        i -= 1
    }
}

draw_mines :: proc(using game : Game) {
    for mine in mines.pool.instances[0:mines.pool.count] {
        pulse :f32= math.sin(math.mod(mine.time, 2) * 0.5 * math.PI)

        // Draw a pulsing damage radius circle
        rl.DrawCircleV(mine.pos, MINE_DAMAGE_RADIUS, rl.ColorAlpha(rl.RED, pulse * 0.025))

        // Draw the body of the mine
        rl.DrawCircleV(mine.pos, mine.radius, rl.DARKGRAY)

        // Draw a blinking red light in the middle of the mine
        col := rl.RED if math.mod(mine.time, 1) > 0.5 else rl.Color{ 100, 0, 0, 255 }
        rl.DrawCircleV(mine.pos, 5, col)
    }
}

// Returns true if the provided line intersects the segments of an enemy. If true, also returns the intersection point/normal
check_mine_line_collision :: #force_inline proc(line_start, line_end : rl.Vector2, mine : Mine) -> (hit : bool, point, normal : rl.Vector2) {
    return check_circle_line_collision(mine.pos, MINE_RADIUS, line_start, line_end)
}

check_circle_line_collision :: proc(circleCenter : rl.Vector2, circleRadius : f32, lineStart, lineEnd : rl.Vector2) -> (hit : bool, point, normal : rl.Vector2) {
    // Calculate the line vector
    lineVec := lineEnd - lineStart
    
    // Calculate vector from circle center to line start
    centerToLineStart := circleCenter - lineStart
    
    // Project centerToLineStart onto lineVec to find the closest point on the line
    t : f32 = linalg.dot(centerToLineStart, lineVec) / linalg.dot(lineVec, lineVec);
    t = math.max(f32(0), min(t, 1)); // Clamp t to the segment
    
    // Get the closest point on the line to the circle center
    closestPoint := lineStart + lineVec * t;
    
    // Calculate the vector from the circle center to the closest point on the line
    circleToClosest := closestPoint - circleCenter
    distance :f32= linalg.length(circleToClosest)
    
    // Check for collision
    if distance < circleRadius {
        // Calculate normal
        if (distance == 0) {
            // The closest point is the circle center, use any normal (use line normal as default)
            normal := rl.Vector2{-lineVec.y, lineVec.x};
            if (linalg.dot(normal, centerToLineStart) < 0) {
                return true, closestPoint, -normal
            }
        } 
        else do return true, closestPoint, circleToClosest * 1 / distance
    }
    
    return false, 0, 0;
}