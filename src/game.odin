// This is the heart of the game.
// It stores the entire state of the program and dictates the order in which various gameplay systems run at a high level
package game

import "core:fmt"
import "core:time"
import "core:math"
import "core:math/rand"
import "core:math/linalg"
import rl "vendor:raylib"

// This is the entire state of the game
// Each field is its own struct, and stores the state of some 
Game :: struct {
    player            : Player,       // Player position, velocity, health etc.
    tutorial          : Tutorial,     // Initializes tutorial and manages its state
    leveling          : Leveling,     // Player xp, level and other state related to leveling up.
    weapon            : Weapon,       // Fire rate, spread, kick etc.
    enemies           : Enemies,      // Pool of enemies, each with health, velocity etc.
    mines             : Mines,        // Pool of mines which can damage the player.
    waves             : Waves,        // Manages when waves of enemies are spawned, and how many.
    pickups           : Pickups,      // Pool of pickups dropped by enemies.
    audio             : Audio,        // Loaded sounds/music available to be played.
    stars             : Stars,        // Stars and their colors. Drawn to the screen as pixels.
    projectiles       : Projectiles,  // Pool of projectiles fired by the player.
    enemy_projectiles : Projectiles,  // Pool of projectiles fired by the player.
    
    game_time       : f64,          // The time used for gameplay.
    game_delta_time : f32,          // The dela-time used for gameplay.
    request_restart : bool,         // Anything can set this to true and the game will be restarted at the end of the current frame.
    
    pixel_particles         : ParticleSystem,   // Pool of particles, which will be drawn to the screen as pixels.
    circle_particles        : ParticleSystem,   // Pool of particles, which will be drawn to the screen as circles.
    line_particles          : ParticleSystem,   // Another pool of particles, which will be drawn to the screen as lines.
    line_trail_particles    : ParticleSystem,   // This particle system will be drawn to a special trails render texture
                                                // Note: Other stuff is actually being drawn to the trail rt as well now, just at a very low opacity to remain subtle
                                                //       This particle system specifically *only* draws to the trail rt whereas the others draw on top of the smoke trail.

    on_calc_time_scale      : ActionStack(f32, Game),

    screenshakes            : ScreenShakes,
    render_target_a         : rl.RenderTexture2D,   // The render texture the game is rendered to.
    render_target_b         : rl.RenderTexture2D,   // Another render texture the game is rendered to (double-buffered for post-processing)
    trail_render_target_a   : rl.RenderTexture2D,   // Render target which trails can be drawn to.
    trail_render_target_b   : rl.RenderTexture2D,   // Another render target which trails can be drawn to (double-buffered for advection, dispersal)
    shaders                 : map[string]rl.Shader, // Named shaders
}

// Kicks off initialization of the various game systems (where needed, not all systems manage their own state)
load_game :: proc(using game : ^Game) {
    // Create render textures for the game.
    // We use pairs of textures so that we can draw from one texture to another with various shader effects (blitting)
    // A "render_target" is a texture we draw the game to. Later a crt/vignette effect is applied before being drawn to the screen.
    render_target_a = rl.LoadRenderTexture(rl.GetScreenWidth(), rl.GetScreenHeight())
    render_target_b = rl.LoadRenderTexture(rl.GetScreenWidth(), rl.GetScreenHeight())
    // The "trail_render_target" textures have specific gameplay elements drawn to them. but rather than being cleared each frame they fade/advect over time.
    // This creates a turbulent trail effect in the texture which is then drawn to the primary render_target before foreground elements.
    trail_render_target_a = rl.LoadRenderTexture(rl.GetScreenWidth(), rl.GetScreenHeight())
    trail_render_target_b = rl.LoadRenderTexture(rl.GetScreenWidth(), rl.GetScreenHeight())

    rl.SetTextureWrap(render_target_a.texture, .CLAMP)
    rl.SetTextureWrap(render_target_b.texture, .CLAMP)
    rl.SetTextureWrap(trail_render_target_a.texture, .CLAMP)
    rl.SetTextureWrap(trail_render_target_b.texture, .CLAMP)
    // The trail render textures use bilinear sampling as a quick and dirty way to accumulate blur.
    rl.SetTextureFilter(trail_render_target_a.texture, .BILINEAR)
    rl.SetTextureFilter(trail_render_target_b.texture, .BILINEAR)

    request_restart = false
    game_time = 0

    // Load the shaders used by the game
    shaders = {
        "CRT"       = rl.LoadShader(vsFileName = nil, fsFileName = "res/shaders/crt.fs"),           // Scanlines/slight distortion
        "Vignette"  = rl.LoadShader(vsFileName = nil, fsFileName = "res/shaders/vignette.fs"),      // Darkened edges
        "TrailFade" = rl.LoadShader(vsFileName = nil, fsFileName = "res/shaders/trail_fade.fs"),    // Used for double-buffered trail rendering
    }

    // The game has an "action stack" which is used to calculate time scale. 
    // This allows external code like level-up modifiers to append themselves into the stack and modify the time-scale to their needs.
    // Other systems have their own action stacks for triggering events and calculating gameplay parameters, but this is the only one used by the Game struct.
    init_action_stack(&on_calc_time_scale)

    init_player(&player)
    init_tutorial(&tutorial)
    init_leveling(&leveling)
    init_weapon(&weapon)
    init_enemies(&enemies)
    init_mines(&mines)
    init_waves(&waves)
    init_projectiles(&projectiles)
    init_projectiles(&enemy_projectiles)
    init_pickups(&pickups)
    init_stars(&stars)
    init_screenshakes(&screenshakes)
    load_audio(&audio)

    // Enable tooltips which are used by the level-up gui
    rl.GuiEnableTooltip()

    start_tutorial(game)
}

