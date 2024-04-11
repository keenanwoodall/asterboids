package game

import time     "core:time"
import rand     "core:math/rand"
import linalg   "core:math/linalg"
import rl       "vendor:raylib"

ENEMY_SPAWN_PADDING :: 100
ENEMY_WAVE_DURATION :: 7

BorderSpawner         :: proc(i, ct, evt_idx:int) -> rl.Vector2 { return random_screen_border_position(ENEMY_SPAWN_PADDING * rand.float32_range(1, 2)) }
FillSpawner           :: proc(i, ct, evt_idx:int) -> rl.Vector2 { return random_screen_position() }
BorderGroupSpawner    :: proc(i, ct, evt_idx:int) -> rl.Vector2 {
    rand.init(&group_rand, u64(evt_idx))

    padding :f32= ENEMY_SPAWN_PADDING * rand.float32_range(1, 2)
    origin  := random_screen_border_position(padding, &group_rand)
    origin  += {
        rand.float32_range(-ENEMY_SPAWN_PADDING, ENEMY_SPAWN_PADDING), 
        rand.float32_range(-ENEMY_SPAWN_PADDING, ENEMY_SPAWN_PADDING)
    }

    return origin
}

@(private) last_wave_tick   : time.Tick
@(private) wave_idx         :int= 0
@(private) spawn_event_idx  :int= 0
@(private) group_rand       := rand.create(12345)

tick_waves :: proc(enemies : ^Enemies) {
    elapsed := time.duration_seconds(time.tick_since(last_wave_tick))

    if elapsed > ENEMY_WAVE_DURATION /*|| rl.IsKeyPressed(.SPACE)*/ {
        wave_idx += 1
        last_wave_tick = time.tick_now()
        spawn_new_wave(enemy_count = wave_idx, enemies = enemies, spawner_proc = BorderGroupSpawner)
    }

    if rl.IsKeyPressed(.SPACE) {
        spawn_new_wave(enemy_count = 100, enemies = enemies, spawner_proc = BorderGroupSpawner)
    }
}

@(private)
spawn_new_wave :: proc(enemy_count : int, enemies : ^Enemies, spawner_proc : proc(i, count, idx:int)->rl.Vector2) {
    Archetype :: struct { size : f32, hp : int, color : rl.Color}
    archetypes := [?]Archetype {
        {ENEMY_SIZE * 1.0, 1, rl.RED},
        {ENEMY_SIZE * 1.5, 2, rl.ORANGE},
        {ENEMY_SIZE * 2.0, 3, rl.SKYBLUE} 
    }

    spawn_event_idx += 1

    for i in 0..<enemy_count * 2 {
        archetype := rand.choice(archetypes[:])
        new_enemy : Enemy = {
            pos = spawner_proc(i, enemy_count, spawn_event_idx),
            vel = rl.Vector2Rotate({0, 1}, rand.float32_range(0, linalg.TAU)) * ENEMY_SPEED,
            siz = archetype.size,
            hp  = archetype.hp,
            col = archetype.color
        }

        add_enemy(new_enemy, enemies)
    }
}

@(private)
random_screen_position :: proc(padding : f32 = 0, r : ^rand.Rand = nil) -> rl.Vector2 {
    w := f32(rl.GetScreenWidth())
    h := f32(rl.GetScreenHeight())
    return {rand.float32_range(padding, w - padding, r), rand.float32_range(padding, h - padding, r)}
}


@(private)
random_screen_border_position :: proc(padding : f32 = 0, r : ^rand.Rand = nil) -> rl.Vector2 {
    w := f32(rl.GetScreenWidth())
    h := f32(rl.GetScreenHeight())
    corners := [4]rl.Vector2  {
        { 0 - padding, 0 - padding }, // bottom left
        { 0 - padding, h + padding }, // top left
        { w + padding, h + padding }, // top right
        { w + padding, 0 - padding }  // bottom right
    }

    corner_idx      := rand.int31_max(4, r)
    corner_idx_next := (corner_idx + 1) % 4

    return linalg.lerp(corners[corner_idx], corners[corner_idx_next], rand.float32_range(0, 1, r))
}