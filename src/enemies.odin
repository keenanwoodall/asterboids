package game

import fmt      "core:fmt"
import math     "core:math"
import time     "core:time"
import rand     "core:math/rand"
import linalg   "core:math/linalg"
import rl       "vendor:raylib"

MAX_ENEMIES             :: 4096
ENEMY_SIZE              :: 10
ENEMY_SPEED             :: 200
ENEMY_FORCE             :: .05
ENEMY_ALIGNMENT_RADIUS  :: 40
ENEMY_COHESION_RADIUS   :: 55
ENEMY_SEPARATION_RADIUS :: 20
ENEMY_FOLLOW_FACTOR     :: 1.75
ENEMY_ALIGNMENT_FACTOR  :: 1.25
ENEMY_COHESION_FACTOR   :: 1.0
ENEMY_SEPARATION_FACTOR :: 3.0

Enemy :: struct {
    pos : rl.Vector2,
    vel : rl.Vector2,
    siz : f32,
    hp  : int,
    col : rl.Color
}

Enemies :: struct {
    count     : int,
    instances : #soa[MAX_ENEMIES]Enemy
}

init_enemies :: proc(using Enemies : ^Enemies) {
    count = 0
}

@(optimization_mode="speed")
tick_enemies :: proc(using enemies : ^Enemies, player : ^Player, dt : f32) {
    for i in 0..<count {
        using enemy := instances[i]

        // Sum steering forces
        steer_force := rl.Vector2{}
        steer_force += follow(i, enemies, player.pos) * ENEMY_FOLLOW_FACTOR
        steer_force += alignment(i, enemies) * ENEMY_ALIGNMENT_FACTOR / siz
        steer_force += cohesion(i, enemies) * ENEMY_COHESION_FACTOR / siz
        steer_force += separation(i, enemies) * ENEMY_SEPARATION_FACTOR

        vel += steer_force
        vel = limit_length(vel, ENEMY_SPEED)

        pos += vel * dt

        instances[i] = enemy
    }
}

@(private)
follow :: proc(index : int, using enemies : ^Enemies, target : rl.Vector2) -> rl.Vector2 {
    current  := instances[index]
    steering := linalg.normalize(target - current.pos) * ENEMY_SPEED
    steering -= current.vel
    steering = limit_length(steering, ENEMY_FORCE)
    return steering
}

@(private)
alignment :: proc (index : int, using enemies : ^Enemies) -> rl.Vector2 {
    current         := instances[index]
    steering        := rl.Vector2{}
    neighbor_count  := 0
    for other, i in instances[0:count] {
        if i == index do continue

        dist := linalg.distance(current.pos, other.pos)
        if dist > ENEMY_ALIGNMENT_RADIUS do continue

        steering += other.vel
        neighbor_count += 1
    }

    if neighbor_count > 0 {
        steering /= f32(neighbor_count)
        steering = set_length(steering, ENEMY_SPEED)
        steering -= current.vel
        steering = limit_length(steering, ENEMY_FORCE)
    }

    return steering
}

@(private)
cohesion :: proc (index : int, using enemies : ^Enemies) -> rl.Vector2 {
    current         := instances[index]
    steering        := rl.Vector2{}
    neighbor_count  := 0
    for other, i in instances[0:count] {
        if i == index do continue

        dist := linalg.distance(current.pos, other.pos)
        if dist > ENEMY_COHESION_RADIUS do continue

        steering += other.pos
        neighbor_count += 1
    }

    if neighbor_count > 0 {
        steering /= f32(neighbor_count)
        steering -= current.pos
        steering = set_length(steering, ENEMY_SPEED)
        steering -= current.vel
        steering = limit_length(steering, ENEMY_FORCE)
    }

    return steering
}

@(private)
separation :: proc (index : int, using enemies : ^Enemies) -> rl.Vector2 {
    current         := instances[index]
    steering        := rl.Vector2{}
    neighbor_count  := 0

    for other, i in instances[0:count] {
        if i == index do continue

        dist := linalg.distance(current.pos, other.pos) - (current.siz + other.siz)
        if dist > ENEMY_SEPARATION_RADIUS do continue

        diff := current.pos - other.pos
        diff /= dist * dist
        steering += diff
        neighbor_count  += 1
    }

    if neighbor_count > 0 {
        steering /= f32(neighbor_count)
        steering = set_length(steering, ENEMY_SPEED)
        steering -= current.vel
        steering = limit_length(steering, ENEMY_FORCE)
    }

    return steering
}

@(private)
set_length :: proc(v : rl.Vector2, length : f32) -> rl.Vector2 {
    return linalg.normalize(v) * length
}

@(private)
limit_length :: proc(v : rl.Vector2, limit : f32) -> rl.Vector2 {
    len := linalg.length(v)
    if len == 0 || len <= limit {
        return v
    }

    dir := v / len
    return dir * limit
}

draw_enemies :: proc(enemies : ^Enemies) {
    rl.rlSetLineWidth(3)
    for i in 0..<enemies.count {
        using inst  := enemies.instances[i]
        corners     := get_enemy_corners(inst)
        rl.DrawTriangleLines(corners[0], corners[1], corners[2], col)
    }
}

add_enemy :: proc(newEnemy : Enemy, using enemies : ^Enemies) {
    if count == MAX_ENEMIES {
        return
    }
    instances[count] = newEnemy
    count += 1
}

release_enemy :: proc(index : int, using enemies : ^Enemies) {
    instances[index] = instances[count - 1]
    count -= 1
}

get_enemy_corners :: proc(using enemy : Enemy) -> [3]rl.Vector2 {
    dir     := linalg.normalize(vel)
    radians := linalg.atan2(dir.y, dir.x) - linalg.PI * 0.5
    corners := [3]rl.Vector2 { {-1, -1}, {+1, -1}, {0, +1.5} }
    for i in 0..<3 {
        corners[i] = rl.Vector2Rotate(corners[i], radians)
        corners[i] *= siz
        corners[i] += pos
    }
    return corners
}

check_enemy_line_collision :: proc(line_start, line_end : rl.Vector2, enemy : Enemy) -> (hit : bool, point, normal : rl.Vector2) {
    corners := get_enemy_corners(enemy)

    for i := 0; i < len(corners); i += 1 {
        enemy_corner_start  := corners[i]
        enemy_corner_end    := corners[(i + 1) % len(corners)]

        point : rl.Vector2 = {}

        if rl.CheckCollisionLines(line_start, line_end, enemy_corner_start, enemy_corner_end, &point) {
            tangent := linalg.normalize(enemy_corner_start - enemy_corner_end)
            normal  := rl.Vector2Rotate(tangent, -math.TAU)
            return true, point, normal
        }
    }

    return false, {}, {}
}