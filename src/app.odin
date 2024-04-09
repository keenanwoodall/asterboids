package game

import rl   "vendor:raylib"
import math "core:math"

main :: proc() {
    rl.SetTraceLogLevel(.ERROR)
    rl.SetConfigFlags(rl.ConfigFlags { rl.ConfigFlag.MSAA_4X_HINT })
    rl.InitWindow(width = 1280, height = 720, title = "Shooter")
    rl.InitAudioDevice()

    load_game()

    for !rl.WindowShouldClose() {
       tick_game()
       draw_game()
    }

    rl.CloseAudioDevice()
    rl.CloseWindow()
}