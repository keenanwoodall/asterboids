package game

import rl "vendor:raylib"

draw_player_gui :: proc(using player : ^Player) {
    health_bar_width    := player.max_hth
    health_bar_x        := i32((f32(rl.GetScreenWidth()) - health_bar_width) / 2)
    health_bar_y        := rl.GetScreenHeight() - 50
    health_width        := health_bar_width * (player.hth / player.max_hth)
    rl.DrawRectangle(health_bar_x, health_bar_y, i32(health_width), 8, rl.RED)
    rl.DrawRectangleLines(health_bar_x, health_bar_y, i32(health_bar_width), 8, rl.WHITE)
}