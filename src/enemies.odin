package game

import "core:fmt"
import "core:math"
import "core:time"
import "core:math/rand"
import "core:math/linalg"

import rl "vendor:raylib"

import "../external/jobs"

MAX_ENEMIES             :: 1080
ENEMY_SIZE              :: 6
ENEMY_SPEED             :: 2500
ENEMY_TURN_SPEED        :: 10
ENEMY_FORCE             :: 500
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
    kill    : bool,
    loot    : int,
    id      : u8,
}

Enemies :: struct {
    count       : int,
    kill_count  : int,
    grid        : ^HGrid(int),
    instances   : [MAX_ENEMIES]Enemy,
    new_instances   : [MAX_ENEMIES]Enemy,
}

init_enemies :: proc(using enemies : ^Enemies) {
    count       = 0
    kill_count  = 0
    grid        = new(HGrid(int))
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

    if count == 0 do return

    #no_bounds_check for i in 0..<count {
        using enemy := instances[i]
        cell_coord := get_cell_coord(grid^, pos)
        insert_cell_data(grid, cell_coord, i)
    }

    copy_slice(dst = new_instances[:count], src = instances[:count])

    JobData :: struct { 
        read    : []Enemy,
        write   : []Enemy,
        grid    : HGrid(int),
        cell    : [dynamic]int,
        player  : Player,
        dt      : f32 
    }

    jobs_group      : jobs.Group
    cell_jobs       := make([]jobs.Job, len(grid.cells), context.temp_allocator)
    cell_jobs_data  := make([]JobData, len(grid.cells), context.temp_allocator)

    job_idx := 0
    for cell_coord, &enemy_indices in grid.cells {
        cell_jobs_data[job_idx] = JobData {
            instances[:], 
            new_instances[:], 
            grid^, 
            enemy_indices, 
            player^, 
            dt
        }
        cell_jobs[job_idx] = jobs.make_job_typed(&jobs_group, &cell_jobs_data[job_idx], proc(using job_data : ^JobData) {
            if len(cell) == 0 do return

            for enemy_idx in cell {
                using enemy := &write[enemy_idx]
                // Sum steering forces
                steer_force := rl.Vector2{}
                if player.alive {
                    steer_force += #force_inline follow(enemy_idx, read, player.pos) * ENEMY_FOLLOW_FACTOR
                }
                steer_force += #force_inline alignment(enemy_idx, read, grid) * ENEMY_ALIGNMENT_FACTOR
                steer_force += #force_inline cohesion(enemy_idx, read, grid) * ENEMY_COHESION_FACTOR
                steer_force += #force_inline separation(enemy_idx, read, grid) * ENEMY_SEPARATION_FACTOR
                vel += steer_force * dt
                vel = limit_length(vel, ENEMY_SPEED / siz)
                pos += vel * dt
                if dir, ok := safe_normalize(vel); ok {
                    rot = math.angle_lerp(rot, math.atan2(dir.y, dir.x) - math.PI / 2, 1 - math.exp(-dt * ENEMY_TURN_SPEED))
                }
            }
        })

        job_idx += 1
    }

    jobs.dispatch_jobs(.High, cell_jobs)
    jobs.wait(&jobs_group)

    copy_slice(dst = instances[:count], src = new_instances[:count])
}

draw_enemies :: proc(using enemies : ^Enemies) {
    #no_bounds_check for &enemy in instances[0:count] {
        corners := get_enemy_corners(enemy)
        rl.DrawTriangleLines(corners[0], corners[2], corners[1], enemy.col)
    }
}

add_enemy :: proc(new_enemy : Enemy, using enemies : ^Enemies) {
    if count == MAX_ENEMIES do return
    instances[count] = new_enemy
    count += 1
}

release_enemy :: proc(index : int, using enemies : ^Enemies) {
    instances[index] = instances[count - 1]
    count -= 1
}

tick_killed_enemies :: proc(using enemies : ^Enemies, pickups : ^Pickups, ps : ^ParticleSystem) {
    for i := 0; i < count; i += 1 {
        using enemy := instances[i]
        if kill {
            release_enemy(i, enemies)
            i -= 1
            kill_count += 1

            spawn_particles_triangle_segments(ps, get_enemy_corners(enemy), col, vel, 0.5, 1.0, 50, 150, 2, 10, 3)

            for i in 0..<enemy.loot {
                spawn_pickup(pickups, pos, rand.choice_enum(PickupType))
            }
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
follow :: proc(index : int, enemies : []Enemy, target : rl.Vector2) -> rl.Vector2 {
    current  := enemies[index]
    steering := linalg.normalize(target - current.pos) * ENEMY_SPEED
    steering -= current.vel
    steering = limit_length(steering, ENEMY_FORCE)
    return steering
}

@(private="file")
alignment :: proc(index : int, enemies : []Enemy, grid : HGrid(int)) -> rl.Vector2 {
    enemy           := enemies[index]
    steering        := rl.Vector2{}
    neighbor_count  := 0
    cell_coord      := get_cell_coord(grid, enemy.pos)

    for x_offset in -1..=1 {
        for y_offset in -1..=1 {
            other_enemy_indices, ok := get_cell_data(grid, cell_coord + {x_offset, y_offset})
            if !ok do continue
            for other_enemy_idx in other_enemy_indices {
                // Check if other enemy is the same
                if index == other_enemy_idx do continue

                other_enemy := enemies[other_enemy_idx]

                // Check if other enemy archetype is the same
                if enemy.id == other_enemy.id do continue

                
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
cohesion :: proc (index : int, enemies : []Enemy, grid : HGrid(int)) -> rl.Vector2 {
    enemy           := enemies[index]
    steering        := rl.Vector2{}
    neighbor_count  := 0
    cell_coord      := get_cell_coord(grid, enemy.pos)

    for x_offset in -1..=1 {
        for y_offset in -1..=1 {
            other_enemy_indices, ok := get_cell_data(grid, cell_coord + {x_offset, y_offset})
            if !ok do continue
            for other_enemy_idx in other_enemy_indices {
                // Check if other enemy is the same
                if index == other_enemy_idx do continue

                other_enemy := enemies[other_enemy_idx]

                // Check if other enemy archetype is the same
                if enemy.id == other_enemy.id do continue
                
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
separation :: proc (index : int, enemies : []Enemy, grid : HGrid(int)) -> rl.Vector2 {
    enemy           := enemies[index]
    steering        := rl.Vector2{}
    neighbor_count  := 0
    cell_coord      := get_cell_coord(grid, enemy.pos)

    for x_offset in -1..=1 {
        for y_offset in -1..=1 {
            other_enemy_indices, ok := get_cell_data(grid, cell_coord + {x_offset, y_offset})
            if !ok do continue
            for other_enemy_idx in other_enemy_indices {
                // Check if other enemy is the same
                if index == other_enemy_idx do continue

                other_enemy := enemies[other_enemy_idx]
                
                sqr_dist := linalg.length2(enemy.pos - other_enemy.pos)
                if sqr_dist > enemy.siz * enemy.siz + other_enemy.siz * other_enemy.siz + ENEMY_SEPARATION_RADIUS * ENEMY_SEPARATION_RADIUS {
                    continue
                }

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