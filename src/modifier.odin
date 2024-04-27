// This code provides utilities for generating and applying random gameplay modifiers.
// Currently it is only used by the leveling system to apply buffs to ther player/weapon.

package game

import "core:fmt"
import "core:time"
import "core:math"
import "core:math/rand"
import "core:math/linalg"
import rl "vendor:raylib"

// All the types of modifiers
ModifierType :: enum {
    MaxHealth,
    ProjectileDelay,
    DoubleBarrel,
    TripleBarrel,
    ProjectileVelocity,
    CollimatingLens,
    ReflectiveCascade,
    ProjectileScreenDeflect,
    ProjectileHoming,
    PlayerAcceleration,
    MagnetBattery,
    OverflowBarrage,
    ThrusterBarrage,
    AdrenalineRush,
    ChronalDisruptor,
    RangeFinder,
    RetrofireOverdrive,
}

// A Modifier is a thing that can be applied (chosen) to the game state
// It can do anything, but currently is used for level ups
Modifier :: struct {
    name        : cstring,                      // Name of the modifier. Shown in the level up gui
    description : cstring,                      // Description of the modifier. Shown in the level up gui
    type        : ModifierType,                 // What type of modifier is this?
    is_valid    : proc(game : ^Game) -> bool,   // Function that can be called to check if a modifier is valid
    on_choose   : proc(game : ^Game),           // Function that can be called to apply the modifier to the current game state
    single_use  : bool,                         // Indicates that this modifier can only be chosen once
    use_count   : int,                          // How many times this modifier has been used
}

// Mapping of modifier types to modifier pairs.
// You can index into this map with a modifier type and get back a modifier.
// This is where the modifier functionality is actually defined.
// Note: This should probably be moved into a struct
ModifierChoices := [ModifierType]Modifier {
    .MaxHealth = { 
        type        = .MaxHealth,
        name        = "Armor Upgrade",
        description = "Player's max health increased",
        on_choose   = proc(game : ^Game) { game.player.max_hth += 100 }
    },
    .ProjectileDelay = {
        type        = .ProjectileDelay,
        name        = "Itchy Finger",
        description = "Player shoots more rapidly",
        is_valid    = proc(game : ^Game) -> bool { return game.weapon.delay > 0.05 },
        on_choose   = proc(game : ^Game) { game.weapon.delay *= 0.8 }
    },
    .DoubleBarrel = {
        type        = .DoubleBarrel,
        name        = "Double Barrel",
        description = "Player shoots two projectiles. Increased spread.",
        single_use  = true,
        is_valid    = proc(game : ^Game) -> bool { return game.weapon.count < 2 },
        on_choose   = proc(game : ^Game) { 
            game.weapon.count = 2
            game.weapon.spread += math.to_radians(f32(5))
        }
    },
    .TripleBarrel = {
        type        = .TripleBarrel,
        name        = "Triple Barrel",
        description = "Player shoots three projectiles. Increased spread.",
        single_use  = true,
        is_valid    = proc(game : ^Game) -> bool { return game.weapon.count < 3 && game.weapon.count > 1},
        on_choose   = proc(game : ^Game) { 
            game.weapon.count = 3 
            game.weapon.spread += math.to_radians(f32(2))
        }
    },
    .ProjectileVelocity = {
        type        = .ProjectileVelocity,
        name        = "Longer Barrel",
        description = "Player's projectiles move faster",
        is_valid    = proc(game : ^Game) -> bool { return game.weapon.speed < 5000 },
        on_choose   = proc(game : ^Game) { game.weapon.speed *= 1.4 }
    },
    .CollimatingLens = {
        type        = .CollimatingLens,
        name        = "Collimating Lens",
        description = "Player's projectiles ricochet off enemies once",
        single_use  = true,
        on_choose   = proc(game : ^Game) { game.weapon.bounces = 1 }
    },
    .ReflectiveCascade = {
        type        = .ReflectiveCascade,
        name        = "Reflective\nCascade",
        description = "Player's projectiles can ricochet an additional time",
        is_valid    = proc(game : ^Game) -> bool { return game.weapon.bounces > 0 },
        on_choose   = proc(game : ^Game) { game.weapon.bounces = 1 }
    },
    .ProjectileScreenDeflect = {
        type        = .ProjectileScreenDeflect,
        name        = "Edge Bounce",
        description = "Projectiles deflect of screen edges",
        single_use  = true,
        is_valid    = proc(game : ^Game) -> bool { return game.weapon.bounces > 0 },
        on_choose   = proc(game : ^Game) { game.projectiles.deflect_off_window = true }
    },
    .ProjectileHoming = {
        type        = .ProjectileHoming,
        name        = "Homing Sensors",
        description = "Projectiles steer towards nearby enemies",
        single_use  = true,
        on_choose   = proc(game : ^Game) { 
            game.projectiles.homing_dist = 4
            game.projectiles.homing_speed = 5
        }
    },
    .PlayerAcceleration = {
        type        = .PlayerAcceleration,
        name        = "Thruster Upgrade",
        description = "Accelerate faster",
        on_choose   = proc(game : ^Game) { game.player.acc *= 1.3 }
    },
    .MagnetBattery = {
        type        = .MagnetBattery,
        name        = "Bigger Magnet",
        description = "Pickups are magnetized from a further away",
        on_choose   = proc(game : ^Game) { game.pickups.attraction_radius += 100 }
    },
    .OverflowBarrage = {
        type        = .OverflowBarrage,
        name        = "Overflow Barrage",
        description = "When at full HP, health pickups are converted into projectiles",
        single_use  = true,
        on_choose   = proc(game : ^Game) { 
            append(
                &game.pickups.hp_pickup_actions, 
                proc(game : ^Game, pickup : ^Pickup) {
                    if game.player.hth >= game.player.max_hth - 1 {
                        try_play_sound(&game.audio, game.audio.laser)
                        shoot(&game.projectiles, game.player, game.weapon, pos = pickup.pos, dir = get_weapon_dir(game.player), color = rl.Color{ 0, 228, 48, 100 })
                    }
                }
            )
        }
    },
    .ThrusterBarrage = {
        type        = .ThrusterBarrage,
        name        = "Thruster Barrage",
        description = "Thruster shoots projectiles",
        single_use  = true,
        on_choose   = proc(game : ^Game) { 
            add_action(&game.player.on_emit_thruster_particles, proc(emit : ^bool, game : ^Game) {
                if rand.float32_range(0, 1.25) > 1 - (1 / game.player.acc / PLAYER_ACCELERATION) {
                    try_play_sound(&game.audio, game.audio.laser)
                    shoot(&game.projectiles, game.player, game.weapon, get_player_base(game.player), -get_player_dir(game.player), color = rl.Color{ 255, 161, 0, 100 })
                }
            })
        }
    },
    .AdrenalineRush = {
        type        = .AdrenalineRush,
        name        = "Adrenaline Rush",
        description = "Increases rate of fire when at low health",
        single_use  = true,
        on_choose   = proc(game : ^Game) { 
            add_action(&game.weapon.on_calc_delay, proc(delay : ^f64, game : ^Game) {
                if game.player.hth / game.player.max_hth < 0.5 {
                    delay^ *= 0.75
                }
            })
         }
    },
    .ChronalDisruptor = {
        type        = .ChronalDisruptor,
        name        = "Chronal Disruptor",
        description = "Slows time when enemies are near",
        single_use  = true,
        on_choose   = proc(game : ^Game) { 
            add_action(&game.on_calc_time_scale, proc(time_scale : ^f32, game : ^Game) {
                if near, dist := near_enemy(game.player, game.enemies); near {
                    n_dist := math.smoothstep(f32(20), 100.0, dist)
                    n_scale := math.lerp(f32(0.2), 1, n_dist)
                    time_scale^ *= n_scale
                }
            })
         }
    },
    .RangeFinder = {
        type        = .RangeFinder,
        name        = "Range Finder",
        description = "Installs a laser sight onto the player ship",
        single_use  = true,
        on_choose   = proc(game : ^Game) { 
            add_action(&game.weapon.on_draw_weapon, proc(draw : ^bool, game : ^Game) {
                rl.DrawLineV(game.player.pos, rl.GetMousePosition(), {255, 0, 0, 80})
            })
         }
    },
    .RetrofireOverdrive = {
        type        = .RetrofireOverdrive,
        name        = "Retrofire Overdrive",
        description = "Player fire rate increases when flying backwards",
        single_use  = true,
        on_choose   = proc(game : ^Game) { 
            add_action(&game.weapon.on_calc_delay, proc(delay : ^f64, game : ^Game) {
                if vel_dir, ok := safe_normalize(game.player.vel); ok {
                    if linalg.dot(vel_dir, get_player_dir(game.player)) < -0.5 {
                        delay^ *= 0.5
                    }
                }
            })
        }
    },
}

