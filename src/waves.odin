package game

import "core:fmt"
import "core:time"
import "core:math/rand"
import "core:math/linalg"
import rl "vendor:raylib"

ENEMY_SPAWN_PADDING :: 100
ENEMY_WAVE_DURATION :: 10

Waves :: struct {
    last_wave_time   : time.Time,
    wave_idx         : int,
    spawn_event_idx  : int,
    group_rand       : rand.Rand,
}

init_waves :: proc(using waves : ^Waves) {
    spawn_event_idx = 0
    wave_idx        = 0
    last_wave_time  = {}
    group_rand      = rand.create(12345)
}

tick_waves :: proc(waves : ^Waves, enemies : ^Enemies) {
    elapsed := time.duration_seconds(time.since(waves.last_wave_time))

    if elapsed > ENEMY_WAVE_DURATION {
        waves.wave_idx += 1
        waves.last_wave_time = time.now()
        spawn_new_wave(waves.wave_idx * 2, waves, enemies, OffscreenClusterSpawner)
    }
}

spawn_new_wave :: proc(enemy_count : int, waves : ^Waves, enemies : ^Enemies, spawner_proc : proc(i, count:int, waves: ^Waves)->rl.Vector2) {
    Archetype :: struct { size : f32, hp : int, color : rl.Color}
    archetypes := [?]Archetype {
        {ENEMY_SIZE * 1.0, 1, rl.RED},
        {ENEMY_SIZE * 1.5, 2, rl.ORANGE},
        {ENEMY_SIZE * 2.0, 3, rl.SKYBLUE} 
    }

    waves.spawn_event_idx += 1

    for i in 0..<enemy_count * 2 {
        archetype : Archetype
        if x := rand.float32_range(0, 10); x < 7 {
            archetype = archetypes[0]
        }
        else if x < 9 {
            archetype = archetypes[1]
        }
        else {
            archetype = archetypes[2]
        }

        new_enemy : Enemy = {
            pos = spawner_proc(i, enemy_count, waves),
            vel = rl.Vector2Rotate({0, 1}, rand.float32_range(0, linalg.TAU)) * ENEMY_SPEED,
            siz = archetype.size,
            hp  = archetype.hp,
            col = archetype.color
        }

        add_enemy(new_enemy, enemies)
    }
}

random_screen_position :: proc(padding : f32 = 0, r : ^rand.Rand = nil) -> rl.Vector2 {
    w := f32(rl.GetScreenWidth())
    h := f32(rl.GetScreenHeight())
    return {rand.float32_range(padding, w - padding, r), rand.float32_range(padding, h - padding, r)}
}

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

OffscreenSpawner        :: proc(i, ct:int, waves: ^Waves) -> rl.Vector2 { return random_screen_border_position(ENEMY_SPAWN_PADDING * rand.float32_range(1, 2)) }
OnScreenSpawner         :: proc(i, ct:int, waves: ^Waves) -> rl.Vector2 { return random_screen_position() }
OffscreenClusterSpawner :: proc(i, ct:int, waves: ^Waves) -> rl.Vector2 {
    rand.init(&waves.group_rand, u64(waves.spawn_event_idx))

    padding :f32= ENEMY_SPAWN_PADDING * rand.float32_range(1, 2)
    origin  := random_screen_border_position(padding, &waves.group_rand)
    origin  += {
        rand.float32_range(-ENEMY_SPAWN_PADDING, ENEMY_SPAWN_PADDING), 
        rand.float32_range(-ENEMY_SPAWN_PADDING, ENEMY_SPAWN_PADDING)
    }

    return origin
}