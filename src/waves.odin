// This code manages the spawning of waves of enemies.

package game

import "core:fmt"
import "core:time"
import "core:strings"
import "core:math"
import "core:math/rand"
import "core:math/linalg"
import rl "vendor:raylib"

ENEMY_SPAWN_PADDING :: 100  // How far offscreen should enemies be spawned?
ENEMY_WAVE_DURATION :: 10   // How long should the delay between waves be?

// The Waves struct stores the state of enemy waves.
// The number of waves which have been spawned, how long the current one has lasted etc.
Waves :: struct {
    no_enemies_timer : f32,         // Counts how long there have been 0 enemies. Used to spawn a new wave early if the previous was finished quickly.
    last_wave_time   : f64,         // At what time the last wave started.
    wave_duration    : f64,         // Delay until the next wave starts. This used to decrement over time, but that functionality has been removed.
    wave_idx         : int,         // Current wave index ie: how many waves have been spawned.
    cluster_rand     : rand.Rand,   // Waves of enemies are broken up into smaller groups.
                                    // This is a custom random number generator which is used to get random numbers unique to each cluster

    on_calc_loot_multiplier : ActionStack(int, Game)
}

// Init functions are called when the game first starts.
// Here we can assign default values and initialize data.
init_waves :: proc(using waves : ^Waves) {
    no_enemies_timer    = 0
    wave_duration       = ENEMY_WAVE_DURATION
    wave_idx            = 0
    last_wave_time      = -ENEMY_WAVE_DURATION
    cluster_rand        = rand.create(12345)

    init_action_stack(&on_calc_loot_multiplier)
}

unload_waves :: proc(using waves : ^Waves) {
    unload_action_stack(&on_calc_loot_multiplier)
}

// Tick functions are called every frame by the game
// Keeps track of how long it's been since the last wave of enemies and spawns a new wave accordingly.
tick_waves :: proc(using game : ^Game, dt : f32) {
    // If there are 0 enemies, increment the "no enemies" timer.
    if enemies.count == 0 do waves.no_enemies_timer += dt

    // Pressing N skips the current wave and spawns the next one immediately
    // Used when testing to quickly skip to harder waves.
    if rl.IsKeyPressed(.N) {
        enemies.count = 0
        waves.no_enemies_timer = 10000
    }

    // How long has it been since the last wave of enemies was spawned?
    elapsed := game_time - waves.last_wave_time

    // If the current wave has gone on longer than the wave duration, or there have been no
    // enemies for more than 2 seconds, spawn the next wave.
    if elapsed > waves.wave_duration || waves.no_enemies_timer > 2 {
        waves.wave_idx += 1

        waves.last_wave_time = game_time
        waves.no_enemies_timer = 0

        // Wave 1 has 2 enemies, Wave 2 has 4 enemies...etc
        enemy_count := waves.wave_idx * 2

        // Each wave is broken up into clusters of 30 enemies.
        // Each cluster of enemies is positioned at a random point offscreen.
        cluster_size := 30
        cluster_count := int(math.ceil(f32(enemy_count) / f32(cluster_size)))

        // Spawn a group of enemies for each cluster
        for i in 0..<cluster_count {
            spawn_enemies(enemy_count, i, game, OffscreenClusterSpawner)
        }
    }
}

// Draw functions are called at the end of each frame by the game.
// This draws a label for a couple seconds when a new wave is spawned.
draw_waves_gui :: proc(waves : ^Waves, time : f64) {
    WAVE_TEXT_DURATION :: 2
    wave_time := time - waves.last_wave_time
    if wave_time > WAVE_TEXT_DURATION do return
    
    label := strings.clone_to_cstring(fmt.tprintf("Wave %i", waves.wave_idx), context.temp_allocator)
    rect := centered_label_rect(screen_rect(), label, 30)
    rect.y += f32(rl.GetScreenHeight()) / 2 - 15
    rl.DrawText(label, i32(rect.x), i32(rect.y), 30, rl.WHITE)
}

