package game

import "core:math/linalg"
import rl "vendor:raylib"

tick_dev_commands :: proc(using game : ^Game) {
    // Skips the current wave and spawns the next one immediately
    // Used when testing to quickly skip to harder waves.
    if rl.IsKeyPressed(.N) {
        enemies.count = 0
        waves.no_enemies_timer = 10000
    }

    // Level up automatically
    if rl.IsKeyPressed(.L) do leveling.xp = get_target_xp(leveling.lvl)

    // Toggle mute music
    if rl.IsKeyPressed(.M) {
        if rl.IsMusicStreamPlaying(audio.music) {
            rl.PauseMusicStream(audio.music)
        } 
        else do rl.ResumeMusicStream(audio.music)
    }

    if rl.IsKeyPressed(.KP_1) do add_archetype_enemy(&enemies, .Small, rl.GetMousePosition(), 0, 0)
    if rl.IsKeyPressed(.KP_2) do add_archetype_enemy(&enemies, .Medium, rl.GetMousePosition(), 0, 0)
    if rl.IsKeyPressed(.KP_3) do add_archetype_enemy(&enemies, .Large, rl.GetMousePosition(), 0, 0)
    if rl.IsKeyPressed(.KP_4) do add_pool(&mines.pool, Mine { pos = rl.GetMousePosition(), hp = 1 })
}