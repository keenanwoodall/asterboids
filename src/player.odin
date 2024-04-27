// This code handles player movement, audio and rendering.

package game

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:time"
import "core:math/linalg"
import rl "vendor:raylib"

PLAYER_SIZE                 :: 12
PLAYER_TURN_SPEED           :: 50
PLAYER_TURN_DRAG            :: 5
PLAYER_ACCELERATION         :: 350
PLAYER_BRAKING_ACCELERATION :: 3
PLAYER_THRUST_EMIT_DELAY    :: 0.02
PLAYER_THRUST_VOLUME_ATTACK :: 10
PLAYER_MAX_SPEED            :: 400

EmitThrustParticleAction :: proc(game : ^Game)

// I have no idea compelled me to use 3-character abbreviations, but I can't rename them easily with OLS :(
Player :: struct {
    max_hth     : f32,          // Max health
    hth         : f32,          // Current health
    rot         : f32,          // Rotation (radians)
    pos         : rl.Vector2,   // Position
    vel         : rl.Vector2,   // Velocity
    acc         : f32,          // Acceleration
    trq         : f32,          // Turn speed
    avel        : f32,          // Angular velocity
    adrg        : f32,          // Angular drag
    siz         : f32,          // Size
    alive       : bool,         // Is the player currently alive?
    knockback   : f32,          // Force applied to player when hit by enemy

    on_emit_thruster_particles : ActionStack(bool, Game),

    thruster_volume         : f32,
    last_thruster_emit_tick : time.Tick, // Note: this should be changed to use game time
    last_damage_time        : f64,       // The last time the player was damaged
}

init_player :: proc(using player : ^Player) {
    half_width   := f32(rl.rlGetFramebufferWidth()) / 2
    half_height  := f32(rl.rlGetFramebufferHeight()) / 2

    max_hth = 100
    hth = 100
    rot = 0
    pos = { half_width, half_height + 50 }
    vel = { 0, 0 }
    acc = PLAYER_ACCELERATION
    trq = PLAYER_TURN_SPEED
    avel = 0
    adrg = PLAYER_TURN_DRAG
    siz = PLAYER_SIZE
    alive = true
    knockback = 500

    thruster_volume = 0
    last_damage_time = -1000

    init_action_stack(&on_emit_thruster_particles)
}

unload_player :: proc(using player : ^Player) {
    unload_action_stack(&on_emit_thruster_particles)
}

tick_player :: proc(using game : ^Game, dt : f32) {
    width   := f32(rl.rlGetFramebufferWidth())
    height  := f32(rl.rlGetFramebufferHeight())

    thruster_emit_time_elapsed := time.duration_seconds(time.tick_since(player.last_thruster_emit_tick))
    can_emit := thruster_emit_time_elapsed >= PLAYER_THRUST_EMIT_DELAY
        
    thruster_target_volume : f32 = 0

    // Movement
    if player.alive {
        turn_left   := rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.A);
        turn_right  := rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D);
        thrust      := rl.IsKeyDown(.UP) || rl.IsKeyDown(.W);

        if turn_left {
            player.avel -= player.trq * dt
        }
        if turn_right {
            player.avel += player.trq * dt
        }
        if thrust {
            dir := get_player_dir(player)

            // To help the controls feel more responsive, we'll calculate how much the player is braking be comparing the direction they're moving to
            // the direction they're thrusting. We can use this to apply more acceleration when braking
            brake_factor := 1 - (linalg.dot(player.vel / (linalg.length(player.vel) + 0.001), dir) / 2 + 0.5) // 1 = braking, 0 = accelerating
            acceleration := player.acc * (1 + brake_factor * PLAYER_BRAKING_ACCELERATION) 

            player.vel += dir * acceleration * dt

            thruster_target_volume += 1
            if can_emit {
                should_emit := true
                execute_action_stack(player.on_emit_thruster_particles, &should_emit, game)
                if should_emit do emit_thruster_particles(&player, &line_particles, -dir, acceleration)
            }
        }
    }

    thruster_target_volume = math.saturate(thruster_target_volume) * 0.2
    player.thruster_volume = math.lerp(player.thruster_volume, thruster_target_volume, 1 - math.exp(-dt * PLAYER_THRUST_VOLUME_ATTACK))

    rl.SetMusicVolume(audio.thrust, player.thruster_volume)

    // Horizontal Edge collision
    if player.pos.x - player.siz < 0 {
        player.pos.x = player.siz
        player.vel.x *= -1;
    }
    if player.pos.x + player.siz > width {
        player.pos.x = width - player.siz
        player.vel.x *= -1;
    }
    // Vertical Edge collision
    if player.pos.y - player.siz < 0 {
        player.pos.y = player.siz
        player.vel.y *= -1;
    }
    if player.pos.y + player.siz > height {
        player.pos.y = height - player.siz
        player.vel.y *= -1;
    }

    // Angular drag
    player.avel *= 1 / (1 + player.adrg * dt)
    player.vel = limit_length(player.vel, PLAYER_MAX_SPEED)

    // Rotate and move player along velocity
    player.rot += player.avel * dt
    player.pos += player.vel * dt
}

