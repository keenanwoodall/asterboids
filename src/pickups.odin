// This code manages pickups. Pickups are dropped by killed enemies and give the player hp or xp

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
PICKUP_ATTRACTION_FORCE     :: 5000
PICKUP_LIFETIME             :: 30

// The state of a pickup.
Pickup :: struct {
    pos         : rl.Vector2,   // Position
    vel         : rl.Vector2,   // Velocity
    col         : rl.Color,     // Color
    hp          : int,          // Health points (added to player on pickup)
    xp          : int,          // Experience points (added to player on pickup)
    time        : f32,          // how long this pickup has been alive
    following   : bool          // Is this pickup following the player?
                                // When a player gets close enough to a pickup, it automatically follows the player as if it is magnetized
}

// The procedure to call when hp or xp is picked up. Is passed the pickup type and count and can return modified values
PickupAction :: proc(game : ^Game, pickup : ^Pickup)

// Just a pool of pickups.
Pickups :: struct {
    // Note: This Pool data type should be used in more places like particles, enemies, projectiles
    pool                : Pool(512, Pickup),
    attraction_radius   : f32,                      // Attraction distance for pickups
    hp_pickup_actions   : [dynamic]PickupAction,    // List of procedures to call when hp is picked up. Returning false cancels pickup
    xp_pickup_actions   : [dynamic]PickupAction,    // List of procedures to call when xp is picked up. Returning false cancels pickup
}

// Init functions are called when the game first starts.
// Here we can initialize data the pickup pool.
init_pickups :: proc(using pickups : ^Pickups) {
    attraction_radius = PICKUP_ATTRACTION_RADIUS
    hp_pickup_actions = make([dynamic]PickupAction)
    xp_pickup_actions = make([dynamic]PickupAction)
    init_pool(&pool)
}

// Unload functions are called when the game is closed or restarted.
// Here we can free the memory allocated by the pickups pool.
unload_pickups :: proc(using pickups : ^Pickups) {
    delete(hp_pickup_actions)
    delete(xp_pickup_actions)
    delete_pool(&pool)
}

// Tick functions are called every frame by the game.
// Here we'll simulate the physics and player-pickup collision of each pickup
tick_pickups :: proc(using game : ^Game) {
    if !game.player.alive do return
    
    // Loop over all the pickups
    for i := 0; i < pickups.pool.count; i += 1 {
        pickup  := &pickups.pool.instances[i]
        // Get the difference in player and pickup position, and the distance
        diff    := player.pos - pickup.pos
        dist    := linalg.length(diff)

        // If the player is close enough to the pickup to pick it up...
        if dist < PICKUP_RADIUS + player.siz / 2 {
            // Play a sound based on whether the pickup is for xp or hp
            if pickup.xp > 0 {
                for pickup_action in pickups.xp_pickup_actions do pickup_action(game, pickup)
                if pickup.xp > 0 {
                    game.leveling.xp += pickup.xp
                    try_play_sound(&audio, audio.collect_xp)
                }
            }
            if pickup.hp > 0 {
                for pickup_action in pickups.hp_pickup_actions do pickup_action(game, pickup)
                if pickup.hp > 0 {
                    game.player.hth = min(game.player.hth + pickup.hp, game.player.max_hth)
                    try_play_sound(&audio, audio.collect_xp)
                }
            }
            // Spawn some particles and release the pickup
            spawn_particles_burst(&line_particles, player.pos, pickup.vel * 0.5, 32, 50, 200, 0.2, 0.5, pickup.col, drag = 3)
            release_pool(&pickups.pool, i)
            // Make sure we decrement i so our loop compensates for the removed pickup!
            i -= 1
            continue
        } // Otherwise, if the player is close enough to the pickup to attract it
        else if dist < pickups.attraction_radius || pickup.following {
            // Add a force to the pickup towards the player.
            // The force starts at 0 when the pickup is first created and increases over time 
            // to add visual interest to pickups which are close to the player when they are first spawned.
            dir         := diff / dist
            pickup.vel  += dir * PICKUP_ATTRACTION_FORCE * math.smoothstep(f32(0.5), 1, f32(pickup.time)) * game_delta_time;

            // Once the player is close enough to a pickup for it to be attracted to the player it will always follow the player.
            // This prevents the annoying scenario where a pickup moves towards and overshoots the player, exceeding the attract radius
            pickup.following = true
        }

        pickup.vel  *= 1 / (1 + PICKUP_DRAG * game_delta_time) // Apply drag to the pickup
        pickup.pos  += pickup.vel * game_delta_time // Move the pickup along its velocity
        pickup.time += game_delta_time              // Increment the pickup lifetime

        // Release the pickup if it has lived longer than the pickup lifetime
        if pickup.time > PICKUP_LIFETIME {
            release_pool(&pickups.pool, i)
            // Make sure we decrement i so our loop compensates for the removed pickup!
            i -= 1
        }
    }
}

// Draw functions are called at the end of each frame by the game.
// Each pickup is just a circle whose radius animates subtely along a sine wave.
draw_pickups :: proc(using pickups : ^Pickups) {
    for pickup in pool.instances[0:pool.count] {
        rl.DrawCircleV(pickup.pos, 4 + f32(math.sin_f32(pickup.time * 5)) * math.smoothstep(f32(PICKUP_LIFETIME), PICKUP_LIFETIME - 2, pickup.time), pickup.col)
    }
}

// This enum is just used as a convenience for the following function
PickupType :: enum {
    Health, XP
}

// Spawns a pickup at a position
spawn_pickup :: proc(using pickups : ^Pickups, pos : rl.Vector2, type : PickupType) {
    new_pickup := Pickup {
        pos = pos,
    }

    // Set the new pickup's color, hp and xp based on the passed pickup type
    switch type {
        case .Health: 
            new_pickup.hp = 1
            new_pickup.col = { 0, 228, 48, 150 }
        case .XP:
            new_pickup.xp = 1
            new_pickup.col = { 255, 203, 0, 150 }
    }

    // Give the pickup a random initial velocity
    new_pickup.vel = rl.Vector2Rotate({0, rand.float32_range(0, 100)}, rand.float32_range(0, math.TAU))

    add_pool(&pool, new_pickup)
}