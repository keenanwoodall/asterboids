// Manages mine state and logic. Mines are hazards which can explode when hit by the player
package game

import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"

MINE_RADIUS :: 10
MINE_DAMAGE :: 100
MINE_HP     :: 2
MINE_GRID_CELL_SIZE :: MINE_RADIUS * 4

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
    init_grid(&mines.grid, MINE_GRID_CELL_SIZE)
}

unload_mines :: proc(mines : ^Mines) {
    delete_pool(&mines.pool)
}

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
        mine.radius = math.lerp(mine.radius, MINE_RADIUS, 1 - math.exp(-game.game_delta_time * 10))
    }
}

tick_player_mines_collision :: proc(using game : ^Game) {
    player_corners := get_player_corners(player)
    mine_radius_sqr :f32= MINE_RADIUS * MINE_RADIUS
    for &mine in mines.pool.instances[0:mines.pool.count] {
        for corner in player_corners {
            if linalg.length2(corner - mine.pos) < mine_radius_sqr {
                player.hth -= MINE_DAMAGE
                mine.destroyed = true
            }
        }
    }
}

tick_destroyed_mines :: proc(using game : ^Game) {
    // Destruction
    for i :int= 0; i < game.mines.pool.count; i += 1 {
        mine := &mines.pool.instances[i]

        if !mine.destroyed && mine.hp > 0 do continue

        release_pool(&mines.pool, i)
        i -= 1
    }
}

draw_mines :: proc(using game : Game) {
    for mine in mines.pool.instances[0:mines.pool.count] {
        rl.DrawCircleV(mine.pos, mine.radius, rl.DARKGRAY)
    }

    for mine in mines.pool.instances[0:mines.pool.count] {
        flash := math.mod(mine.time, 1) > 0.5

        //if flash do rl.DrawCircleV(mine.pos, MINE_RADIUS * 8, { 255, 0, 0, 10 })

        col := rl.RED if flash else rl.Color{ 100, 0, 0, 255 }
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