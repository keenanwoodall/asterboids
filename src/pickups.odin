package game

import "core:fmt"
import "core:time"
import "core:math"
import "core:math/rand"
import "core:math/linalg"
import rl "vendor:raylib"

SPAWN_DELAY                 :: 20
PICKUP_RADIUS               :: 5
PICKUP_COLOR                :: rl.GREEN
PICKUP_DRAG                 :: 3
PICKUP_ATTRACTION_RADIUS    :: 100
PICKUP_ATTRACTION_FORCE     :: 0.25

ModifierType :: enum {
    Heal,
    MaxHealth,
    WeaponDelay,
    WeaponCount,
    WeaponSpeed,
    WeaponAccuracy,
    WeaponBounce,
    WeaponKick,
    // PlayerSpeed,
    // PlayerAcceleration,
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
            description = "Fire Rate + 30%",
            is_valid    = proc(game : ^Game) -> bool { return game.weapon.delay > 0.05 },
            on_choose   = proc(game : ^Game) { game.weapon.delay *= 0.7 }
        },
        negative_mod = {
            type        = .WeaponDelay,
            description = "Fire Rate - 10%",
            is_valid    = proc(game : ^Game) -> bool { return game.weapon.delay < 1 },
            on_choose   = proc(game : ^Game) { game.weapon.delay *= 1.1 },
        },
    },
    .WeaponCount = {
        positive_mod = {
            type        = .WeaponCount,
            description = "Projectile Count + 2",
            is_valid    = proc(game : ^Game) -> bool { return game.weapon.count < 64 },
            on_choose   = proc(game : ^Game) { game.weapon.count += 1 }
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
            description = "Velocity - 20%",
            is_valid    = proc(game : ^Game) -> bool { return game.weapon.speed > 250 },
            on_choose   = proc(game : ^Game) { game.weapon.speed *= 0.8 },
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
            description = "Accuracy - 20%",
            is_valid    = proc(game : ^Game) -> bool { return game.weapon.speed < math.TAU },
            on_choose   = proc(game : ^Game) { game.weapon.spread = math.min(math.TAU, game.weapon.spread + game.weapon.speed * 0.2) },
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
            description = "Kick - 20%",
            on_choose   = proc(game : ^Game) { game.weapon.kick *= 0.8 }
        },
        negative_mod = {
            type        = .WeaponBounce,
            description = "Kick + 10%",
            on_choose   = proc(game : ^Game) { game.weapon.kick *= 1.1 },
        },
    }
}

ModifierPickup :: struct {
    pos         : rl.Vector2,
    vel         : rl.Vector2,
}

Pickups :: struct {
    last_spawn_time : time.Time,
    spawn_delay     : f64,
    selecting_mod   : bool,
    mod_choice_a    : ModifierPair,
    mod_choice_b    : ModifierPair,
    pool            : Pool(128, ModifierPickup)
}

init_pickups :: proc(using pickups : ^Pickups) {
    last_spawn_time = time.now()
    spawn_delay     = SPAWN_DELAY
    pool_init(&pool)
}

unload_pickups :: proc(using pickups : ^Pickups) {
    pool_delete(&pool)
}

tick_pickups :: proc(using game : ^Game, dt : f32) {
    time_since_last_spawn := time.duration_seconds(time.since(pickups.last_spawn_time))
    if time_since_last_spawn >= pickups.spawn_delay {
        pickups.last_spawn_time = time.now()
        spawn_pickup(pickups)
    }

    for i := 0; i < pickups.pool.count; i += 1 {
        pickup  := &pickups.pool.instances[i]
        diff    := player.pos - pickup.pos
        dist    := linalg.length(diff)
        if dist < PICKUP_RADIUS + player.siz / 2 {
            choice_a, a_ok := random_modifier_pair(game)
            choice_b, b_ok := random_modifier_pair(game)

            if a_ok && b_ok {
                pickups.selecting_mod = true
                pickups.mod_choice_a = choice_a
                pickups.mod_choice_b = choice_b     
            }
            else do fmt.printfln("ERROR. Could not find valid mod choices.")

            pool_release(&pickups.pool, i)
            i -= 1
        }
        else if dist < PICKUP_ATTRACTION_RADIUS {
            dir         := diff / dist
            pickup.vel  += dir * PICKUP_ATTRACTION_FORCE * 1 - (dist / PICKUP_ATTRACTION_RADIUS) * dt
        }

        pickup.vel  *= 1 / (1 + PICKUP_DRAG * dt)
        pickup.pos  += pickup.vel * dt
    }
}

