package game
import fmt      "core:fmt"
import time     "core:time"
import math     "core:math"
import linalg   "core:math/linalg"
import rl       "vendor:raylib"

player          : ^Player
enemies         : ^Enemies
projectiles     : ^Projectiles
sounds          : ^Sounds
particle_system : ^ParticleSystem

load_game :: proc() {
    player          = new(Player)
    enemies         = new(Enemies)
    projectiles     = new(Projectiles)
    sounds          = new(Sounds)
    particle_system = new(ParticleSystem)

    init_player(player)
    init_enemies(enemies)
    init_projectiles(projectiles)
    load_sounds(sounds)
}

unload_game :: proc() {
    unload_enemies(enemies)
    free(player)
    free(enemies)
    free(projectiles)
    free(particle_system)
    free(sounds)
    unload_sounds(sounds)
}

tick_game :: proc() {
    dt := rl.GetFrameTime();

    //if rl.IsKeyDown(.LEFT_SHIFT) do dt *= 0.05

    tick_player(player, dt)
    tick_player_weapon(player)
    tick_waves(enemies)
    tick_enemies(enemies, player, dt)
    tick_projectiles(projectiles, dt)
    tick_projectiles_collision(projectiles, enemies)
    tick_particles(particle_system, dt)
    tick_sounds(sounds)
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