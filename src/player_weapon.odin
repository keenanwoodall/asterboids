package game

import "core:fmt"
import "core:time"
import "core:math"
import "core:math/rand"
import "core:math/linalg"
import rl "vendor:raylib"

SHOOT_DELAY     :: 0.25
SHOOT_SPEED     :: 1000
SHOOT_SPREAD    :: math.RAD_PER_DEG * 5
WEAPON_WIDTH    :: 3
WEAPON_LENGTH   :: 30
WEAPON_KICK     :: 50

Weapon :: struct {
    delay       : f64,
    speed       : f32,
    kick        : f32,
    spread      : f32,
    count       : int,
    penetration : int,
    bounces     : int,
    last_shoot_time : f64
}

init_weapon :: proc(using weapon : ^Weapon) {
    count   = 1
    delay   = SHOOT_DELAY
    speed   = SHOOT_SPEED
    kick    = WEAPON_KICK
    spread  = SHOOT_SPREAD
    last_shoot_time = {}
}

tick_player_weapon :: proc(using weapon : ^Weapon, using player : ^Player, audio : ^Audio, projectiles : ^Projectiles, ps : ^ParticleSystem, game_time : f64) {
    if !alive do return

    time_since_shoot := game_time - last_shoot_time

    if rl.IsMouseButtonDown(.LEFT) && time_since_shoot > delay {
        last_shoot_time = game_time

        // kick
        vel -= get_weapon_dir(player) * kick

        // sfx
        try_play_sound(audio, audio.laser, debounce = 0.05)

        // vfx
        weapon_tip      := get_weapon_tip(player)
        particle_dir    := get_weapon_dir(player)
        spawn_particles_direction(ps, weapon_tip, +particle_dir, 10, min_speed = 300, max_speed = 2000, min_lifetime = 0.05, max_lifetime = 0.1, color = rl.YELLOW, angle = 0.1, drag = 10)
        particle_dir     = rl.Vector2Rotate(particle_dir, math.PI / 2)
        spawn_particles_direction(ps, weapon_tip, -particle_dir, 5, min_speed = 300, max_speed = 500, min_lifetime = 0.05, max_lifetime = 0.1, color = rl.YELLOW, angle = 0.2, drag = 10)
        spawn_particles_direction(ps, weapon_tip, +particle_dir, 5, min_speed = 300, max_speed = 500, min_lifetime = 0.05, max_lifetime = 0.1, color = rl.YELLOW, angle = 0.2, drag = 10)

        for i in 0..<count {
            direction := rl.Vector2Rotate(linalg.normalize(rl.GetMousePosition() - pos), rand.float32_range(-spread, spread))
            actual_speed := speed * rand.float32_range(0.95, 1)
            add_projectile(
                newProjectile = Projectile {
                    pos = get_weapon_tip(player),
                    dir = direction,
                    spd = actual_speed,
                    len = math.max(actual_speed * 0.01, 5),
                    bounces = bounces
                },
                projectiles = projectiles,
            )
        }
    }
}

draw_player_weapon :: proc(using player : ^Player, weapon : ^Weapon) {
    if !alive do return

    weapon_rect  := rl.Rectangle{pos.x, pos.y, WEAPON_WIDTH, WEAPON_LENGTH}
    weapon_pivot := rl.Vector2{WEAPON_WIDTH / 2, 0}
    weapon_angle := get_weapon_deg(player)
    weapon_spread_deg := math.to_degrees(-weapon.spread / 2)
    rl.DrawLineV(pos, rl.GetMousePosition(), {255, 0, 0, 80})
    rl.DrawRectanglePro(weapon_rect, weapon_pivot, weapon_angle, rl.GRAY)
}

get_weapon_dir :: #force_inline proc(using player : ^Player) -> rl.Vector2 {
    return linalg.normalize(rl.GetMousePosition() - pos)
}

get_weapon_rad :: #force_inline proc(using player : ^Player) -> f32 {
    dir := get_weapon_dir(player)
    return linalg.atan2(dir.y, dir.x) - math.PI / 2
}

get_weapon_deg :: #force_inline proc(using player : ^Player) -> f32 {
    return linalg.to_degrees(get_weapon_rad(player))
}

get_weapon_tip :: #force_inline proc(using player : ^Player) -> rl.Vector2 {
    local_tip := rl.Vector2{0, WEAPON_LENGTH}
    local_tip  = rl.Vector2Rotate(local_tip, get_weapon_rad(player))
    return local_tip + pos
}