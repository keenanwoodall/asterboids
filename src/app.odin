package game

import "base:runtime"
import "core:math"
import "core:mem"
import "core:fmt"
import "core:time"
import "core:prof/spall"
import rl "vendor:raylib"


spall_ctx : spall.Context
spall_buffer : spall.Buffer

main :: proc() {
    spall_ctx = spall.context_create("trace_test.spall")
	defer spall.context_destroy(&spall_ctx)

    spall_buffer_data := make([]u8, spall.BUFFER_DEFAULT_SIZE)
    spall_buffer := spall.buffer_create(spall_buffer_data)
    defer spall.buffer_destroy(&spall_ctx, &spall_buffer)

    rl.SetTraceLogLevel(.ERROR)
    rl.SetConfigFlags(rl.ConfigFlags { rl.ConfigFlag.MSAA_4X_HINT })
    rl.InitWindow(width = 1920, height = 1080, title = "Asterboids")
    rl.InitAudioDevice()

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
        //spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, scope_name)

        tick_game(&game)
        draw_game(&game)

        if game.request_restart {
            unload_game(&game)
            load_game(&game)
        }
    }
}