draw_pickups :: proc(using pickups : ^Pickups) {
    for pickup in pool.instances[0:pool.count] {
        rl.DrawCircleV(pickup.pos, PICKUP_RADIUS, PICKUP_COLOR)
    }
}

draw_pickup_selection_gui :: proc(using game : ^Game) {
    PANEL_WIDTH     :: 400
    PANEL_HEIGHT    :: 200

    or_text         : cstring = "or"

    choice_pair_a   := game.pickups.mod_choice_a
    choice_pair_b   := game.pickups.mod_choice_b

    window_rect     := centered_rect(PANEL_WIDTH, PANEL_HEIGHT)

    v_split_rects   := v_split_rect(window_rect, percent = 1, bias = 50)
    choices_rect    := v_split_rects[0]
    skip_rect       := v_split_rects[1]

    choices_rect    = top_padded_rect(choices_rect, 20)
    skip_rect       = padded_rect(skip_rect, left_pad = 15, right_pad = 15, bottom_pad = 15)

    or_rect         := rect_centered_rect_label(choices_rect, 30, or_text)
    choice_rects    := h_subdivide_rect(choices_rect, 2)
    uniform_pad_rects(15, &choice_rects)

    rl.GuiPanel(window_rect, "Select Modifier")
    if rl.GuiButton(choice_rects[0], "") {
        pickups.selecting_mod = false
        choice_pair_a.positive_mod.on_choose(game)
        choice_pair_a.negative_mod.on_choose(game)
    }
    if rl.GuiButton(choice_rects[1], "") {
        pickups.selecting_mod = false
        choice_pair_b.positive_mod.on_choose(game)
        choice_pair_b.negative_mod.on_choose(game)
    }

    if rl.GuiButton(skip_rect, "Skip") {
        pickups.selecting_mod = false
    }

    rl.GuiLabel(or_rect, or_text)

    choice_a_rects := v_subdivide_rect(choice_rects[0], 2)
    choice_b_rects := v_subdivide_rect(choice_rects[1], 2)

    rl.DrawRectangleRec(choice_a_rects[0], {0, 255, 0, 50})
    rl.DrawRectangleRec(choice_b_rects[0], {0, 255, 0, 50})

    rl.DrawRectangleRec(choice_a_rects[1], {255, 0, 0, 50})
    rl.DrawRectangleRec(choice_b_rects[1], {255, 0, 0, 50})

    uniform_pad_rects(15, &choice_a_rects)
    uniform_pad_rects(15, &choice_b_rects)

    choice_a_positive_rect := centered_label_rect(choice_a_rects[0], choice_pair_a.positive_mod.description)
    choice_a_negative_rect := centered_label_rect(choice_a_rects[1], choice_pair_a.negative_mod.description)

    choice_b_positive_rect := centered_label_rect(choice_b_rects[0], choice_pair_b.positive_mod.description)
    choice_b_negative_rect := centered_label_rect(choice_b_rects[1], choice_pair_b.negative_mod.description)

    rl.GuiLabel(choice_a_positive_rect, choice_pair_a.positive_mod.description)
    rl.GuiLabel(choice_a_negative_rect, choice_pair_a.negative_mod.description)
    rl.GuiLabel(choice_b_positive_rect, choice_pair_b.positive_mod.description)
    rl.GuiLabel(choice_b_negative_rect, choice_pair_b.negative_mod.description)
}

spawn_pickup :: proc(using pickups : ^Pickups) {
    new_pickup := ModifierPickup {
        pos = random_screen_position(padding = 50),
    }

    pool_add(&pool, new_pickup)
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