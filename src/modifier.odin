package game

import "core:fmt"
import "core:time"
import "core:math"
import "core:math/rand"
import "core:math/linalg"
import rl "vendor:raylib"

ModifierType :: enum {
    Heal,
    MaxHealth,
    WeaponDelay,
    WeaponCount,
    WeaponSpeed,
    WeaponAccuracy,
    WeaponBounce,
    WeaponKick,
    PlayerSpeed,
    PlayerAcceleration,
}

Modifier :: struct {
    description : cstring,
    type        : ModifierType,
    is_valid    : proc(game : ^Game) -> bool,
    on_choose   : proc(game : ^Game),
}

ModifierPair :: struct {
    positive_mod : Modifier,
    negative_mod : Modifier,
}

ModifierChoices := map[ModifierType]ModifierPair {
    .Heal = { 
        positive_mod = {
            type        = .Heal,
            description = "Heal 100%",
            is_valid    = proc(game : ^Game) -> bool { return game.player.hth < game.player.max_hth },
            on_choose   = proc(game : ^Game) { game.player.hth = game.player.max_hth },
        },
        negative_mod = {
            type        = .Heal,
            description = "Lose 25% Health",
            is_valid    = proc(game : ^Game) -> bool { return game.player.hth < game.player.max_hth },
            on_choose   = proc(game : ^Game) { game.player.hth *= 0.75 },
        },
    },
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
    .WeaponSpeed = {
        positive_mod = {
            type        = .WeaponSpeed,
            description = "Velocity + 40%",
            is_valid    = proc(game : ^Game) -> bool { return game.weapon.speed < 5000 },
            on_choose   = proc(game : ^Game) { game.weapon.speed *= 1.4 }
        },
        negative_mod = {
            type        = .WeaponSpeed,
            description = "Velocity - 10%",
            is_valid    = proc(game : ^Game) -> bool { return game.weapon.speed > 250 },
            on_choose   = proc(game : ^Game) { game.weapon.speed *= 0.9 },
        },
    },
    .WeaponAccuracy = {
        positive_mod = {
            type        = .WeaponAccuracy,
            description = "Accuracy + 30%",
            is_valid    = proc(game : ^Game) -> bool { return game.weapon.spread > 0 },
            on_choose   = proc(game : ^Game) { game.weapon.spread = math.max(0, game.weapon.spread - game.weapon.speed * 0.3) }
        },
        negative_mod = {
            type        = .WeaponAccuracy,
            description = "Accuracy - 30%",
            is_valid    = proc(game : ^Game) -> bool { return game.weapon.speed < math.TAU },
            on_choose   = proc(game : ^Game) { game.weapon.spread = math.min(math.TAU, game.weapon.spread + game.weapon.speed * 0.3) },
        },
    },
    .WeaponBounce = {
        positive_mod = {
            type        = .WeaponBounce,
            description = "Bounces + 1",
            on_choose   = proc(game : ^Game) { game.weapon.bounces += 1 }
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
    .PlayerSpeed = {
        positive_mod = {
            type        = .PlayerSpeed,
            description = "Speed + 25%",
            on_choose   = proc(game : ^Game) { game.player.spd *= 1.25 }
        },
        negative_mod = {
            type        = .PlayerSpeed,
            description = "Speed - 5%",
            on_choose   = proc(game : ^Game) { game.player.spd *= 0.95 },
        },
    },
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

is_mod_valid :: proc(mod : Modifier, game : ^Game) -> bool {
    if mod.is_valid == nil do return true
    return mod.is_valid(game)
}

random_modifier_pair :: proc(game : ^Game, excluded_types : ..ModifierType) -> (ModifierPair, bool) {
    positive_mod, positive_mod_found := random_positive_modifier(game, ..excluded_types)
    if !positive_mod_found do return {}, false
    negative_mod, negative_mod_type, negative_mod_found := random_negative_modifier(game, positive_mod.type)
    if !negative_mod_found do return {}, false

    return {positive_mod, negative_mod}, true
}

random_positive_modifier :: proc(game : ^Game, excluded_types : ..ModifierType) -> (Modifier, bool) {
    modifier_count := len(ModifierType)
    offset := rand.int_max(modifier_count)
    modifiers : for i : int = 0; i < modifier_count; i += 1 {
        idx := (offset + i) % modifier_count
        type := cast(ModifierType)idx

        for excluded_type in excluded_types {
            if excluded_type == type do continue modifiers
        }
        
        mod := ModifierChoices[type].positive_mod
        if !is_mod_valid(mod, game) do continue
        return mod, true
    }
    return {}, false
}

random_negative_modifier :: proc(game : ^Game, excluded_types : ..ModifierType) -> (Modifier, ModifierType, bool) {
    modifier_count := len(ModifierType)
    offset := rand.int_max(modifier_count)
    modifiers : for i : int = 0; i < modifier_count; i += 1 {
        idx := (offset + i) % modifier_count
        type := cast(ModifierType)idx

        for excluded_type in excluded_types {
            if excluded_type == type do continue modifiers
        }

        mod := ModifierChoices[type].negative_mod
        if !is_mod_valid(mod, game) do continue
        return mod, type, true
    }
    return {}, {}, false
}