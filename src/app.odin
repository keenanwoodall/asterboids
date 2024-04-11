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

    game := new(Game)

    load_game(game)
    defer unload_game(game)

    for !rl.WindowShouldClose() {
        tick_game(game)
        draw_game(game)
        rl.DrawFPS(10, 10)

        if game.request_restart || rl.IsKeyPressed(.R) {
            unload_game(game)
            load_game(game)
        }
    }
}