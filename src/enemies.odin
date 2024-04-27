// This code manages the simulation, drawing and cleanup of enemies
// In this game, enemies are "boids": bird-like objects that move flocks

package game

import "core:fmt"
import "core:math"
import "core:time"
import "core:math/rand"
import "core:math/linalg"

import rl "vendor:raylib"

// For multithreading the flocking simulation I am using an external package
// Repository: https://github.com/jakubtomsu/jobs
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

// The Enemy struct stores the state of a single enemy
Enemy :: struct {
    pos     : rl.Vector2,   // Position
    vel     : rl.Vector2,   // Velocity
    rot     : f32,          // Rotation (radians)
    siz     : f32,          // Size
    spd     : f32,          // Speed multiplier
    col     : rl.Color,     // Color
    hp      : int,          // Health points
    dmg     : f32,
    kill    : bool,         // Killed?
    loot    : int,          // Number of pickups that will be dropped on death
    id      : u8,           // There are different types of enemies, each with a different size/hp/loot etc. 
                            // This is an identifier for quick comparisons between different types of enemies
}

// The Enemies struct stores the state of all enemies
Enemies :: struct {
    count       : int,                      // The number of active enemies.
    kill_count  : int,                      // The number of enemies which have been killed this game.
    grid        : HGrid(int),               // HGrid is a "hash grid". It lets us figure out where enemies are relative to eachother more efficiently.
    instances   : [MAX_ENEMIES]Enemy,       // Enemies are stores in a pool so that their memory is preallocated.
    new_instances   : [MAX_ENEMIES]Enemy,   // To assist in safe multithreading of the enemy boid sim we store two copies of the enemies
}

// Init functions are called when the game first starts.
// Here we can assign default values and initialize data.
init_enemies :: proc(using enemies : ^Enemies) {
    count       = 0
    kill_count  = 0
    grid        = {}

    // The enemies grid is list of 2D cells where each cell stores a list enemy indexes.
    // Enemies steer themselves based on the position and velocity of neighboring enemies within a certain radius
    // so we'll set the cell size of the grid to the maximum of those radii
    cell_size   : f32 = max(ENEMY_ALIGNMENT_RADIUS, ENEMY_COHESION_RADIUS, ENEMY_SEPARATION_RADIUS)
    init_cell_data(&grid, cell_size)
}

// Unload functions are called when the game is closed or restarted.
// Here we can free an allocated memory.
unload_enemies :: proc(using enemies : ^Enemies) {
    delete_cell_data(grid)
}

