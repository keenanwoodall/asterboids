package game

import "core:math/rand"
import rl "vendor:raylib"

Stars :: struct {
    positions   : [1024]rl.Vector2,
    colors      : [1024]rl.Color
}

init_stars :: proc(using stars : ^Stars) {
    for &p in positions do p = random_screen_position()
    for &c in colors do c = rl.ColorFromHSV(20, 0.3, 0.9) * {255, 255, 255, u8(rand.uint32() % 255)}
}

draw_stars :: proc(using stars : ^Stars) {
    for i in 0..<len(positions) do rl.DrawPixelV(positions[i], colors[i])
}