package game

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

Leveling :: struct {
    xp                  : int,
    lvl                 : int,
    leveling_up         : bool,
    level_up_choice_a   : ModifierPair,
    level_up_choice_b   : ModifierPair,
}

init_leveling :: proc(using leveling : ^Leveling) {
    xp = 0
    lvl = 1
    leveling_up = false
    level_up_choice_a = {}
    level_up_choice_b = {}
}

tick_leveling :: proc(using game : ^Game) {
    if leveling.xp >= get_target_xp(leveling.lvl) {
        leveling.lvl += 1
        leveling.xp = 0
        choice_a, a_ok := random_modifier_pair(game)
        choice_b, b_ok := random_modifier_pair(game)

        if a_ok && b_ok {
            leveling.leveling_up = true
            leveling.level_up_choice_a = choice_a
            leveling.level_up_choice_b = choice_b     

            try_play_sound(&audio, audio.level_up)
        }
        else do fmt.printfln("ERROR. Could not find valid mod choices.")
    }
}

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

    rl.GuiPanel(window_rect, "Level up!")
    if rl.GuiButton(choice_rects[0], "") {
        leveling.leveling_up = false
        choice_pair_a.positive_mod.on_choose(game)
        //choice_pair_a.negative_mod.on_choose(game)
        try_play_sound(&audio, audio.level_up_conf)
    }
    if rl.GuiButton(choice_rects[1], "") {
        leveling.leveling_up = false
        choice_pair_b.positive_mod.on_choose(game)
        //choice_pair_b.negative_mod.on_choose(game)
        try_play_sound(&audio, audio.level_up_conf)
    }

    if rl.GuiButton(skip_rect, "Skip") {
        leveling.leveling_up = false
    }

    rl.GuiLabel(or_rect, or_text)

    //choice_a_rects := v_subdivide_rect(choice_rects[0], 2)
    //choice_b_rects := v_subdivide_rect(choice_rects[1], 2)

    // rl.DrawRectangleRec(choice_a_rects[0], {0, 255, 0, 50})
    // rl.DrawRectangleRec(choice_b_rects[0], {0, 255, 0, 50})

    // rl.DrawRectangleRec(choice_a_rects[1], {255, 0, 0, 50})
    // rl.DrawRectangleRec(choice_b_rects[1], {255, 0, 0, 50})

    choice_a_rect := choice_rects[0]
    choice_b_rect := choice_rects[1]

    rl.DrawRectangleRec(choice_a_rect, {0, 255, 0, 50})
    rl.DrawRectangleRec(choice_b_rect, {0, 255, 0, 50})

    choice_a_rect = uniform_padded_rect(choice_a_rect, 15)
    choice_b_rect = uniform_padded_rect(choice_b_rect, 15)

    choice_a_positive_rect := centered_label_rect(choice_a_rect, choice_pair_a.positive_mod.description)
    //choice_a_positive_rect := centered_label_rect(choice_a_rects[0], choice_pair_a.positive_mod.description)
    //choice_a_negative_rect := centered_label_rect(choice_a_rects[1], choice_pair_a.negative_mod.description)

    choice_b_positive_rect := centered_label_rect(choice_b_rect, choice_pair_b.positive_mod.description)
    //choice_b_positive_rect := centered_label_rect(choice_b_rects[0], choice_pair_b.positive_mod.description)
    //choice_b_negative_rect := centered_label_rect(choice_b_rects[1], choice_pair_b.negative_mod.description)

    rl.GuiLabel(choice_a_positive_rect, choice_pair_a.positive_mod.description)
    //rl.GuiLabel(choice_a_negative_rect, choice_pair_a.negative_mod.description)
    rl.GuiLabel(choice_b_positive_rect, choice_pair_b.positive_mod.description)
    //rl.GuiLabel(choice_b_negative_rect, choice_pair_b.negative_mod.description)
}

get_target_xp :: proc(level : int) -> int {
    return int(math.pow(f32(level * 6), 1.1))
}