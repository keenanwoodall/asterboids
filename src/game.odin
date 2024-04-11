package game
import fmt      "core:fmt"
import time     "core:time"
import math     "core:math"
import linalg   "core:math/linalg"
import rl       "vendor:raylib"

player          : ^Player
enemies         : ^Enemies
waves           : ^Waves
projectiles     : ^Projectiles
audio           : ^Audio
particle_system : ^ParticleSystem

load_game :: proc() {
    player          = new(Player)
    enemies         = new(Enemies)
    waves           = new(Waves)
    projectiles     = new(Projectiles)
    audio           = new(Audio)
    particle_system = new(ParticleSystem)

    init_player(player)
    init_player_weapon()
    init_enemies(enemies)
    init_projectiles(projectiles)
    load_audio(audio)
}

unload_game :: proc() {
    unload_enemies(enemies)
    free(player)
    free(enemies)
    free(waves)
    free(projectiles)
    free(particle_system)
    free(audio)
    unload_audio(audio)
}

tick_game :: proc() {
    dt := rl.GetFrameTime();

    tick_player(player, dt)
    tick_player_weapon(player)
    tick_waves(waves, enemies)
    tick_enemies(enemies, player, dt)
    tick_projectiles(projectiles, dt)
    tick_projectiles_collision(projectiles, enemies)
    tick_particles(particle_system, dt)
    tick_audio(audio)
}

draw_game :: proc() {
    rl.BeginDrawing()
    defer rl.EndDrawing()
    
    rl.ClearBackground(rl.BLACK)
    draw_player(player)
    draw_enemies(enemies)
    draw_projectiles(projectiles)
    draw_player_weapon(player)
    draw_particles(particle_system)
}