// Tick functions are called every frame by the game
@(optimization_mode="speed")
tick_enemies :: proc(using enemies : ^Enemies, player : Player, dt : f32) {
    // The cell data stored by the enemies grid is rebuilt every frame since enemies are constantly moving 
    // and the cell that an enemy was in last frame may not be the same this frame.
    // There may be room for optimization here since enemies enemies aren't changing cells each frame,
    // but isolating the enemies whose cell changed would come with it's own performance cost
    clear_cell_data(&grid)

    // If there aren't any enemies, don't do anything!
    if count == 0 do return

    // Rebuild the enemies grid.
    #no_bounds_check for i in 0..<count {
        using enemy := instances[i]
        // Get the currenty enemies cell coordinate based on its current position
        // and insert its index into the grid
        cell_coord := get_cell_coord(grid, pos)
        insert_cell_data(&grid, cell_coord, i)
    }

    // We will be multithreading the enemy boid simulation. 
    // Each cell of the enemies grid will be simulated on a different thread in parallel
    // Enemies in one cell need to check enemies in adjacent cells so to prevent different threads from reading/writing to the same enemy data 
    // the Enemies struct stores two enemy arrays: one for reading and one for writing.
    // Before simulating the boids, copy the current enemies array over the new enemies array so that they are in sync
    copy_slice(dst = new_instances[:count], src = instances[:count])

    // Note: This "double-buffered" approach is probably not ideal.
    // An alternate approach that may be worth trying would be to store the enemies array *once*
    // Then to prevent multiple threads from accessing the same data, we could break the sim up into two passes.
    // The first pass simulates every other cell and the second pass simulates the skipped cells
    // If you think of the cells like a checkerboard, it'd be like simulating all the white squares, and then all the black squares

    // Multithreading is done via a "job system." https://github.com/jakubtomsu/jobs
    // This an easy way to break up some parallelizable work into chunks, where each chunk runs on a different thread
    // Each "job" needs to be passed the data/context it needs to run.
    // This struct holds all the data used by a single job
    JobData :: struct { 
        read    : []Enemy,          // Array of enemies which we can safely read position/velocity etc from.
        write   : []Enemy,          // Array of enemies which we can safely write to.
        grid    : HGrid(int),       // Grid of enemy indices.
        cell    : [dynamic]int,     // Specific cell from the grid that this job will be handling.
        player  : Player,
        dt      : f32               // "Delta Time" - the amount of time that has passed since the last frame
    }

    // A job group is our "handle" which lets us wait for our jobs to finish
    jobs_group      : jobs.Group
    // Allocate a job and job data for each cell in the grid
    // We're using the builtin temporary allocator since these only need to exist for the duration of this function
    cell_jobs       := make([]jobs.Job, len(grid.cells), context.temp_allocator)
    cell_jobs_data  := make([]JobData, len(grid.cells), context.temp_allocator)

    // This is like the `i` of the following for-loop. 
    // We just need to declare and iterate it manually since the loop is iterating over a map which operates via a key rather than an index
    job_idx := 0
    // Iterate over all the cells
    // The key is the cell coordinate and the value is the data stored in the cell (the indices of enemies in the cell)
    for cell_coord, &enemy_indices in grid.cells {
        // Increment the job index at the end of this iteration
        defer job_idx += 1

        // Initialize the job data at the current index
        cell_jobs_data[job_idx] = JobData {
            instances[:], 
            new_instances[:], 
            grid, 
            enemy_indices, 
            player, 
            dt
        }
        // Initialize a job at the current index.
        // To create a job we need to provide the job group for synchronization, the data which will be used by the job,
        // and the actual job function which is called on another thread and passed the job data
        // We're declaring the job function inline
        cell_jobs[job_idx] = jobs.make_job_typed(&jobs_group, &cell_jobs_data[job_idx], proc(using job_data : ^JobData) {
            // This is a job function which will run on another thread
            // We are passed job_data which has all the info we need to simulate a single grid cell of enemies
            
            // If (for some reason) there are no enemies in this cell, do nothing!
            if len(cell) == 0 do return

            // Iterate over all the enemy indices in the cell
            for enemy_idx in cell {
                // Use the index to get the corresponding enemy from the array of enemies which we can "write" to (modify)
                using enemy := &write[enemy_idx]

                // Enemies are moved via "steering forces" https://www.red3d.com/cwr/steer/gdc99/

                // Sum steering forces
                steer_force := rl.Vector2{}

                // Each of the following functions return a force that steers the enemy in a particular direction
                // They are not super interesting individually, but when combined they result in interesting, emergent
                // bird-like movement/flocking
                if player.alive {
                    steer_force += #force_inline follow(enemy_idx, read, player.pos) * ENEMY_FOLLOW_FACTOR
                }
                steer_force += #force_inline alignment(enemy_idx, read, grid) * ENEMY_ALIGNMENT_FACTOR
                steer_force += #force_inline cohesion(enemy_idx, read, grid) * ENEMY_COHESION_FACTOR
                steer_force += #force_inline separation(enemy_idx, read, grid) * ENEMY_SEPARATION_FACTOR

                // Add the steer force to the enemy, limit its speed, and move the enemy along its new velocity
                vel += steer_force * dt
                vel = limit_length(vel, (ENEMY_SPEED * spd) / siz)
                pos += vel * dt

                // Enemies are rotated to face along their velocity. 
                // Enemy velocity can change quite rapidly so to prevent jitter I animating this rotation smoothly over time
                if dir, ok := safe_normalize(vel); ok {
                    rot = math.angle_lerp(rot, math.atan2(dir.y, dir.x) - math.PI / 2, 1 - math.exp(-dt * ENEMY_TURN_SPEED))
                }
            }
        })
    }

    // We have successfully initialized all the jobs!

    // Dispatch the jobs to run them
    jobs.dispatch_jobs(.High, cell_jobs)
    // Wait for them to complete before continuing
    jobs.wait(&jobs_group)

    // The jobs wrote the new enemy states to the new_instances array.
    // The rest of the game references the regular instances array, so we need to copy the new enemies over the array
    // Note: Could we just switch the pointer used by each array to "flip" them needing to copy?
    copy_slice(dst = instances[:count], src = new_instances[:count]) 
}

// Draw functions are called at the end of each frame by the game.
draw_enemies :: proc(using enemies : ^Enemies) {
    #no_bounds_check for &enemy in instances[0:count] {
        corners := get_enemy_corners(enemy)
        rl.DrawTriangleLines(corners[0], corners[2], corners[1], enemy.col)
    }
}

// This is a utility function to add a new enemy.
add_enemy :: proc(new_enemy : Enemy, using enemies : ^Enemies) {
    if count == MAX_ENEMIES do return
    instances[count] = new_enemy
    count += 1
}

// This is a utility function to release an enemy.
release_enemy :: proc(index : int, using enemies : ^Enemies) {
    instances[index] = instances[count - 1]
    count -= 1
}