draw_player :: proc(using game : ^Game) {
    if !player.alive do return
    radius  := player.siz / 2
    corners := get_player_corners(player)

    color := rl.RAYWHITE

    time_since_damaged : f32 = f32(game_time - player.last_damage_time)
    if time_since_damaged < PLAYER_DAMAGE_DEBOUNCE {
        color = rl.RED if (math.mod(time_since_damaged, 0.15) > 0.15 / 2) else color
    }

    rl.DrawTriangle(corners[0], corners[2], corners[1], color)
}

// The direction the player is facing
get_player_dir :: proc(using player : Player) -> rl.Vector2 {
    return { math.cos(rot), math.sin(rot) }
}

// Gets the base of the player. This is where the thruster particles emit from.
get_player_base :: proc(using player : Player) -> rl.Vector2 {
    corners := get_player_corners(player)
    return linalg.lerp(corners[0], corners[1], 0.5)
}

get_player_corners :: proc(using player : Player) -> [3]rl.Vector2 {
    // Start by defining the offsets of each vertex
    corners := [3]rl.Vector2 { {-0.75, -1}, {+0.75, -1}, {0, +1.5} }
    // Iterate over each vertex and transform them based on the player's position, rotation and size
    for i in 0..<3 {
        corners[i] = rl.Vector2Rotate(corners[i], rot - math.PI / 2)
        corners[i] *= siz
        corners[i] += pos
    }
    return corners
}

@(private) 
emit_thruster_particles :: proc(using player : ^Player, ps : ^ParticleSystem, dir : rl.Vector2, acceleration : f32) {
    player.last_thruster_emit_tick = time.tick_now()
    norm_dir := linalg.normalize(dir)
    spawn_particles_direction(
        particle_system = ps, 
        center          = get_player_base(player^),
        direction       = norm_dir, 
        count           = int(0.0035 * acceleration) + 1, 
        min_speed       = 200,
        max_speed       = 1000,
        min_lifetime    = 0.1,
        max_lifetime    = 0.5,
        size            = { 1, 10 },
        color           = rl.ORANGE,
        angle           = .2,
        drag            = 5,
    )
}

// Returns the distance to the closest enemy in the neighboring cells, if any
near_enemy :: proc(player : Player, enemies : Enemies) -> (near : bool, dist : f32) {
    player_cell := get_cell_coord(enemies.grid, player.pos)

    @(static) CellOffsets := [?][2]int {
        {0, 0}, // Check center cell first
        {-1, +1}, {+0, +1}, {+1, +1},
        {-1, +0},           {+1, +0},
        {-1, -1}, {+0, -1}, {+1, -1},
    }

    closest_sqr_dist : f32 = math.F32_MAX

    for cell_offset, idx in CellOffsets {
        enemy_indices, exists := get_cell_data(enemies.grid, player_cell + cell_offset)
        if !exists do continue

        for enemy_idx in enemy_indices {
            enemy := enemies.instances[enemy_idx]
            sqr_dist := linalg.length2(enemy.pos - player.pos)
            closest_sqr_dist = min(sqr_dist, closest_sqr_dist)
        }

        // If we found an enemy in the center cell we can break because none of the neighboring cells
        // will have a closer enemy
        if idx == 0 && closest_sqr_dist < math.F32_MAX do break
    }

    return closest_sqr_dist < math.F32_MAX, math.sqrt(closest_sqr_dist)
}