// Releases resources used by the various game systems (where needed, not all systems manage their own state)
unload_game :: proc(using game : ^Game) {
    rl.UnloadRenderTexture(render_target_a)
    rl.UnloadRenderTexture(render_target_b)
    rl.UnloadRenderTexture(trail_render_target_a)
    rl.UnloadRenderTexture(trail_render_target_b)
    
    for _, shader in shaders do rl.UnloadShader(shader)

    unload_action_stack(&on_calc_time_scale)

    unload_player(&player)
    unload_weapon(&weapon)
    unload_projectiles(&projectiles)
    unload_projectiles(&enemy_projectiles)
    unload_enemies(&enemies)
    unload_mines(&mines)
    unload_waves(&waves)
    unload_pickups(&pickups)
    unload_audio(&audio)
    unload_screenshakes(&screenshakes)
    unload_mods()
}

// Ticks the various game systems
tick_game :: proc(using game : ^Game) {
    // Calculate the current time scale using an action stack. See action_stack.odin and modifiers.odin for more info.
    time_scale : f32 = 1
    execute_action_stack(on_calc_time_scale, &time_scale, game)
    game_delta_time = rl.GetFrameTime() * time_scale;

    tick_audio(&audio)
    request_restart = rl.IsKeyPressed(.R)

    // Tick the tutorial until it completes
    if !tutorial.complete {
        tick_tutorial(game)
    }

    // Run the game like normal unless the player is selecting a level-up option, in which case the gameplay should remain frozen.
    if !leveling.leveling_up {
        // Tick all the things!
        tick_pickups(game)
        tick_leveling(game)

        tick_player(game)
        tick_player_weapon(game)

        // Only tick the waves system if the player is alive and the tutorial is complete
        if player.alive && tutorial.complete do tick_waves(game)

        tick_mines(game)
        tick_enemies(game)
        tick_player_enemy_collision(game)
        tick_player_mines_collision(game)

        tick_projectiles(&enemy_projectiles, game_delta_time)
        tick_projectiles(&projectiles, game_delta_time)
        tick_player_projectiles(&projectiles, enemies, game_delta_time)

        tick_player_projectile_collision(game)
        tick_projectiles_screen_collision(&projectiles)
        tick_projectiles_screen_collision(&enemy_projectiles)
        tick_projectiles_enemy_collision(&projectiles, &enemies, &pixel_particles, &audio)
        tick_projectiles_mine_collision(&projectiles, &mines, &pixel_particles, &audio)
        
        tick_killed_player(game)
        tick_killed_enemies(&enemies, &pickups, &line_particles)
        tick_destroyed_mines(game)

        tick_particles(&pixel_particles, game_delta_time)
        tick_particles(&circle_particles, game_delta_time)
        tick_particles(&line_particles, game_delta_time)    
        tick_particles(&line_trail_particles, game_delta_time)    

        game_time += f64(game_delta_time)
    }
}