// Spawns some number of enemies. Their position is calculated by the spawner_proc, which can be any function
// with a valid signature.
spawn_enemies :: proc(
    enemy_count     : int, 
    cluster_idx     : int,
    game            : ^Game, 
    spawner_proc    : proc(rng: ^rand.Rand, wave, cluster: int)->rl.Vector2) {
    
    // This is probably a silly way to go about this, but to author the three enemy variants
    // I'm using this struct to store the relevant parameters.
    Archetype :: struct { size : f32, hp : int, loot : int, color : rl.Color}

    // Each archetype is stored in this array.
    @(static)
    Archetypes := [?]Archetype {
        {ENEMY_SIZE * 1.0, 1, 1, rl.RED},
        {ENEMY_SIZE * 1.5, 2, 4, rl.ORANGE},
        {ENEMY_SIZE * 2.5, 7, 10, rl.SKYBLUE} 
    }

    loot_multiplier : int = 1
    execute_action_stack(game.waves.on_calc_loot_multiplier, &loot_multiplier, game)

    // For each enemy we want to spawn...
    for i in 0..<enemy_count {
        // Pick a random archetype by rolling a random number between 0 and 10.
        // 70% of the time the archetype will be the little red enemy.
        // 20% of the time it will be the orange enemy.
        // 10% of the time it will be the large blue enemy.
        archetype : Archetype
        id        : u8
        if x := rand.float32_range(0, 10); x < 7 {
            archetype = Archetypes[0]
            id = 0
        }
        else if x < 9 {
            archetype = Archetypes[1]
            id = 1
        }
        else {
            archetype = Archetypes[2]
            id = 2
        }

        // Create a new enemy, using the spawner_proc to calculate its position and the archetype
        // to configure the rest of its parameters.
        new_enemy : Enemy = {
            pos     = spawner_proc(&game.waves.cluster_rand, game.waves.wave_idx, cluster_idx),
            vel     = rl.Vector2Rotate({0, 1}, rand.float32_range(0, linalg.TAU)) * ENEMY_SPEED, // A little random start velocity just cuz
            siz     = archetype.size,
            hp      = archetype.hp,
            loot    = archetype.loot * loot_multiplier,
            col     = archetype.color,
            id      = id,
        }

        // Add the new enemy to the pool of enemies
        add_enemy(new_enemy, &game.enemies)
    }
}

// Returns a random position on screen, with optional padding.
random_screen_position :: proc(padding : f32 = 0, r : ^rand.Rand = nil) -> rl.Vector2 {
    w := f32(rl.GetScreenWidth())
    h := f32(rl.GetScreenHeight())
    return {rand.float32_range(padding, w - padding, r), rand.float32_range(padding, h - padding, r)}
}

// Returns a random position on the edge of the screen, with optional padding.
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

// Various spawner functions which can be passed to the spawn_enemies function to determine how enemies are positioned.
OffscreenSpawner        :: proc(rng: ^rand.Rand, wave: int = 0, cluster: int = 0) -> rl.Vector2 { return random_screen_border_position(ENEMY_SPAWN_PADDING * rand.float32_range(1, 2)) }
OnScreenSpawner         :: proc(rng: ^rand.Rand, wave: int = 0, cluster: int = 0) -> rl.Vector2 { return random_screen_position() }
// This is the spawn function the game currently uses.
OffscreenClusterSpawner :: proc(rng: ^rand.Rand, wave, cluster: int) -> rl.Vector2 {
    // Initialize the random number generator using the current cluster and wave as the seed.
    // This OffscreenClusterSpawner function is called for each enemy, but each call is independant from another,
    // so by initializing the rng using the cluster as a seed, we can get random numbers from it and know they'll
    // be the same for any other enemies of the same cluster.
    rand.init(rng, u64(cluster * wave + cluster - wave))

    // Enemies will be spawned offscreen. Add some random padding so they are spawned further away from the screen border, randomly.
    padding : f32 = ENEMY_SPAWN_PADDING * rand.float32_range(1.25, 3)

    // Use the rng which was seeded with the current cluster to get the origin of the current cluster.
    origin  := random_screen_border_position(padding, rng)
    // Add a random offset for the current enemy.
    origin  += {
        rand.float32_range(-ENEMY_SPAWN_PADDING, ENEMY_SPAWN_PADDING), 
        rand.float32_range(-ENEMY_SPAWN_PADDING, ENEMY_SPAWN_PADDING)
    }

    return origin
}