// This is the entry point into the program

package game

import "base:runtime"
import "core:math"
import "core:mem"
import "core:fmt"
import "core:time"
import rl "vendor:raylib"

main :: proc() {
    // Configure raylib and create a window.
    rl.SetTraceLogLevel(.ALL)
    rl.InitWindow(width = 1920, height = 1080, title = "Asterboids")
    rl.InitAudioDevice()
    rl.SetTargetFPS(144)

    defer {
        rl.CloseAudioDevice()
        rl.CloseWindow()
    }

    // This game struct holds the state of the entire game.
    game := Game{}

    load_game(&game)
    defer unload_game(&game)

    // Here is the main game loop.
    for !rl.WindowShouldClose() {
        // Odin has an allocators built into the language.
        // As the name implies, allocators let us allocate and free memory.
        // There are different allocators that manage memory in different ways.
        // Odin provides a temporary allocator which we use for allocating memory
        // that doesn't need to live for more than a frame.
        // At the end of each frame we want to free that temporary memory:
        defer free_all(context.temp_allocator)

        // "tick" the game forward in time.
        tick_game(&game)
        // draw the game.
        draw_game(&game)

        // If the game wants to restart, reload it
        if game.request_restart {
            unload_game(&game)
            load_game(&game)
        }
    }
}