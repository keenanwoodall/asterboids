package game

import time     "core:time"
import rand     "core:math/rand"
import linalg   "core:math/linalg"
import rl       "vendor:raylib"

ENEMY_SPAWN_PADDING :: 100
ENEMY_WAVE_DURATION :: 7

@(private) last_wave_tick : time.Tick
@(private) wave_idx       := 0

tick_waves :: proc(enemies : ^Enemies) {
    elapsed := time.duration_seconds(time.tick_since(last_wave_tick))

    if elapsed > ENEMY_WAVE_DURATION || rl.IsKeyPressed(.SPACE) {
        wave_idx += 1
        last_wave_tick = time.tick_now()
        spawn_new_wave(enemy_count = wave_idx, enemies = enemies)
    }
}

@(private)
spawn_new_wave :: proc(enemy_count : int, enemies : ^Enemies) {
    Archetype :: struct { size : f32, hp : int, color : rl.Color}
    archetypes := [?]Archetype {
        {ENEMY_SIZE * 0.75, 1, rl.RED},
        {ENEMY_SIZE * 1.0,  2, rl.ORANGE},
        {ENEMY_SIZE * 1.25, 3, rl.SKYBLUE} 
    }

    for i in 0..<enemy_count {
        archetype := rand.choice(archetypes[:])
        new_enemy : Enemy = {
            pos = random_screen_border_position(ENEMY_SPAWN_PADDING * rand.float32_range(1, 2)),
            vel = rl.Vector2Rotate({0, 1}, rand.float32_range(0, linalg.TAU)) * ENEMY_SPEED,
            siz = archetype.size,
            hp  = archetype.hp,
            col = archetype.color
        }

        add_enemy(new_enemy, enemies)
    }
}

@(private)
random_screen_position :: proc(padding : f32 = 0) -> rl.Vector2 {
    w := f32(rl.GetScreenWidth())
    h := f32(rl.GetScreenHeight())
    return {rand.float32_range(padding, w - padding), rand.float32_range(padding, h - padding)}
}

@(private)
random_screen_border_position :: proc(padding : f32 = 0) -> rl.Vector2 {
    w := f32(rl.GetScreenWidth())
    h := f32(rl.GetScreenHeight())
    corners := [4]rl.Vector2  {
        { 0 - padding, 0 - padding }, // bottom left
        { 0 - padding, h + padding }, // top left
        { w + padding, h + padding }, // top right
        { w + padding, 0 - padding }  // bottom right
    }

    corner_idx      := rand.int31_max(4)
    corner_idx_next := (corner_idx + 1) % 4

    return linalg.lerp(corners[corner_idx], corners[corner_idx_next], rand.float32_range(0, 1))
}