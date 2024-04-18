package game

import "core:fmt"
import "core:time"
import "core:math"
import "core:math/rand"
import "core:math/linalg"
import "core:prof/spall"
import "core:strings"
import rl "vendor:raylib"

Game :: struct {
    player          : Player,
    leveling        : Leveling,
    weapon          : Weapon,
    enemies         : Enemies,
    waves           : Waves,
    projectiles     : Projectiles,
    pickups         : Pickups,
    audio           : Audio,
    pixel_particles : ParticleSystem,
    line_particles  : ParticleSystem,
    stars           : Stars,

    game_time            : f64,
    request_restart : bool
}

load_game :: proc(using game : ^Game) {
    request_restart = false
    game_time = 0

    init_player(&player)
    init_leveling(&leveling)
    init_weapon(&weapon)
    init_enemies(&enemies)
    init_waves(&waves)
    init_projectiles(&projectiles)
    init_pickups(&pickups)
    init_stars(&stars)
    load_audio(&audio)
}

unload_game :: proc(using game : ^Game) {
    unload_enemies(&enemies)
    unload_pickups(&pickups)
    unload_audio(&audio)
}

tick_game :: proc(using game : ^Game) {
    dt := rl.GetFrameTime();

    if !leveling.leveling_up {
        // Tick all the things!
        tick_pickups(game, dt)
        tick_leveling(game)
        tick_player(&player, &audio, &pixel_particles, dt)
        tick_player_weapon(&weapon, &player, &audio, &projectiles, &pixel_particles, game_time)
        if player.alive {
            tick_waves(&waves, &enemies, dt, game_time)
        }
        tick_enemies(&enemies, player, dt)
        tick_player_enemy_collision_(&player, &enemies, &line_particles, dt)
        tick_projectiles(&projectiles, dt)
        tick_projectiles_screen_collision(&projectiles)
        tick_projectiles_enemy_collision(&projectiles, &enemies, &pixel_particles, &audio)
        tick_killed_enemies(&enemies, &pickups, &line_particles)
        tick_particles(&pixel_particles, dt)
        tick_particles(&line_particles, dt)    

        game_time += f64(dt)
    }

    tick_audio(&audio)

    request_restart = rl.IsKeyPressed(.R)
}

draw_game :: proc(using game : ^Game) {
    rl.BeginDrawing()
    defer rl.EndDrawing()
    
    rl.ClearBackground(rl.BLACK)

    draw_stars(&stars)
    draw_player(&player)
    draw_enemies(&enemies)
    draw_projectiles(&projectiles)
    draw_pickups(&pickups)
    draw_player_weapon(&player, &weapon)
    draw_particles_as_pixels(&pixel_particles)
    draw_particles_as_lines(&line_particles)
    draw_game_gui(game)
    draw_waves_gui(&waves, game_time)

    if leveling.leveling_up {
        draw_level_up_gui(game)
    }

    rl.DrawFPS(10, 10)
    rl.DrawText(rl.TextFormat("Enemies: %i", enemies.count), 10, 30, 20, rl.WHITE)

    if !player.alive {
        label := strings.clone_to_cstring(
            fmt.tprintf(
                "GAME OVER\n\nWave: %i\nLevel: %i\nEnemies Killed: %i\n\n",
                waves.wave_idx,
                leveling.lvl,
                enemies.kill_count,
            ), 
            context.temp_allocator,
        )
        font_size : i32 = 20
        rect := centered_label_rect(screen_rect(), label, font_size)

        rl.DrawText(label, i32(rect.x), i32(rect.y + rect.height / 2 - f32(font_size) / 2), font_size, rl.RED)
    }
}