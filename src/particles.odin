package game

import fmt      "core:fmt"
import math     "core:math"
import linalg   "core:math/linalg"
import rand     "core:math/rand"
import rl       "vendor:raylib"

MAX_PARTICLES :: 1024

Particle :: struct {
    tim : f32,          // time     (how long it's been alive)
    dur : f32,          // lifetime (duration)
    pos : rl.Vector2,   // position
    siz : rl.Vector2,   // size
    col : rl.Color,     // color
    vel : rl.Vector2,   // velocity
    rot : f32,          // rotation (radians)
    trq : f32,          // torque
    vdg : f32,          // velocity drag
    adg : f32           // angular drag
}

ParticleSystem :: struct {
    count     : int,
    particles : [MAX_PARTICLES]Particle
}

tick_particles :: proc(using particle_system : ^ParticleSystem, dt: f32) {
    for i := 0; i < count; i += 1 {
        using particle := particles[i]
        vel *= 1 / (1 + vdg * dt)
        trq *= 1 / (1 + adg * dt)
        pos += particle.vel * dt
        rot += particle.trq * dt
        tim += dt
        if tim >= dur {
            release_particle(i, particle_system)
            i -= 1
        }
        else {
            particles[i] = particle
        }
    }
}

draw_particles_as_pixels :: proc(using particle_system : ^ParticleSystem) {
    for p in particles[0:count] {
        rl.DrawPixelV(p.pos, p.col)
    }
}

draw_particles_as_lines :: proc(using particle_system : ^ParticleSystem) {
    rl.rlSetLineWidth(3)
    for p in particles[0:count] {
        alpha := math.pow((1 - p.tim / p.dur), .5)
        p1 := p.pos
        p2 := p.pos + rl.Vector2Rotate({0, 1} * p.siz.y, p.rot) * alpha
        rl.DrawLineV(p1, p2, p.col * {1,1,1, u8((1 - alpha) * 255)})
    }
}

add_particle :: proc(newParticle : Particle, using particle_system : ^ParticleSystem) {
    if count == MAX_PARTICLES do return
    particles[count] = newParticle
    count += 1
}

release_particle :: proc(index : int, using particle_system : ^ParticleSystem) {
    particles[index] = particles[count - 1]
    count -= 1
}

spawn_particles_triangle_segments :: proc(
    particle_system     : ^ParticleSystem, 
    triangle            : [3]rl.Vector2,
    color               : rl.Color,
    velocity            : rl.Vector2,
    min_lifetime, 
    max_lifetime        : f32,
    min_force, 
    max_force           : f32,
    min_torque, 
    max_torque          : f32,
    drag                : f32 = 0,
    angular_drag        : f32 = 0,) {
        
    center : rl.Vector2
    for p in triangle do center += p
    center /= 3

    for i in 0..<3 {
        start_idx   := i
        end_idx     := (i + 1) % 3

        start_pos   := triangle[start_idx]
        end_pos     := triangle[end_idx]

        mid_point   := (start_pos + end_pos) / 2

        diff        := end_pos - start_pos
        dist        := linalg.length(diff)
        dir         := diff / dist

        theta       := math.atan2(dir.y, dir.x) - math.PI * 0.5

        new_segment_particle := Particle {
            pos = start_pos,
            vel = velocity + linalg.normalize(mid_point - center) * rand.float32_range(min_force, max_force),
            trq = (-1 if rand.float32_range(0, 1) > 0.5 else 1) * rand.float32_range(0, max_torque),
            dur = rand.float32_range(min_lifetime, max_lifetime),
            siz = {0, dist},
            col = color,
            rot = theta,
            vdg = drag,
            adg = angular_drag,
        }

        add_particle(new_segment_particle, particle_system)
    }
}

spawn_particles_burst :: proc(
    particle_system : ^ParticleSystem, 
    center          : rl.Vector2, 
    velocity        : rl.Vector2,
    count           : int, 
    min_speed       : f32,
    max_speed       : f32,
    min_duration    : f32,
    max_duration    : f32,
    color           : rl.Color,
    start_angle     : f32 = 0.0,
    end_angle       : f32 = math.TAU,
    drag            : f32 = 0,
    size            := rl.Vector2{1, 1},
    angle_offset    :f32= 0,) {
        
    for i in 0..<count {
        speed           := rand.float32_range(min_speed, max_speed)
        angle           := rand.float32_range(start_angle, end_angle)
        new_particle    := Particle {
            pos = center,
            vel = rl.Vector2Rotate({0, speed}, angle) + velocity,
            rot = angle - math.PI / 2 + angle_offset,
            col = color,
            siz = size,
            dur = rand.float32_range(min_duration, max_duration),
            vdg = drag
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
    drag            : f32 = 0,
    angular_drag    : f32 = 0) {
        
    for i in 0..<count {
        speed           := rand.float32_range(min_speed, max_speed)
        new_particle    := Particle {
            pos = center,
            vel = rl.Vector2Rotate(direction * speed, rand.float32_range(-angle, angle)),
            col = color,
            dur = rand.float32_range(min_lifetime, max_lifetime),
            vdg = drag,
            adg = drag
        }
        add_particle(new_particle, particle_system)
    }
}