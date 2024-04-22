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
    //Heal,
    MaxHealth,
    WeaponDelay,
    WeaponCount,
    WeaponVelocity,
    WeaponAccuracy,
    WeaponBounce,
    WeaponKick,
    //PlayerSpeed, // no speed buffs for balancing reasons
    PlayerAcceleration,
}

// A Modifier is a thing that can be applied (chosen) to the game state
// It can do anything, but currently is used for level ups
Modifier :: struct {
    description : cstring,                      // Description of the modifier. Shown in the level up gui
    type        : ModifierType,                 // What type of modifier is this?
    is_valid    : proc(game : ^Game) -> bool,   // Function that can be called to check if a modifier is valid
    on_choose   : proc(game : ^Game),           // Function that can be called to apply the modifier to the current game state
}

// Just a pair of modifiers! When leveling up, the player is presented with two modifier types, 
// and for each they can choose the "positive or "negative" variant. 
// This is kinda silly, but the player might want to debuf something like weapon accuracy for more spread
ModifierPair :: struct {
    positive_mod : Modifier,
    negative_mod : Modifier,
}

// Mapping of modifier types to modifier pairs.
// You can index into this map with a modifier type like `WeaponAccuracy` and get back a modifier pair with an accuracty buff and debuff modifier.
// This is where the modifier functionality is actually defined.
ModifierChoices := [ModifierType]ModifierPair {
    /* Healing is disabled as a level up choice now that there are health pickups */
    // .Heal = { 
    //     positive_mod = {
    //         type        = .Heal,
    //         description = "Heal 100%",
    //         is_valid    = proc(game : ^Game) -> bool { return game.player.hth < game.player.max_hth },
    //         on_choose   = proc(game : ^Game) { game.player.hth = game.player.max_hth },
    //     },
    //     negative_mod = {
    //         type        = .Heal,
    //         description = "Lose 25% Health",
    //         is_valid    = proc(game : ^Game) -> bool { return game.player.hth < game.player.max_hth },
    //         on_choose   = proc(game : ^Game) { game.player.hth *= 0.75 },
    //     },
    // },
    .MaxHealth = { 
        positive_mod = {
            type        = .MaxHealth,
            description = "Max Health + 100",
            on_choose   = proc(game : ^Game) { game.player.max_hth += 100 }
        },
        negative_mod = {
            type        = .MaxHealth,
            description = "Max Health - 25",
            is_valid    = proc(game : ^Game) -> bool { return game.player.max_hth > 25 },
            on_choose   = proc(game : ^Game) {
                game.player.max_hth -= 25
                game.player.hth = math.min(game.player.hth, game.player.max_hth)
                if game.player.hth <= 0 do game.player.alive = false
            },
        },
    },
    .WeaponDelay = {
        positive_mod = {
            type        = .WeaponDelay,
            description = "Fire Rate + 20%",
            is_valid    = proc(game : ^Game) -> bool { return game.weapon.delay > 0.05 },
            on_choose   = proc(game : ^Game) { game.weapon.delay *= 0.8 }
        },
        negative_mod = {
            type        = .WeaponDelay,
            description = "Fire Rate - 5%",
            is_valid    = proc(game : ^Game) -> bool { return game.weapon.delay < 1 },
            on_choose   = proc(game : ^Game) { game.weapon.delay *= 1.05 },
        },
    },
    .WeaponCount = {
        positive_mod = {
            type        = .WeaponCount,
            description = "Projectile Count + 2",
            is_valid    = proc(game : ^Game) -> bool { return game.weapon.count < 64 },
            on_choose   = proc(game : ^Game) { game.weapon.count += 2 }
        },
        negative_mod = {
            type        = .WeaponCount,
            description = "Projectile Count - 1",
            is_valid    = proc(game : ^Game) -> bool { return game.weapon.count > 1 },
            on_choose   = proc(game : ^Game) { game.weapon.count -= 1 },
        },
    },
    .WeaponVelocity = {
        positive_mod = {
            type        = .WeaponVelocity,
            description = "Velocity + 40%",
            is_valid    = proc(game : ^Game) -> bool { return game.weapon.speed < 5000 },
            on_choose   = proc(game : ^Game) { game.weapon.speed *= 1.4 }
        },
        negative_mod = {
            type        = .WeaponVelocity,
            description = "Velocity - 10%",
            is_valid    = proc(game : ^Game) -> bool { return game.weapon.speed > 250 },
            on_choose   = proc(game : ^Game) { game.weapon.speed *= 0.9 },
        },
    },
    .WeaponAccuracy = {
        positive_mod = {
            type        = .WeaponAccuracy,
            description = "Accuracy + 50%",
            is_valid    = proc(game : ^Game) -> bool { return game.weapon.spread > math.to_radians(f32(0.5)) },
            on_choose   = proc(game : ^Game) { game.weapon.spread *= 0.5 }
        },
        negative_mod = {
            type        = .WeaponAccuracy,
            description = "Accuracy - 30%",
            is_valid    = proc(game : ^Game) -> bool { return game.weapon.spread < math.TAU },
            on_choose   = proc(game : ^Game) { game.weapon.spread = math.min(math.TAU, game.weapon.spread + game.weapon.spread * 0.3) },
        },
    },
    .WeaponBounce = {
        positive_mod = {
            type        = .WeaponBounce,
            description = "Bounces + 2",
            on_choose   = proc(game : ^Game) { game.weapon.bounces += 2 }
        },
        negative_mod = {
            type        = .WeaponBounce,
            description = "Bounces - 1",
            is_valid    = proc(game : ^Game) -> bool { return game.weapon.bounces > 0 },
            on_choose   = proc(game : ^Game) { game.weapon.bounces -= 1 },
        },
    },
    .WeaponKick = {
        positive_mod = {
            type        = .WeaponKick,
            description = "Kick - 50%",
            on_choose   = proc(game : ^Game) { game.weapon.kick *= 0.5 }
        },
        negative_mod = {
            type        = .WeaponKick,
            description = "Kick + 10%",
            on_choose   = proc(game : ^Game) { game.weapon.kick *= 1.1 },
        },
    },
    /* Player speed modifiers disabled for balancing (for now?) */
    // .PlayerSpeed = {
    //     positive_mod = {
    //         type        = .PlayerSpeed,
    //         description = "Speed + 25%",
    //         on_choose   = proc(game : ^Game) { game.player.spd *= 1.25 }
    //     },
    //     negative_mod = {
    //         type        = .PlayerSpeed,
    //         description = "Speed - 5%",
    //         on_choose   = proc(game : ^Game) { game.player.spd *= 0.95 },
    //     },
    // },
    .PlayerAcceleration = {
        positive_mod = {
            type        = .PlayerAcceleration,
            description = "Acceleration + 30%",
            on_choose   = proc(game : ^Game) { game.player.acc *= 1.3 }
        },
        negative_mod = {
            type        = .PlayerAcceleration,
            description = "Acceleration - 10%",
            on_choose   = proc(game : ^Game) { game.player.acc *= 0.9 },
        },
    }
}

// Utility function to quickly check if a modifier is valid
is_mod_valid :: proc(mod : Modifier, game : ^Game) -> bool {
    if mod.is_valid == nil do return true
    return mod.is_valid(game)
}

// Fetches a random modifier pair and optionally allows certain modifier types to be excluded.
// Excluding types is helpful for preventing the same modifiers choice from being presented twice in the level up gui.
// The `..ModifierType` syntax lets us pass excluded modifier types as an array, or as individual function arguments.
random_modifier_pair :: proc(game : ^Game, excluded_types : ..ModifierType) -> (ModifierPair, bool) {
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
        
        // Get the pair of positive/negative modifiers for this modifier type
        mod_pair := ModifierChoices[type]
        
        // If both modifiers are invaliud, check the next modifier type
        if !is_mod_valid(mod_pair.positive_mod, game) && !is_mod_valid(mod_pair.negative_mod, game) do continue

        // We found a valid modifier pair!
        return mod_pair, true
    }

    // We could not find a valid modifier pair. All the available modifiers were either excluded or invalid.
    return {}, false
}