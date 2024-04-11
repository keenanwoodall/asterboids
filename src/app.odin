package game

import math "core:math"
import mem  "core:mem"
import fmt  "core:fmt"
import rl   "vendor:raylib"

main :: proc() {
    rl.SetTraceLogLevel(.ERROR)
    rl.SetConfigFlags(rl.ConfigFlags { rl.ConfigFlag.MSAA_4X_HINT })
    rl.InitWindow(width = 1920, height = 1080, title = "Shooter")
    rl.InitAudioDevice()

    defer {
        rl.CloseAudioDevice()
        rl.CloseWindow()
    }

    load_game()
    defer unload_game()

    for !rl.WindowShouldClose() {
        tick_game()
        draw_game()
        rl.DrawFPS(10, 10)

        if rl.IsKeyPressed(.R) {
            unload_game()
            load_game()
        }
    }
}