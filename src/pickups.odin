package game

import "core:fmt"
import "core:time"
import "core:math"
import "core:math/rand"
import "core:math/linalg"
import rl "vendor:raylib"

SPAWN_DELAY                 :: 20
PICKUP_RADIUS               :: 10
PICKUP_COLOR                :: rl.YELLOW
PICKUP_DRAG                 :: 2
PICKUP_ATTRACTION_RADIUS    :: 200
PICKUP_ATTRACTION_FORCE     :: 5000
PICKUP_LIFETIME             :: 30

PickupType :: enum {
    Health, XP
}

Pickup :: struct {
    pos         : rl.Vector2,
    vel         : rl.Vector2,
    col         : rl.Color,
    hp          : int,
    xp          : int,
    time        : f32,
    following   : bool
}

Pickups :: struct {
    pool : Pool(512, Pickup)
}

init_pickups :: proc(using pickups : ^Pickups) {
    pool_init(&pool)
}

unload_pickups :: proc(using pickups : ^Pickups) {
    pool_delete(&pool)
}

tick_pickups :: proc(using game : ^Game, dt : f32) {
    if !game.player.alive do return
    
    for i := 0; i < pickups.pool.count; i += 1 {
        pickup  := &pickups.pool.instances[i]
        diff    := player.pos - pickup.pos
        dist    := linalg.length(diff)
        if dist < PICKUP_RADIUS + player.siz / 2 {
            if pickup.xp > 0 {
                game.leveling.xp += pickup.xp
                try_play_sound(&audio, audio.collect_xp)
            }
            if pickup.hp > 0 {
                game.player.hth = min(game.player.hth + f32(pickup.hp), game.player.max_hth)
                try_play_sound(&audio, audio.collect_hp)
            }
            spawn_particles_burst(&line_particles, player.pos, pickup.vel * 0.5, 32, 50, 200, 0.2, 0.5, pickup.col, drag = 3)
            pool_release(&pickups.pool, i)
            i -= 1
            continue
        }
        else if dist < PICKUP_ATTRACTION_RADIUS || pickup.following {
            dir         := diff / dist
            pickup.vel  += dir * PICKUP_ATTRACTION_FORCE * math.smoothstep(f32(0.5), 1, f32(pickup.time)) * dt;

            pickup.following   = true
        }

        pickup.vel  *= 1 / (1 + PICKUP_DRAG * dt)
        pickup.pos  += pickup.vel * dt
        pickup.time += dt

        if pickup.time > PICKUP_LIFETIME {
            pool_release(&pickups.pool, i)
            i -= 1
        }
    }
}

draw_pickups :: proc(using pickups : ^Pickups) {
    for pickup in pool.instances[0:pool.count] {
        rl.DrawCircleV(pickup.pos, 4 + f32(math.sin_f32(pickup.time * 5)) * math.smoothstep(f32(PICKUP_LIFETIME), PICKUP_LIFETIME - 2, pickup.time), pickup.col)
    }
}

spawn_pickup :: proc(using pickups : ^Pickups, pos : rl.Vector2, type : PickupType) {
    new_pickup := Pickup {
        pos = pos,
    }

    switch type {
        case .Health: 
            new_pickup.hp = 1
            new_pickup.col = { 0, 228, 48, 150 }
        case .XP:
            new_pickup.xp = 1
            new_pickup.col = { 255, 203, 0, 150 }
    }

    new_pickup.vel = rl.Vector2Rotate({0, rand.float32_range(0, 100)}, rand.float32_range(0, math.TAU))

    pool_add(&pool, new_pickup)
}