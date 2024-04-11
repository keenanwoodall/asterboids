package game

import rl   "vendor:raylib"
import math "core:math"

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

    for !rl.WindowShouldClose() {
       tick_game()
       draw_game()
       rl.DrawFPS(10, 10)
    }
}