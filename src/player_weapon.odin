package game
import fmt "core:fmt"
import time "core:time"
import math "core:math"
import linalg "core:math/linalg"
import rl "vendor:raylib"

SHOOT_DELAY :: 0.2

@(private) last_shoot_tick : time.Tick

tick_player_weapon :: proc(using player : ^Player) {
    time_since_shoot := time.duration_seconds(time.tick_since(last_shoot_tick))

    if rl.IsMouseButtonDown(.LEFT) && time_since_shoot > SHOOT_DELAY {
        last_shoot_tick = time.tick_now()
        rl.PlaySound(sounds.laser)
        add_projectile(
            newProjectile = Projectile {
                pos = pos,
                dir = linalg.normalize(rl.GetMousePosition() - pos),
                spd = 2000,
                len = 15
            },
            projectiles = projectiles,
        )
    }
}
