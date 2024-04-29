package game

import "core:fmt"
import "core:strings"
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

    if !player.alive {
        label := strings.clone_to_cstring(
            fmt.tprintf(
                "GAME OVER\n\nWave: %i\nLevel: %i\nEnemies Killed: %i\n\n",
                waves.wave_idx,
                leveling.lvl,
                enemies.kill_count,
            ), 
            context.temp_allocator,
        )
        font_size : i32 = 20
        rect := centered_label_rect(screen_rect(), label, font_size)

        rl.DrawText(label, i32(rect.x), i32(rect.y + rect.height / 2 - f32(font_size) / 2), font_size, rl.RED)
    }
}