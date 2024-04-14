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
PICKUP_ATTRACTION_RADIUS    :: 100
PICKUP_ATTRACTION_FORCE     :: 1
PICKUP_LIFETIME             :: 20

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
    pool : Pool(1024, Pickup)
}

init_pickups :: proc(using pickups : ^Pickups) {
    pool_init(&pool)
}

unload_pickups :: proc(using pickups : ^Pickups) {
    pool_delete(&pool)
}

tick_pickups :: proc(using game : ^Game, dt : f32) {
    for i := 0; i < pickups.pool.count; i += 1 {
        pickup  := &pickups.pool.instances[i]
        diff    := player.pos - pickup.pos
        dist    := linalg.length(diff)
        if dist < PICKUP_RADIUS + player.siz / 2 {
            game.leveling.xp += pickup.xp
            game.player.hth = min(game.player.hth + f32(pickup.hp), game.player.max_hth)
            pool_release(&pickups.pool, i)
            i -= 1
            continue
        }
        else if dist < PICKUP_ATTRACTION_RADIUS || pickup.following {
            dir         := diff / dist
            pickup.vel  += dir * PICKUP_ATTRACTION_FORCE * 1 - (dist / PICKUP_ATTRACTION_RADIUS) * dt
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
        rl.DrawCircleV(pickup.pos, 3, rl.GREEN if pickup.hp > 0 else rl.YELLOW)
    }
}

spawn_pickup :: proc(using pickups : ^Pickups, pos : rl.Vector2, type : PickupType) {
    new_pickup := Pickup {
        pos = pos,
    }

    switch type {
        case .Health: new_pickup.hp = 1
        case .XP: new_pickup.xp = 1
    }

    new_pickup.vel = rl.Vector2Rotate({0, rand.float32_range(0, 5)}, math.TAU)

    pool_add(&pool, new_pickup)
}