// This tick function is called by the game after projectile collisions are resolved.
// Rather than releasing killed enemies immediately, they are marked as "kill"ed.
// There could be multiple ways for an enemy to be killed, 
// so this gives us a centralized place to handle their death, spawn vfx/pickups etc
tick_killed_enemies :: proc(using enemies : ^Enemies, pickups : ^Pickups, ps : ^ParticleSystem) {
    for i := 0; i < count; i += 1 {
        using enemy := instances[i]
        if kill {
            release_enemy(i, enemies)
            i -= 1
            kill_count += 1

            spawn_particles_triangle_segments(ps, get_enemy_corners(enemy), col, vel, 0.5, 1.0, 50, 150, 2, 10, 3)

            pickup_count := rand.int_max(enemy.loot + 1)
            for i in 0..<pickup_count {
                spawn_pickup(pickups, pos, PickupType.XP if rand.float32_range(0, 1) > 0.4 else PickupType.Health)
            }
        }
    }
}

// Call this from game.draw_game if you want to visualize the enemies hash grid
draw_enemies_grid :: proc(using enemies : Enemies) {
    for cell in grid.cells {
        rl.DrawRectangleLinesEx({f32(cell.x) * grid.cell_size, f32(cell.y) * grid.cell_size, grid.cell_size, grid.cell_size}, 1, {255, 255, 255, 50})
    }
}

draw_enemy_grid_cell :: proc(using enemies : Enemies, cell_coord : [2]int) {
    rl.DrawRectangleLinesEx({f32(cell_coord.x) * grid.cell_size, f32(cell_coord.y) * grid.cell_size, grid.cell_size, grid.cell_size}, 1, {255, 0, 0, 100})
}

// Enemies are triangles. This function calculates the vertices of an enemy triangle.
// Corners is probably the wrong term because enemies are triangles.
get_enemy_corners :: proc(using enemy : Enemy, padding : f32 = 0) -> [3]rl.Vector2 {
    // Start by defining the offsets of each vertex
    corners := [3]rl.Vector2 { {-1, -1}, {+1, -1}, {0, +1.5} } * (1 + padding)
    // Iterate over each vertex and transform them based on the enemy's position, rotation and size
    for i in 0..<3 {
        corners[i] = rl.Vector2Rotate(corners[i], rot)
        corners[i] *= siz
        corners[i] += pos
    }
    return corners
}

// Returns true if the provided line intersects the segments of an enemy. If true, also returns the intersection point/normal
check_enemy_line_collision :: proc(line_start, line_end : rl.Vector2, enemy : Enemy) -> (hit : bool, point, normal : rl.Vector2) {
    corners := get_enemy_corners(enemy, padding = 1)

    // Iterate over each segment
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

// Steers an enemy at the given index towards a target position
@(private="file")
follow :: proc(index : int, enemies : []Enemy, target : rl.Vector2) -> rl.Vector2 {
    current  := enemies[index]
    steering := linalg.normalize(target - current.pos) * ENEMY_SPEED
    steering -= current.vel
    steering = limit_length(steering, ENEMY_FORCE)
    return steering
}

// The following 3 steering functions (alignment, cohesion, separation) iterate over enemies in the neighboring cells
// and steer the current enemy based on the other enemies distance, velocity, position etc
/*
    ┌─┐                                    
    └─┘ = cell                             
     x  = current enemy                    
     .  = neighboring enemy                                                    
    ┌────────────┬────────────┬────────────┐
    │ .          │            │        . . │
    │    .       │     .      │      .     │
    │          . │            │          . │
    │(-1,+1)     │(+0,+1)     │(+1,+1)     │
    ├────────────┼────────────┼────────────┤
    │            │  .         │          . │
    │   .        │       x    │    .       │
    │            │         .  │         .  │
    │(-1,+0)    .│(+0,+1)     │(+1,+0)     │
    ├────────────┼────────────┼────────────┤
    │            │            │         .  │
    │    .       │  .  .      │  .  .      │
    │            │        .   │        .   │
    │(-1,-1)   . │(+0,-1)     │(+1,-1)     │
    └────────────┴────────────┴────────────┘
*/

// Steers an enemy at the given index so that its velocity aligns with nearby enemies
@(private="file")
alignment :: proc(index : int, enemies : []Enemy, grid : HGrid(int)) -> rl.Vector2 {
    enemy           := enemies[index]
    steering        := rl.Vector2{}
    neighbor_count  := 0
    cell_coord      := get_cell_coord(grid, enemy.pos)

    // Iterate over all adjacent cells (and the central one as well)
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

// Steers an enemy at the given index so that it moves towards the center of nearby enemies
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

// Steers an enemy at the given index so that it moves away from any nearby enemies which are too close
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

// Utility function to set the length of a vector
set_length :: proc(v : rl.Vector2, length : f32) -> rl.Vector2 {
    return linalg.normalize(v) * length
}

// Utility function to limit the length of a vector
limit_length :: proc(v : rl.Vector2, limit : f32) -> rl.Vector2 {
    len := linalg.length(v)
    if len == 0 || len <= limit {
        return v
    }

    dir := v / len
    return dir * limit
}

// Utility function to safely normalize a vector
safe_normalize :: proc(v : rl.Vector2) -> (rl.Vector2, bool) {
    length := linalg.length(v)
    if length > 0 do return v / length, true
    else do return 0, false
}