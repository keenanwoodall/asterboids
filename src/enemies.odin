package game

import fmt      "core:fmt"
import math     "core:math"
import time     "core:time"
import rand     "core:math/rand"
import linalg   "core:math/linalg"
import rl       "vendor:raylib"

MAX_ENEMIES             :: 4096
ENEMY_SIZE              :: 5
ENEMY_SPEED             :: 1400
ENEMY_TURN_SPEED        :: 10
ENEMY_FORCE             :: .2
ENEMY_ALIGNMENT_RADIUS  :: 50
ENEMY_COHESION_RADIUS   :: 50
ENEMY_SEPARATION_RADIUS :: 20
ENEMY_FOLLOW_FACTOR     :: 2.0
ENEMY_ALIGNMENT_FACTOR  :: 1.0
ENEMY_COHESION_FACTOR   :: 1.25
ENEMY_SEPARATION_FACTOR :: 3.0

Enemy :: struct {
    pos     : rl.Vector2,
    vel     : rl.Vector2,
    rot     : f32,
    siz     : f32,
    col     : rl.Color,
    hp      : int,
    kill    : bool
}

Enemies :: struct {
    count       : int,
    grid        : ^HGrid(Enemy),
    instances   : [MAX_ENEMIES]Enemy,
}

init_enemies :: proc(using enemies : ^Enemies) {
    count       = 0
    grid        = new(HGrid(Enemy))
    cell_size   : f32 = max(ENEMY_ALIGNMENT_RADIUS, ENEMY_COHESION_RADIUS, ENEMY_SEPARATION_RADIUS)
    init_cell_data(grid, cell_size)
}

unload_enemies :: proc(using enemies : ^Enemies) {
    delete_cell_data(grid)
    free(grid)
}

@(optimization_mode="speed")
tick_enemies :: proc(using enemies : ^Enemies, player : ^Player, dt : f32) {
    clear_cell_data(grid)

    for i in 0..<count {
        using enemy := instances[i]
        cell_coord := get_cell_coord(grid, pos)
        insert_cell_data(grid, cell_coord, &instances[i])
    }

    for enemy, i in instances[:count] {
        using enemy := instances[i]

        // Sum steering forces
        steer_force := rl.Vector2{}
        steer_force += follow(i, enemies, player.pos) * ENEMY_FOLLOW_FACTOR
        steer_force += alignment(i, enemies) * ENEMY_ALIGNMENT_FACTOR
        steer_force += cohesion(i, enemies) * ENEMY_COHESION_FACTOR
        steer_force += separation(i, enemies) * ENEMY_SEPARATION_FACTOR
        
        vel += steer_force
        vel = limit_length(vel, ENEMY_SPEED / siz)

        pos += vel * dt

        if dir, ok := safe_normalize(vel); ok {
            rot = math.angle_lerp(rot, math.atan2(dir.y, dir.x) - math.PI / 2, 1 - math.exp(-dt * ENEMY_TURN_SPEED))
        }

        instances[i] = enemy
    }
}

draw_enemies :: proc(using enemies : ^Enemies) {
    rl.rlSetLineWidth(3)
    for i in 0..<count {
        using enemy := instances[i]
        corners     := get_enemy_corners(enemy)
        rl.DrawTriangle(corners[0], corners[2], corners[1], col)
    }
}

add_enemy :: proc(new_enemy : Enemy, using enemies : ^Enemies) {
    if count == MAX_ENEMIES {
        return
    }
    instances[count] = new_enemy
    count += 1
}

release_enemy :: proc(index : int, using enemies : ^Enemies) {
    instances[index] = instances[count - 1]
    count -= 1
}

release_killed_enemies :: proc(using enemies : ^Enemies, ps : ^ParticleSystem) {
    for i in 0..<count {
        using enemy := instances[i]
        if kill {
            release_enemy(i, enemies)
            spawn_particles_triangle_segments(ps, get_enemy_corners(enemy), col, vel, 0.5, 1.0, 50, 150, 2, 10, 3)
        }
    }
}

draw_enemies_grid :: proc(using enemies : ^Enemies) {
    for cell in grid.cells {
        rl.DrawRectangleLinesEx({f32(cell.x) * grid.cell_size, f32(cell.y) * grid.cell_size, grid.cell_size, grid.cell_size}, 1, {255, 255, 255, 20})
    }
}

get_enemy_corners :: proc(using enemy : Enemy) -> [3]rl.Vector2 {
    corners := [3]rl.Vector2 { {-1, -1}, {+1, -1}, {0, +1.5} }
    for i in 0..<3 {
        corners[i] = rl.Vector2Rotate(corners[i], rot)
        corners[i] *= siz
        corners[i] += pos
    }
    return corners
}

