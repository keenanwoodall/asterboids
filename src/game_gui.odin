package game

import rl "vendor:raylib"

// Draw functions are called at the end of each frame by the game.
// This function draws the player's health and xp bar
draw_game_gui :: proc(using game : ^Game) {
    health_bar_width    := min(i32(player.max_hth * 2), rl.GetScreenWidth() - 30)
    health_bar_x        := i32((f32(rl.GetScreenWidth()) - f32(health_bar_width)) / 2)
    health_bar_y        := rl.GetScreenHeight() - 50
    health_width        := i32(f32(health_bar_width) * (f32(player.hth) / f32(player.max_hth)))
    rl.DrawRectangle(health_bar_x, health_bar_y, i32(health_width), 8, rl.RED)
    rl.DrawRectangleLines(health_bar_x, health_bar_y, i32(health_bar_width), 8, rl.WHITE)

    target_xp       := get_target_xp(leveling.lvl)
    xp_bar_width    := min(f32(target_xp * 17), f32(rl.GetScreenWidth() - 30))
    xp_bar_x        := i32((f32(rl.GetScreenWidth()) - f32(xp_bar_width)) / 2)
    xp_bar_y        := rl.GetScreenHeight() - 35
    xp_width        := f32(xp_bar_width) * (f32(leveling.xp) / f32(target_xp))
    rl.DrawRectangle(xp_bar_x, xp_bar_y, i32(xp_width), 8, rl.YELLOW)
    rl.DrawRectangleLines(xp_bar_x, xp_bar_y, i32(xp_bar_width), 8, rl.WHITE)
}