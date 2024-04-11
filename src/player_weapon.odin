package game
import fmt "core:fmt"
import time "core:time"
import math "core:math"
import rand "core:math/rand"
import linalg "core:math/linalg"
import rl "vendor:raylib"

SHOOT_DELAY     :: 0.2
WEAPON_WIDTH    :: 3
WEAPON_LENGTH   :: 30

@(private) last_shoot_tick : time.Tick

init_player_weapon :: proc() {
    last_shoot_tick = {}
}

tick_player_weapon :: proc(using player : ^Player) {
    time_since_shoot := time.duration_seconds(time.tick_since(last_shoot_tick))

    if rl.IsMouseButtonDown(.LEFT) && time_since_shoot > SHOOT_DELAY {
        last_shoot_tick = time.tick_now()

        // kick
        vel -= get_weapon_dir(player) * 100

        // sfx
        try_play_sound(audio, audio.laser, debounce = 0.05)

        // vfx
        weapon_tip      := get_weapon_tip(player)
        particle_dir    := get_weapon_dir(player)
        spawn_particles_direction(particle_system, weapon_tip, +particle_dir, 10, min_speed = 300, max_speed = 2000, min_lifetime = 0.05, max_lifetime = 0.1, color = rl.YELLOW, angle = 0.1, drag = 10)
        particle_dir     = rl.Vector2Rotate(particle_dir, math.PI / 2)
        spawn_particles_direction(particle_system, weapon_tip, -particle_dir, 5, min_speed = 300, max_speed = 500, min_lifetime = 0.05, max_lifetime = 0.1, color = rl.YELLOW, angle = 0.2, drag = 10)
        spawn_particles_direction(particle_system, weapon_tip, +particle_dir, 5, min_speed = 300, max_speed = 500, min_lifetime = 0.05, max_lifetime = 0.1, color = rl.YELLOW, angle = 0.2, drag = 10)

        add_projectile(
            newProjectile = Projectile {
                pos = get_weapon_tip(player),
                dir = linalg.normalize(rl.GetMousePosition() - pos),
                spd = 2000,
                len = 15
            },
            projectiles = projectiles,
        )
    }

    if rl.IsMouseButtonPressed(.RIGHT){
        // kick
        vel -= get_weapon_dir(player) * 500

        // sfx
        try_play_sound(audio, audio.laser, debounce = 0.05)

        // vfx
        weapon_tip      := get_weapon_tip(player)
        particle_dir    := get_weapon_dir(player)
        spawn_particles_direction(particle_system, weapon_tip, +particle_dir, 10, min_speed = 300, max_speed = 2000, min_lifetime = 0.05, max_lifetime = 0.1, color = rl.YELLOW, angle = 0.3, drag = 10)

        for i in 0..<8 {
            add_projectile(
                newProjectile = Projectile {
                    pos = get_weapon_tip(player),
                    dir = rl.Vector2Rotate(linalg.normalize(rl.GetMousePosition() - pos), rand.float32_range(-0.2, 0.2)),
                    spd = 1500,
                    len = 10
                },
                projectiles = projectiles,
            )
        }
    }
}

draw_player_weapon :: proc(using player : ^Player) {
    weapon_rect  := rl.Rectangle{pos.x, pos.y, WEAPON_WIDTH, WEAPON_LENGTH}
    weapon_pivot := rl.Vector2{WEAPON_WIDTH / 2, 0}
    weapon_angle := get_weapon_deg(player)

    rl.DrawRectanglePro(weapon_rect, weapon_pivot, weapon_angle, rl.GRAY)
}

@private
get_weapon_dir :: #force_inline proc(using player : ^Player) -> rl.Vector2 {
    return linalg.normalize(rl.GetMousePosition() - pos)
}

@private
get_weapon_rad :: #force_inline proc(using player : ^Player) -> f32 {
    dir := get_weapon_dir(player)
    return linalg.atan2(dir.y, dir.x) - math.PI / 2
}

@private
get_weapon_deg :: #force_inline proc(using player : ^Player) -> f32 {
    return linalg.to_degrees(get_weapon_rad(player))
}

@private
get_weapon_tip :: #force_inline proc(using player : ^Player) -> rl.Vector2 {
    local_tip := rl.Vector2{0, WEAPON_LENGTH}
    local_tip  = rl.Vector2Rotate(local_tip, get_weapon_rad(player))
    return local_tip + pos
}