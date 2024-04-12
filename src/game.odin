package game

import fmt      "core:fmt"
import time     "core:time"
import math     "core:math"
import linalg   "core:math/linalg"
import rl       "vendor:raylib"

Game :: struct {
    player          : ^Player,
    enemies         : ^Enemies,
    waves           : ^Waves,
    projectiles     : ^Projectiles,
    audio           : ^Audio,
    pixel_particles : ^ParticleSystem,
    line_particles  : ^ParticleSystem,

    request_restart : bool
}

load_game :: proc(using game : ^Game) {
    player          = new(Player)
    enemies         = new(Enemies)
    waves           = new(Waves)
    projectiles     = new(Projectiles)
    audio           = new(Audio)
    pixel_particles = new(ParticleSystem)
    line_particles  = new(ParticleSystem)

    request_restart = false

    init_player(player)
    init_player_weapon()
    init_enemies(enemies)
    init_projectiles(projectiles)
    load_audio(audio)
}

unload_game :: proc(using game : ^Game) {
    unload_enemies(enemies)
    free(player)
    free(enemies)
    free(waves)
    free(projectiles)
    free(pixel_particles)
    free(line_particles)
    free(audio)
    unload_audio(audio)
}

tick_game :: proc(using game : ^Game) {
    dt := rl.GetFrameTime();

    tick_player(player, audio, pixel_particles, dt)
    tick_player_weapon(player, audio, projectiles, pixel_particles)

    tick_waves(waves, enemies)
    tick_enemies(enemies, player, dt)

    tick_player_enemy_collision_(player, enemies, line_particles, dt)

    tick_projectiles(projectiles, dt)
    tick_projectiles_screen_collision(projectiles)
    tick_projectiles_enemy_collision(projectiles, enemies, pixel_particles, audio)

    release_killed_enemies(enemies, line_particles)

    tick_particles(pixel_particles, dt)
    tick_particles(line_particles, dt)

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
    draw_player_weapon(player)
    draw_particles_as_pixels(pixel_particles)
    draw_particles_as_lines(line_particles)

    rl.DrawFPS(10, 10)
}