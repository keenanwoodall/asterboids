package game

import "base:runtime"
import "core:math"
import "core:mem"
import "core:fmt"
import "core:time"
import rl "vendor:raylib"

main :: proc() {
    rl.SetTraceLogLevel(.ERROR)
    rl.SetConfigFlags(rl.ConfigFlags { rl.ConfigFlag.MSAA_4X_HINT })
    rl.InitWindow(width = 1920, height = 1080, title = "Asterboids")
    rl.InitAudioDevice()
    rl.SetTargetFPS(120)

    defer {
        rl.CloseAudioDevice()
        rl.CloseWindow()
    }

    game := Game{}

    load_game(&game)
    defer unload_game(&game)

    for !rl.WindowShouldClose() {
        defer free_all(context.temp_allocator)
        @(static) frame_number := 0
        defer frame_number += 1
        scope_name := fmt.tprintf("frame %v", frame_number)

        tick_game(&game)
        draw_game(&game)

        if game.request_restart {
            unload_game(&game)
            load_game(&game)
        }
    }
}