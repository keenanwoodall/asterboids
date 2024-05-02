// This code generates and draws random stars as pixels.

package game

import "core:math/rand"
import rl "vendor:raylib"

// The stars struct stores an array of positions and colors.
// These arrays should always have the same length.
Stars :: struct {
    positions   : []rl.Vector2,
    colors      : []rl.Color
}

// Init functions are called when the game first starts.
// Here we simply set each star position to a random point on screen
// and give each star a color with a random opacity
init_stars :: proc(using stars : ^Stars) {
    positions   = make([]rl.Vector2, 1024)
    colors      = make([]rl.Color, 1024)

    for &p in positions do p = random_screen_position()
    for &c in colors do c = rl.ColorFromHSV(20, 0.3, 0.9) * {255, 255, 255, u8(rand.uint32() % 255)}
}

unload_stars :: proc(using stars : ^Stars) {
    delete(positions)
    delete(colors)
}

// Draw functions are called at the end of each frame by the game.
// This function draws a colored pixel at each position in the Stars struct.
draw_stars :: proc(using stars : ^Stars) {
    for i in 0..<len(positions) do rl.DrawPixelV(positions[i], colors[i])
}