package game

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:math/linalg"
import rl "vendor:raylib"

Tutorial :: struct {
    complete : bool
}

init_tutorial :: proc(using tut : ^Tutorial) {
    complete = false
}

start_tutorial :: proc(using game : ^Game) {
    tutorial_enemy : Enemy = {
        pos     = rl.Vector2 { f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight()) } / 2.0 + rl.Vector2 { 0, - 200 },
        vel     = 0,
        siz     = ENEMY_SIZE,
        hp      = 1,
        dmg     = 0,
        loot    = 0,
        col     = rl.RED,
        id      = 0,
    }

    // Add the new enemy to the pool of enemies
    add_enemy(tutorial_enemy, &enemies)
}

tick_tutorial :: proc(using game : ^Game) {
    if enemies.count == 0 do tutorial.complete = true
}

draw_tutorial :: proc(using game : ^Game) {
    INSTRUCTIONS :: "A\t\t\t\tTurn Left\n\nD\t\t\t\tTurn Right\n\nW\t\t\t\tActivate Thruster\n\nLMB\t\t\tShoot\n\n\n\n\nKill Enemy To Start Game"
    rect := centered_label_rect(centered_rect(200, 200), INSTRUCTIONS, 20)
    rl.DrawText(INSTRUCTIONS, i32(rect.x), i32(rect.y) + 300, 20, rl.WHITE)
}