unload_mods :: proc() {
    for &mod in ModifierChoices {
        mod.use_count = 0
    }
}

// Utility function to quickly check if a modifier is valid
is_mod_valid :: proc(mod : Modifier, game : ^Game) -> bool {
    if mod.is_valid != nil {
        return mod.is_valid(game) && (!mod.single_use || mod.use_count == 0)
    }
   
    return !mod.single_use || mod.use_count == 0
}

use_mod :: proc(mod : ^Modifier, game : ^Game) {
    mod.on_choose(game)
    mod.use_count += 1
}

// Fetches a random modifier and optionally allows certain modifier types to be excluded.
// Excluding types is helpful for preventing the same modifiers choice from being presented twice in the level up gui.
// The `..ModifierType` syntax lets us pass excluded modifier types as an array, or as individual function arguments.
random_modifier :: proc(game : ^Game, excluded_types : ..ModifierType) -> (^Modifier, bool) {
    // Get the number of available modifier types.
    modifier_count := len(ModifierType)
    // We'll use a random offset when indexing into the modifiers
    offset := rand.int_max(modifier_count)
    modifiers : for i : int = 0; i < modifier_count; i += 1 {
        // The modifier index will be added to the random offset and we
        // use the modulo operator to make sure the index loops back around to 0 if it surpasses the number of modifiers
        idx := (offset + i) % modifier_count

        // Now we have a random number between 0 and the number of possible modifier types.
        // We can just cast the index to a ModifierType!
        type := cast(ModifierType)idx

        // If the type is excluded, check the next modifier type
        for excluded_type in excluded_types {
            if excluded_type == type do continue modifiers
        }
        
        // Get the modifier for this modifier type
        mod := &ModifierChoices[type]
        
        // If the modifier is invalid, check the next modifier type
        if !is_mod_valid(mod^, game) do continue

        // We found a valid modifier pair!
        return mod, true
    }

    // We could not find a valid modifier pair. All the available modifiers were either excluded or invalid.
    return {}, false
}