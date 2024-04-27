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
    xp                      : int,
    lvl                     : int,
    leveling_up             : bool,
    level_up_choices        : [3]^Modifier,
    wait_for_mouse_up       : bool,         // Raylib does not take into account if your mouse was pressed off of the button your release over.
                                            // We'll use this flag to prevent accidental button clicks when releasing the mouse over a level up choice
}

// Init functions are called when the game first starts.
// Here we can assign default values and initialize data.
init_leveling :: proc(using leveling : ^Leveling) {
    xp = 0
    lvl = 1
    leveling_up = false
}

// Tick functions are called every frame by the game
tick_leveling :: proc(using game : ^Game) {
    // Level up automatically when debug key is pressed for testing
    if rl.IsKeyPressed(.L) do leveling.xp = get_target_xp(leveling.lvl)

    // Check if our current xp is enough to level up
    if leveling.xp >= get_target_xp(leveling.lvl) {
        // If so, level up, reset xp, generate random level up choices
        // and indicate we want to show level up gui if valid level up choices are found.
        leveling.lvl += 1
        leveling.xp = 0
        
        choice_a, a_ok := random_modifier(game)
        choice_b, b_ok := random_modifier(game, choice_a.type)
        choice_c, c_ok := random_modifier(game, choice_a.type, choice_b.type)

        if a_ok && b_ok && c_ok {
            leveling.leveling_up = true
            leveling.wait_for_mouse_up = rl.IsMouseButtonDown(.LEFT)
            leveling.level_up_choices[0] = choice_a
            leveling.level_up_choices[1] = choice_b
            leveling.level_up_choices[2] = choice_c

            try_play_sound(&audio, audio.level_up)
        }
        else do fmt.printfln("ERROR. Could not find valid mod choices.")
    }
}

// Draw functions are called at the end of each frame by the game
// However this function will only be called by the game is leveling.leveling_up is true
draw_level_up_gui :: proc(using game : ^Game) {
    PANEL_WIDTH     :: 450
    PANEL_HEIGHT    :: 150

    // Get the two level up choices that we need to present to the player.
    choice_a   := game.leveling.level_up_choices[0]
    choice_b   := game.leveling.level_up_choices[1]
    choice_c   := game.leveling.level_up_choices[2]

    // Create a rect in the center of the screen for the level up panel. 
    window_rect     := centered_rect(PANEL_WIDTH, PANEL_HEIGHT)

    // Split the panel vertically. The top rect will be used to display the level-up choices
    // and the bottom rect will show a "Skip" button, should the player not like their options.

    // The rect which contains the level-up choices needs padding to accomodate for the top bar of the panel
    choices_rect    := top_padded_rect(window_rect, 20)
    // Additional padding so it isn't flush with the panel
    choices_rect     = uniform_padded_rect(choices_rect, 15)

    // Split the choices rect in to thirds
    choice_rects    := h_subdivide_rect(choices_rect, 3)

    // Add inner padding between the choices
    choice_rects[0]  = padded_rect(choice_rects[0], right_pad = 8)
    choice_rects[1]  = padded_rect(choice_rects[1], left_pad = 8, right_pad = 8)
    choice_rects[2]  = padded_rect(choice_rects[2], left_pad = 8)

    // Now we have the necessary rects to draw the ui.

    rl.GuiPanel(window_rect, "Level up!")
    
    // Little utility function to more easily enable/disable ui interactability.
    EnableGUI :: proc(enable : bool) {
        if enable {
            rl.GuiEnable()
        }
        else {
            rl.GuiDisable()
        }
    }

    // Draw each level up choice, disabling the ui if the level up choice is not valid.
    // Level up choices are just Modifiers. See the modifiers.odin file for more info.

    if choice_a.single_use do rl.DrawRectangleRec(uniform_padded_rect(choice_rects[0], -2), rl.GOLD)

    rl.GuiSetTooltip(choice_a.description)   
    if rl.GuiButton(choice_rects[0], get_temp_mod_display_name(choice_a^)) && !leveling.wait_for_mouse_up {
        leveling.leveling_up = false
        use_mod(choice_a, game)
        try_play_sound(&audio, audio.level_up_conf)
    }

    if choice_b.single_use do rl.DrawRectangleRec(uniform_padded_rect(choice_rects[1], -2), rl.GOLD)
    
    rl.GuiSetTooltip(choice_b.description)
    if rl.GuiButton(choice_rects[1], get_temp_mod_display_name(choice_b^)) && !leveling.wait_for_mouse_up {
        leveling.leveling_up = false
        use_mod(choice_b, game)
        try_play_sound(&audio, audio.level_up_conf)
    }

    if choice_c.single_use do rl.DrawRectangleRec(uniform_padded_rect(choice_rects[2], -2), rl.GOLD)

    rl.GuiSetTooltip(choice_c.description)
    if rl.GuiButton(choice_rects[2], get_temp_mod_display_name(choice_c^)) && !leveling.wait_for_mouse_up {
        leveling.leveling_up = false
        use_mod(choice_c, game)
        try_play_sound(&audio, audio.level_up_conf)
    }

    rl.GuiSetTooltip(nil)

    if leveling.wait_for_mouse_up && rl.IsMouseButtonReleased(.LEFT) {
        leveling.wait_for_mouse_up = false
    }
}

// Calculates the required xp for a given level
get_target_xp :: proc(level : int) -> int {
    return int(math.pow(f32(level * 6), 1.1))
}

get_temp_mod_display_name :: proc(mod : Modifier) -> cstring {
    if mod.single_use || mod.use_count == 0 {
        return mod.name
    }

    return rl.TextFormat("%s (%i)", mod.name, mod.use_count)
}