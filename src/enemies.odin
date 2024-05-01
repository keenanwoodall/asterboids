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

MAX_ENEMIES             :: 1024
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
ENEMY_PROJECTILE_DAMAGE :: 25
ENEMY_PROJECTILE_SPREAD :: .1
ENEMY_PROJECTILE_SPEED  :: 500

// Function signature for an action an enemy can perform. Like shoot, dash, spawn mine etc
EnemyAction :: proc(enemy : ^Enemy, game : ^Game)

// The Enemy struct stores the state of a single enemy
Enemy :: struct {
    pos     : rl.Vector2,   // Position
    vel     : rl.Vector2,   // Velocity
    rot     : f32,          // Rotation (radians)
    spd     : f32,          // Speed multiplier
    siz     : f32,          // Speed multiplier
    hp      : int,           // Health points
    dmg     : int,
    kill    : bool,         // Killed?

    id      : EnemyArchetype,   // There are different types of enemies, each with a different size/hp/loot etc. 
                                // This is an identifier for quick comparisons between different types of enemies.
                                // It can also be used to index into the global Archetypes array to get shared.
                                // Some hot data that is shared between enemies of the same archetype like `siz` is still stored on the enemy for fast access.
    action_timer : Timer,
    action       : EnemyAction,
}

// The Enemies struct stores the state of all enemies
Enemies :: struct {
    count         : int,                      // The number of active enemies.
    kill_count    : int,                      // The number of enemies which have been killed this game.
    grid          : HGrid(int),               // HGrid is a "hash grid". It lets us figure out where enemies are relative to eachother more efficiently.
    instances     : []Enemy,       // Enemies are stores in a pool so that their memory is preallocated.
    new_instances : []Enemy,   // To assist in safe multithreading of the enemy boid sim we store two copies of the enemies
}

// This is probably a silly way to go about this, but to author the three enemy variants
// I'm using this struct to store the relevant parameters.
Archetype :: struct { size : f32, hp, dmg : int, spd : f32, loot : int, color : rl.Color, rate : f64, action : EnemyAction}

// Each archetype is stored in this array.
// Created enemies are assigned an id which correlates with their index in this array.
EnemyArchetype :: enum u8 { Small, Medium, Large, Tutorial }
Archetypes := map[EnemyArchetype]Archetype {
    .Small = { size = ENEMY_SIZE * 1.0, hp = 1, dmg = 35, spd = 1, loot = 1, color = rl.YELLOW },
    .Medium = { size = ENEMY_SIZE * 1.5, hp = 2, dmg = 50, spd = 1, loot = 3, color = rl.ORANGE,
        // Medium enemies roll a dice for whether they will shoot each time their action is invoked.
        rate = .5,
        action = proc(enemy : ^Enemy, game : ^Game) {
            // Chance that enemy shoots
            if rand.float32_range(0, 1) < 0.5 do return
            enemy_speed := linalg.length(enemy.vel)
            // Enemy must be moving
            if enemy_speed > 0 {
                dir_to_player := linalg.normalize(game.player.pos - enemy.pos)
                player_alignment := linalg.dot(enemy.vel / enemy_speed, dir_to_player)

                // and must be mostly facing the player
                if player_alignment < 0.5 do return

                dir_to_player = rl.Vector2Rotate(dir_to_player, rand.float32_range(-ENEMY_PROJECTILE_SPREAD, ENEMY_PROJECTILE_SPREAD))
                actual_speed := ENEMY_PROJECTILE_SPEED * rand.float32_range(0.95, 1)
                try_play_sound(&game.audio, game.audio.laser)
                emit_muzzle_blast(&game.pixel_particles, enemy.pos, dir_to_player, rl.ORANGE)
                add_projectile(
                    newProjectile = Projectile {
                        pos = enemy.pos,
                        dir = dir_to_player,
                        spd = actual_speed,
                        len = 15,
                        bounces = 0,
                        col = rl.ORANGE,
                    },
                    projectiles = &game.enemy_projectiles,
                )
            }
        } 
    },
    .Large = { size = ENEMY_SIZE * 2.5, hp = 7, dmg = 90, spd = 1, loot = 7, color = rl.RED,
        rate = 0.2,
        action = proc(enemy : ^Enemy, game : ^Game) {
            // Don't spawn any mines if offscreen
            if enemy.pos.x < 0 || enemy.pos.x > f32(rl.GetScreenWidth()) || enemy.pos.y < 0 || enemy.pos.y > f32(rl.GetScreenHeight()) {
                return
            }
            add_pool(&game.mines.pool, Mine { pos = enemy.pos, hp = MINE_HP, destroyed = false })
        },
    },
    .Tutorial = { size = ENEMY_SIZE * 1.0, hp = 1, dmg = 0, spd = 0, loot = 5, color = rl.YELLOW }
}

