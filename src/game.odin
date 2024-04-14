package game

import "core:fmt"
import "core:time"
import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"

Game :: struct {
    player          : ^Player,
    weapon          : ^Weapon,
    enemies         : ^Enemies,
    waves           : ^Waves,
    projectiles     : ^Projectiles,
    pickups         : ^Pickups,
    audio           : ^Audio,
    pixel_particles : ^ParticleSystem,
    line_particles  : ^ParticleSystem,

    request_restart : bool
}

load_game :: proc(using game : ^Game) {
    player          = new(Player)
    weapon          = new(Weapon)
    enemies         = new(Enemies)
    waves           = new(Waves)
    projectiles     = new(Projectiles)
    pickups         = new(Pickups)
    audio           = new(Audio)
    pixel_particles = new(ParticleSystem)
    line_particles  = new(ParticleSystem)

    request_restart = false

    init_player(player)
    init_weapon(weapon)
    init_enemies(enemies)
    init_projectiles(projectiles)
    init_pickups(pickups)
    load_audio(audio)
}

unload_game :: proc(using game : ^Game) {
    unload_enemies(enemies)
    unload_pickups(pickups)
    unload_audio(audio)
    free(player)
    free(weapon)
    free(enemies)
    free(waves)
    free(projectiles)
    free(pickups)
    free(pixel_particles)
    free(line_particles)
    free(audio)
}

tick_game :: proc(using game : ^Game) {
    dt := rl.GetFrameTime();

    if !pickups.selecting_mod {
        // Tick all the things!
        tick_pickups(game, dt)
        tick_player(player, audio, pixel_particles, dt)
        tick_player_weapon(weapon, player, audio, projectiles, pixel_particles)
        tick_waves(waves, enemies)
        tick_enemies(enemies, player, dt)
        tick_player_enemy_collision_(player, enemies, line_particles, dt)
        tick_projectiles(projectiles, dt)
        tick_projectiles_screen_collision(projectiles)
        tick_projectiles_enemy_collision(projectiles, enemies, pixel_particles, audio)
        tick_killed_enemies(enemies, line_particles)
        tick_particles(pixel_particles, dt)
        tick_particles(line_particles, dt)    
    }

    tick_audio(audio)

    request_restart = rl.IsKeyPressed(.R)
}

draw_game :: proc(using game : ^Game) {
    rl.BeginDrawing()
    defer rl.EndDrawing()
    
    rl.ClearBackground(rl.BLACK)

    draw_player(player)
    draw_enemies(enemies)
    draw_projectiles(projectiles)
    draw_pickups(pickups)
    draw_player_weapon(player)
    draw_particles_as_pixels(pixel_particles)
    draw_particles_as_lines(line_particles)

    draw_player_gui(player)

    if pickups.selecting_mod {
        draw_pickup_selection_gui(game)
    }
}