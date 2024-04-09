package game

import math "core:math"
import rand "core:math/rand"
import rl   "vendor:raylib"

MAX_PARTICLES :: 1024

Particle :: struct {
    pos : rl.Vector2,
    vel : rl.Vector2,
    col : rl.Color,
    lif : f32,
    drg : f32
}

ParticleSystem :: struct {
    count     : int,
    particles : [MAX_PARTICLES]Particle
}

tick_particles :: proc(using particle_system : ^ParticleSystem, dt: f32) {
    for i := 0; i < count; i += 1 {
        using particle := particles[i]
        particle.vel *= 1 / (1 + drg * dt)
        particle.pos += particle.vel * dt
        particle.lif -= dt
        if particle.lif <= 0 {
            release_particle(i, particle_system)
            i -= 1
        }
        else {
            particles[i] = particle
            rl.DrawPixelV(pos, col)
        }
    }
}

draw_particles :: proc(using particle_system : ^ParticleSystem) {
    rl.rlSetLineWidth(2)
    for i in 0..<count {
        using particle := particles[i]
        rl.DrawPixelV(pos, col)
    }
}

add_particle :: proc(newParticle : Particle, using particle_system : ^ParticleSystem) {
    if count == MAX_PARTICLES {
        return
    }
    particles[count] = newParticle
    count += 1
}

release_particle :: proc(index : int, using particle_system : ^ParticleSystem) {
    particles[index] = particles[count - 1]
    count -= 1
}

spawn_particles_burst :: proc(
    particle_system : ^ParticleSystem, 
    center          : rl.Vector2, 
    count           : int, 
    min_speed       : f32,
    max_speed       : f32,
    min_lifetime    : f32,
    max_lifetime    : f32,
    color           : rl.Color,
    start_angle     : f32 = 0.0,
    end_angle       : f32 = math.TAU,
    drag            : f32 = 0) {
        
    for i in 0..<count {
        speed           := rand.float32_range(min_speed, max_speed)
        angle           := rand.float32_range(start_angle, end_angle)
        new_particle    := Particle {
            pos = center,
            vel = rl.Vector2Rotate({0, speed}, angle),
            col = color,
            lif = rand.float32_range(min_lifetime, max_lifetime),
            drg = drag
        }
        add_particle(new_particle, particle_system)
    }
}

spawn_particles_direction :: proc(
    particle_system : ^ParticleSystem, 
    center          : rl.Vector2, 
    direction       : rl.Vector2,
    count           : int, 
    min_speed       : f32,
    max_speed       : f32,
    min_lifetime    : f32,
    max_lifetime    : f32,
    color           : rl.Color,
    angle           : f32 = 0,
    drag            : f32 = 0) {
        
    for i in 0..<count {
        speed           := rand.float32_range(min_speed, max_speed)
        new_particle    := Particle {
            pos = center,
            vel = rl.Vector2Rotate(direction * speed, rand.float32_range(-angle, angle)),
            col = color,
            lif = rand.float32_range(min_lifetime, max_lifetime),
            drg = drag
        }
        add_particle(new_particle, particle_system)
    }
}