// This code handles player movement, audio and rendering.

package game

import "core:fmt"
import "core:math"
import "core:time"
import "core:math/linalg"
import rl "vendor:raylib"

PLAYER_SIZE                 :: 12
PLAYER_TURN_SPEED           :: 50
PLAYER_TURN_DRAG            :: 5
PLAYER_ACCELERATION         :: 350
PLAYER_BRAKING_ACCELERATION :: 3
PLAYER_THRUST_EMIT_DELAY    :: 0.01
PLAYER_THRUST_VOLUME_ATTACK :: 10
PLAYER_MAX_SPEED            :: 400

// I have no idea compelled me to use 3-character abbreviations, but I can't rename them easily with OLS :(
Player :: struct {
    max_hth : f32,          // Max health
    hth     : f32,          // Current health
    rot     : f32,          // Rotation (radians)
    pos     : rl.Vector2,   // Position
    vel     : rl.Vector2,   // Velocity
    acc     : f32,          // Acceleration
    trq     : f32,          // Turn speed
    avel    : f32,          // Angular velocity
    adrg    : f32,          // Angular drag
    siz     : f32,          // Size
    alive   : bool,
    thruster_volume : f32,
    last_thruster_emit_tick : time.Tick,
}

init_player :: proc(using player : ^Player) {
    half_width   := f32(rl.rlGetFramebufferWidth()) / 2
    half_height  := f32(rl.rlGetFramebufferHeight()) / 2

    max_hth = 100
    hth = 100
    rot = 0
    alive = true
    pos = { half_width, half_height + 50 }
    vel = { 0, 0 }
    avel = 0
    siz = PLAYER_SIZE
    acc = PLAYER_ACCELERATION
    trq = PLAYER_TURN_SPEED
    adrg = PLAYER_TURN_DRAG
    thruster_volume = 0
}

tick_player :: proc(using player : ^Player, audio : ^Audio, ps : ^ParticleSystem, dt : f32) {
    width   := f32(rl.rlGetFramebufferWidth())
    height  := f32(rl.rlGetFramebufferHeight())

    thruster_emit_time_elapsed := time.duration_seconds(time.tick_since(last_thruster_emit_tick))
    can_emit := thruster_emit_time_elapsed >= PLAYER_THRUST_EMIT_DELAY
        
    thruster_target_volume : f32 = 0

    // Movement
    if alive {
        turn_left   := rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.A);
        turn_right  := rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D);
        thrust      := rl.IsKeyDown(.UP) || rl.IsKeyDown(.W);

        if turn_left {
            avel -= trq * dt
        }
        if turn_right {
            avel += trq * dt
        }
        if thrust {
            dir := get_player_dir(player^)
            brake_factor := 1 - (linalg.dot(player.vel / (linalg.length(player.vel) + 0.001), dir) / 2 + 0.5)// 1 = braking, 0 = accelerating
            acceleration := acc * (1 + brake_factor * PLAYER_BRAKING_ACCELERATION) 
            vel += dir * acceleration * dt
            thruster_target_volume += 1
            if can_emit do emit_thruster_particles(player, ps, -dir, acceleration)
        }
    }

    thruster_target_volume = math.saturate(thruster_target_volume) * 0.2
    thruster_volume = math.lerp(thruster_volume, thruster_target_volume, 1 - math.exp(-dt * PLAYER_THRUST_VOLUME_ATTACK))

    rl.SetMusicVolume(audio.thrust, thruster_volume)

    // Horizontal Edge collision
    if pos.x - siz < 0 {
        pos.x = siz
        vel.x *= -1;
    }
    if pos.x + siz > width {
        pos.x = width - siz
        vel.x *= -1;
    }
    // Vertical Edge collision
    if pos.y - siz < 0 {
        pos.y = siz
        vel.y *= -1;
    }
    if pos.y + siz > height {
        pos.y = height - siz
        vel.y *= -1;
    }

    // Angular drag
    avel *= 1 / (1 + adrg * dt)
    vel = limit_length(vel, PLAYER_MAX_SPEED)

    // Rotate and move player along velocity
    rot += avel * dt
    pos += vel * dt
}

draw_player :: proc(using player : ^Player) {
    if !alive do return
    radius := siz / 2
    corners := get_player_corners(player^)
    rl.DrawTriangle(corners[0], corners[2], corners[1], rl.RAYWHITE)
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
        count           = int(0.005 * acceleration), 
        min_speed       = 200,
        max_speed       = 1000,
        min_lifetime    = 0.1,
        max_lifetime    = 0.5,
        color           = rl.GRAY,
        angle           = .2,
        drag            = 5,
    )
}