// Draws the various parts of the game
draw_game :: proc(using game : ^Game) {
    screenshake := sum_shake(&screenshakes, game_time)
    //TODO: DELETE ME
    //shake({ 0, 10 }, f32(game.game_time - game.weapon.last_shoot_time), 50, 6)

    // First draw stuff that should have a turbulent smoke trail to a render texture
    {
        // Start by blitting from the previous render target to the next to step the smoke "simulation" forward.
        blit(trail_render_target_a, trail_render_target_b, shaders["TrailFade"], 
            { "time", f32(game_time) },
            { "dt", rl.GetFrameTime() }, 
            { "res", [2]i32 { rl.GetScreenWidth(), rl.GetScreenHeight() }},
        )

        // Then draw everything that should have a trail.
        rl.BeginTextureMode(trail_render_target_b)
        {
            // Offset everything that's drawn by the current screenshake amount
            rl.rlTranslatef(screenshake.x, screenshake.y, 0)

            draw_player_trail(game)
            draw_particles_as_lines(&line_trail_particles)
            // eh go ahead and draw the other particles to the trail map as well :P. just with low opacity
            draw_particles_as_pixels(&pixel_particles, 0.5)
            draw_particles_as_circles(&circle_particles, 0.5)
            draw_particles_as_lines(&line_particles, 0.5)
            draw_projectiles(&projectiles, 0.5)
            draw_projectiles(&enemy_projectiles, 0.5)
        }
        rl.EndTextureMode()

        // Finally swap the render textures so that the destination is the source for the next tick.
        swap(&trail_render_target_b, &trail_render_target_a)
    }

    // Render game
    {
        // Almost everything in the game is drawn to a texture rather than directly to the screen.
        // This allows us to apply post processing shaders like a vignette to the texture before drawing it to the screen. 
        rl.BeginTextureMode(render_target_a)
        defer rl.EndTextureMode()

        // Draw a subtle vertical gradient for the background, and then draw stars on top
        rl.DrawRectangleGradientV(0, 0, rl.GetScreenWidth(), rl.GetScreenHeight(), {10, 3, 16, 255}, {5, 10, 20, 255})
        draw_stars(&stars)

        // The trails are drawn right after the background so that everything else draws on top.
        rl.DrawTextureRec(trail_render_target_a.texture, rl.Rectangle{ 0, 0, f32(render_target_a.texture.width), -f32(render_target_a.texture.height) }, rl.Vector2{ 0, 0 }, rl.WHITE);

        // Offset everything else that's drawn by the current screenshake amount
        // The trails in the render texture being drawn on the line above don't need to be translated because everything drawn to it was also translated.
        rl.rlTranslatef(screenshake.x, screenshake.y, 0)

        // Now that the smoke has been drawn, we can draw the rest of the game on top.
        draw_mines(game^)
        draw_player(game)
        draw_enemies(&enemies)
        draw_projectiles(&projectiles)
        draw_projectiles(&enemy_projectiles)
        draw_pickups(&pickups)
        draw_player_weapon(game)
        draw_particles_as_pixels(&pixel_particles)
        draw_particles_as_circles(&circle_particles)
        draw_particles_as_lines(&line_particles)

        if !tutorial.complete do draw_tutorial(game)
        else {
            draw_game_gui(game)
            draw_waves_gui(&waves, game_time)
        }

        rl.DrawFPS(10, 10)
    }

    // Display game
    {
        // Draw from the current render_target_a to render_target_b with a CRT shader
        rl.BeginTextureMode(render_target_b)
        rl.ClearBackground(rl.BLACK)
        rl.BeginShaderMode(shaders["CRT"])
        rl.DrawTextureRec(render_target_a.texture, rl.Rectangle{ 0, 0, f32(render_target_a.texture.width), -f32(render_target_a.texture.height) }, rl.Vector2{ 0, 0 }, rl.WHITE);
        rl.EndShaderMode()
        rl.EndTextureMode()

        swap(&game.render_target_a, &game.render_target_b)
        
        // Draw from the new render_target_a to render_target_b with a Vignette shader
        rl.BeginTextureMode(render_target_b)
        rl.ClearBackground(rl.BLACK)
        rl.BeginShaderMode(shaders["Vignette"])
        rl.DrawTextureRec(render_target_a.texture, rl.Rectangle{ 0, 0, f32(render_target_a.texture.width), -f32(render_target_a.texture.height) }, rl.Vector2{ 0, 0 }, rl.WHITE);
        rl.EndShaderMode()
        rl.EndTextureMode()

        swap(&game.render_target_a, &game.render_target_b)

        // Draw from the current render_target_a to the screen
        rl.BeginDrawing()
        defer rl.EndDrawing()
        
        rl.DrawTextureRec(render_target_a.texture, rl.Rectangle{ 0, 0, f32(render_target_a.texture.width), -f32(render_target_a.texture.height) }, rl.Vector2{ 0, 0 }, rl.WHITE);

        // Level up gui is drawn after post processing to help with legibility
        if leveling.leveling_up {
            draw_level_up_gui(game)
        }
    }
}