check_enemy_line_collision :: proc(line_start, line_end : rl.Vector2, enemy : Enemy) -> (hit : bool, point, normal : rl.Vector2) {
    corners := get_enemy_corners(enemy)

    for i := 0; i < len(corners); i += 1 {
        enemy_corner_start  := corners[i]
        enemy_corner_end    := corners[(i + 1) % len(corners)]

        point : rl.Vector2 = {}

        if rl.CheckCollisionLines(line_start, line_end, enemy_corner_start, enemy_corner_end, &point) {
            tangent := linalg.normalize(enemy_corner_start - enemy_corner_end)
            normal  := rl.Vector2Rotate(tangent, -math.TAU)
            return true, point, normal
        }
    }

    return false, {}, {}
}

@(private="file")
follow :: proc(index : int, using enemies : ^Enemies, target : rl.Vector2) -> rl.Vector2 {
    current  := instances[index]
    steering := linalg.normalize(target - current.pos) * ENEMY_SPEED
    steering -= current.vel
    steering = limit_length(steering, ENEMY_FORCE)
    return steering
}

@(private="file")
alignment :: proc(index : int, using enemies : ^Enemies) -> rl.Vector2 {
    enemy           := instances[index]
    steering        := rl.Vector2{}
    neighbor_count  := 0
    cell_coord      := get_cell_coord(grid, enemy.pos)

    for x_offset in -1..=1 {
        for y_offset in -1..=1 {
            other_enemies, ok := get_cell_data(grid, cell_coord + {x_offset, y_offset})
            if !ok do continue
            for other_enemy, other_idx in other_enemies {
                // Check if other enemy ptr is to the same address
                if &instances[index] == other_enemies[other_idx] do continue
                
                sqr_dist := linalg.length2(enemy.pos - other_enemy.pos)
                if sqr_dist > ENEMY_ALIGNMENT_RADIUS * ENEMY_ALIGNMENT_RADIUS do continue

                steering += other_enemy.vel
                neighbor_count += 1
            }
        }
    }

    if neighbor_count > 0 {
        steering /= f32(neighbor_count)
        steering = set_length(steering, ENEMY_SPEED)
        steering -= enemy.vel
        steering = limit_length(steering, ENEMY_FORCE)
    }

    return steering
}

@(private="file")
cohesion :: proc (index : int, using enemies : ^Enemies) -> rl.Vector2 {
    enemy           := instances[index]
    steering        := rl.Vector2{}
    neighbor_count  := 0
    cell_coord      := get_cell_coord(grid, enemy.pos)

    for x_offset in -1..=1 {
        for y_offset in -1..=1 {
            other_enemies, ok := get_cell_data(grid, cell_coord + {x_offset, y_offset})
            if !ok do continue
            for other_enemy, other_idx in other_enemies {
                // Check if other enemy ptr is to the same address
                if &instances[index] == other_enemies[other_idx] do continue
                
                sqr_dist := linalg.length2(enemy.pos - other_enemy.pos)
                if sqr_dist > ENEMY_COHESION_RADIUS * ENEMY_COHESION_RADIUS do continue

                steering += other_enemy.pos
                neighbor_count += 1
            }
        }
    }

    if neighbor_count > 0 {
        steering /= f32(neighbor_count)
        steering -= enemy.pos
        steering = set_length(steering, ENEMY_SPEED)
        steering -= enemy.vel
        steering = limit_length(steering, ENEMY_FORCE)
    }

    return steering
}

@(private="file")
separation :: proc (index : int, using enemies : ^Enemies) -> rl.Vector2 {
    enemy         := instances[index]
    steering        := rl.Vector2{}
    neighbor_count  := 0
    cell_coord      := get_cell_coord(grid, enemy.pos)

    for x_offset in -1..=1 {
        for y_offset in -1..=1 {
            other_enemies, ok := get_cell_data(grid, cell_coord + {x_offset, y_offset})
            if !ok do continue
            for other_enemy, other_idx in other_enemies {
                // Check if other enemy ptr is to the same address
                if &instances[index] == other_enemies[other_idx] do continue
                
                sqr_dist := linalg.length2(enemy.pos - other_enemy.pos)
                if sqr_dist > ENEMY_SEPARATION_RADIUS * ENEMY_SEPARATION_RADIUS do continue

                dist := math.sqrt(sqr_dist)

                diff := enemy.pos - other_enemy.pos
                diff /= dist * dist
                steering += diff
                neighbor_count  += 1
            }
        }
    }

    if neighbor_count > 0 {
        steering /= f32(neighbor_count)
        steering = set_length(steering, ENEMY_SPEED)
        steering -= enemy.vel
        steering = limit_length(steering, ENEMY_FORCE)
    }

    return steering
}

@(private="file")
set_length :: proc(v : rl.Vector2, length : f32) -> rl.Vector2 {
    return linalg.normalize(v) * length
}

@(private="file")
limit_length :: proc(v : rl.Vector2, limit : f32) -> rl.Vector2 {
    len := linalg.length(v)
    if len == 0 || len <= limit {
        return v
    }

    dir := v / len
    return dir * limit
}

@(private="file")
safe_normalize :: proc(v : rl.Vector2) -> (rl.Vector2, bool) {
    length := linalg.length(v)
    if length > 0 do return v / length, true
    else do return 0, false
}