// Init functions are called when the game first starts.
// Here we can assign default values and initialize data.
init_enemies :: proc(using enemies : ^Enemies) {
    count       = 0
    kill_count  = 0
    grid        = {}

    instances = make([]Enemy, MAX_ENEMIES)
    new_instances = make([]Enemy, MAX_ENEMIES)

    // The enemies grid is list of 2D cells where each cell stores a list enemy indexes.
    // Enemies steer themselves based on the position and velocity of neighboring enemies within a certain radius
    // so we'll set the cell size of the grid to the maximum of those radii
    cell_size : f32 = max(ENEMY_ALIGNMENT_RADIUS, ENEMY_COHESION_RADIUS, ENEMY_SEPARATION_RADIUS)
    init_grid(&grid, cell_size)
}

// Unload functions are called when the game is closed or restarted.
// Here we can free an allocated memory.
unload_enemies :: proc(using enemies : ^Enemies) {
    delete(instances)
    delete(new_instances)
    delete_grid(grid)
}

// Tick functions are called every frame by the game. This handles enemy steering and the flocking simulation.
@(optimization_mode="speed")
tick_enemies :: proc(using game : ^Game) {
    // The cell data stored by the enemies grid is rebuilt every frame since enemies are constantly moving 
    // and the cell that an enemy was in last frame may not be the same this frame.
    // There may be room for optimization here since enemies enemies aren't changing cells each frame,
    // but isolating the enemies whose cell changed would come with it's own performance cost.
    // Needs to be cleared even if enemies.count is zero since some code iterates over enemies via grid cells
    clear_grid(&enemies.grid)

    // If there aren't any enemies, don't do anything!
    if enemies.count == 0 do return

    // Tick enemy actions
    for &enemy in enemies.instances[:enemies.count] {
        if enemy.action == nil do continue // Note: is there a better way to structure entities to avoid putting this condition in a big loop?
        action_count := tick_timer(&enemy.action_timer, game_delta_time)
        for i in 0..<action_count {
            enemy.action(&enemy, game)
        }
    }

    // Rebuild the enemies grid.
    #no_bounds_check for i in 0..<enemies.count {
        using enemy := enemies.instances[i]
        // Get the currenty enemies cell coordinate based on its current position
        // and insert its index into the grid
        cell_coord := get_cell_coord(enemies.grid, pos)
        insert_grid_data(&enemies.grid, cell_coord, i)
    }

    // We will be multithreading the enemy boid simulation. 
    // Each cell of the enemies grid will be simulated on a different thread in parallel
    // Enemies in one cell need to check enemies in adjacent cells so to prevent different threads from reading/writing to the same enemy data 
    // the Enemies struct stores two enemy arrays: one for reading and one for writing.
    // Before simulating the boids, copy the current enemies array over the new enemies array so that they are in sync
    copy_slice(dst = enemies.new_instances[:enemies.count], src = enemies.instances[:enemies.count])

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
    cell_jobs       := make([]jobs.Job, len(enemies.grid.cells), context.temp_allocator)
    cell_jobs_data  := make([]JobData, len(enemies.grid.cells), context.temp_allocator)

    // This is like the `i` of the following for-loop. 
    // We just need to declare and iterate it manually since the loop is iterating over a map which operates via a key rather than an index
    job_idx := 0
    // Iterate over all the cells
    // The key is the cell coordinate and the value is the data stored in the cell (the indices of enemies in the cell)
    for cell_coord, &enemy_indices in enemies.grid.cells {
        // Increment the job index at the end of this iteration
        defer job_idx += 1

        // Initialize the job data at the current index
        cell_jobs_data[job_idx] = JobData {
            enemies.instances[:], 
            enemies.new_instances[:], 
            enemies.grid, 
            enemy_indices, 
            player, 
            game_delta_time
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

            screen_bounds :=  rl.Rectangle{0, 0, f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}

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
                steer_force += #force_inline contain(enemy_idx, read, screen_bounds)
                steer_force += #force_inline alignment(enemy_idx, read, grid) * ENEMY_ALIGNMENT_FACTOR
                steer_force += #force_inline cohesion(enemy_idx, read, grid) * ENEMY_COHESION_FACTOR
                steer_force += #force_inline separation(enemy_idx, read, grid) * ENEMY_SEPARATION_FACTOR

                // Add the steer force to the enemy, limit its speed, and move the enemy along its new velocity
                vel += steer_force * dt
                vel = limit_length(vel, (ENEMY_SPEED * f32(spd)) / f32(siz))
                pos += vel * dt

                // Enemies are rotated to face along their velocity. 
                // Enemy velocity can change quite rapidly so to prevent jitter I animating this rotation smoothly over time
                if dir, ok := safe_normalize(vel); ok {
                    rot = math.angle_lerp(f32(rot), math.atan2(dir.y, dir.x) - math.PI / 2, 1 - math.exp(-dt * ENEMY_TURN_SPEED))
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
    copy_slice(dst = enemies.instances[:enemies.count], src = enemies.new_instances[:enemies.count]) 
}

// Draw functions are called at the end of each frame by the game. Draws the enemies to the screen
draw_enemies :: proc(using enemies : ^Enemies) {
    #no_bounds_check for &enemy in instances[0:count] {
        corners := get_enemy_corners(enemy)
        archetype := Archetypes[enemy.id]
        rl.DrawTriangleLines(corners[0], corners[2], corners[1], archetype.color)
    }
}

// This is a utility function to add a new enemy.
add_enemy :: proc(new_enemy : Enemy, using enemies : ^Enemies) {
    if count == MAX_ENEMIES do return
    instances[count] = new_enemy
    count += 1
}

// Adds a new enemy instance and populates its parameters from a specific enemy archetype.
add_archetype_enemy :: proc(using enemies : ^Enemies, type : EnemyArchetype, pos, vel : rl.Vector2, rot : f32 = 0) {
    arch := Archetypes[type]
    new_enemy := Enemy {
        pos = pos, 
        vel = vel, 
        rot = rot, 
        spd = arch.spd, 
        siz = arch.size, 
        hp = arch.hp,  
        dmg = arch.dmg, 
        kill = false,
        id = type,  
        // Add some random offset to the last tick time so enemies spawned on the same frame aren't in lockstep
        action_timer = { rate = arch.rate, last_tick_time = rand.float64_range(0, 1 / arch.rate + 0.01) },
        action = arch.action,
    }

    add_enemy(new_enemy, enemies)
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
        if hp < 0 || kill {
            release_enemy(i, enemies)
            i -= 1
            kill_count += 1

            // Some things like enemy color/loot is stored per archetype and needs to be fetched
            archetype := Archetypes[id]
            col := archetype.color
            loot := archetype.loot

            spawn_particles_triangle_segments(ps, get_enemy_corners(enemy), col, vel, 0.5, 1.0, 50, 150, 2, 10, 3)

            pickup_count : u8 = u8(rand.int_max(int(loot) + 1)) // this casting is annoying
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
    offset   := target - current.pos
    dist     := linalg.length(offset)

    // Don't follow if really close
    if dist < 0.01 do return {}

    // "Interest" is just a way to dampen steering strength as the distance to the player increases
    // Has a knock-on aggro affect since aggro tends to be a positive feedback loop
    interest := math.lerp(f32(0.05), 1, math.smoothstep(f32(600), 100, dist))

    steering := offset / dist * f32(ENEMY_SPEED) * interest
    steering -= current.vel
    steering = limit_length(steering, ENEMY_FORCE)
    return steering
}

// Steers an enemy to stay within a rectangle
@(private="file")
contain :: proc(index : int, enemies : []Enemy, rect : rl.Rectangle) -> rl.Vector2 {
    current  := enemies[index]
    target_pos := rl.Vector2 { clamp(current.pos.x, rect.x, rect.x + rect.width), clamp(current.pos.y, rect.y, rect.y + rect.height) }
    offset := target_pos - current.pos
    dist := linalg.length(offset)

    if dist < 10 do return {}

    steering := linalg.normalize(offset) * ENEMY_SPEED
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