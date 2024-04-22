// This code manages the player leveling state, level up choices and level up gui
// Leveling up consists of applying a "modifier" to the game state.
// A modifier is just a function that is passed the game state and can do whatever it wants to it.
// Level up modifiers mostly modify the Player and PlayerWeapon
package game

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

// The Leveling struct stores the state of the player level and level-up choices
Leveling :: struct {
    xp                  : int,
    lvl                 : int,
    leveling_up         : bool,
    level_up_choice_a   : ModifierPair,
    level_up_choice_b   : ModifierPair,
}

// Init functions are called when the game first starts.
// Here we can assign default values and initialize data.
init_leveling :: proc(using leveling : ^Leveling) {
    xp = 0
    lvl = 1
    leveling_up = false
    level_up_choice_a = {}
    level_up_choice_b = {}
}

// Tick functions are called every frame by the game
tick_leveling :: proc(using game : ^Game) {
    // Check if our current xp is enough to level up
    if leveling.xp >= get_target_xp(leveling.lvl) {
        // If so, level up, reset xp, generate random level up choices
        // and indicate we want to show level up gui if valid level up choices are found.
        leveling.lvl += 1
        leveling.xp = 0
        choice_a, a_ok := random_modifier_pair(game)
        choice_b, b_ok := random_modifier_pair(game, choice_a.positive_mod.type)

        if a_ok && b_ok {
            leveling.leveling_up = true
            leveling.level_up_choice_a = choice_a
            leveling.level_up_choice_b = choice_b

            try_play_sound(&audio, audio.level_up)
        }
        else do fmt.printfln("ERROR. Could not find valid mod choices.")
    }
}

// Draw functions are called at the end of each frame by the game
// However this function will only be called by the game is leveling.leveling_up is true
draw_level_up_gui :: proc(using game : ^Game) {
    PANEL_WIDTH     :: 400
    PANEL_HEIGHT    :: 200

    or_text         : cstring = "or"

    choice_pair_a   := game.leveling.level_up_choice_a
    choice_pair_b   := game.leveling.level_up_choice_b

    window_rect     := centered_rect(PANEL_WIDTH, PANEL_HEIGHT)

    v_split_rects   := v_split_rect(window_rect, percent = 1, bias = 50)
    choices_rect    := v_split_rects[0]
    skip_rect       := v_split_rects[1]

    choices_rect    = top_padded_rect(choices_rect, 20)
    skip_rect       = padded_rect(skip_rect, left_pad = 15, right_pad = 15, bottom_pad = 15)

    or_rect         := rect_centered_rect_label(choices_rect, 30, or_text)
    choice_rects    := h_subdivide_rect(choices_rect, 2)
    uniform_pad_rects(15, &choice_rects)

    choice_left_rects := v_split_rect(choice_rects[0], bias = -5)
    choice_right_rects := v_split_rect(choice_rects[1], bias = -5)

    v_pad_rects(5, &choice_left_rects)
    v_pad_rects(5, &choice_right_rects)

    rl.GuiPanel(window_rect, "Level up!")
    
    EnableGUI :: proc(enable : bool) {
        if enable {
            rl.GuiEnable()
        }
        else {
            rl.GuiDisable()
        }
    }

    EnableGUI(is_mod_valid(choice_pair_a.positive_mod, game))
    if rl.GuiButton(choice_left_rects[0], choice_pair_a.positive_mod.description) {
        leveling.leveling_up = false
        choice_pair_a.positive_mod.on_choose(game)
        try_play_sound(&audio, audio.level_up_conf)
    }
    EnableGUI(is_mod_valid(choice_pair_a.negative_mod, game))
    if rl.GuiButton(choice_left_rects[1], choice_pair_a.negative_mod.description) {
        leveling.leveling_up = false
        choice_pair_a.negative_mod.on_choose(game)
        try_play_sound(&audio, audio.level_up_conf)
    }
    EnableGUI(is_mod_valid(choice_pair_b.positive_mod, game))
    if rl.GuiButton(choice_right_rects[0], choice_pair_b.positive_mod.description) {
        leveling.leveling_up = false
        choice_pair_b.positive_mod.on_choose(game)
        try_play_sound(&audio, audio.level_up_conf)
    }
    EnableGUI(is_mod_valid(choice_pair_b.negative_mod, game))
    if rl.GuiButton(choice_right_rects[1], choice_pair_b.negative_mod.description) {
        leveling.leveling_up = false
        choice_pair_b.negative_mod.on_choose(game)
        try_play_sound(&audio, audio.level_up_conf)
    }
    EnableGUI(true)

    if rl.GuiButton(skip_rect, "Skip") {
        leveling.leveling_up = false
    }

    rl.GuiLabel(or_rect, or_text)

    choice_a_rect := choice_rects[0]
    choice_b_rect := choice_rects[1]
}

// Calculates the required xp for a given level
get_target_xp :: proc(level : int) -> int {
    return int(math.pow(f32(level * 6), 1.1))
}