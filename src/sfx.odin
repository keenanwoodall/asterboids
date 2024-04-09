package game
import fmt "core:fmt"
import rl   "vendor:raylib"

Sounds :: struct {
    music       : rl.Music,
    laser       : rl.Sound,
    dash        : rl.Sound,
    pickup      : rl.Sound,
    explosion    : rl.Sound,
    impact      : rl.Sound,
    thrust      : rl.Music,
}

load_sounds :: proc(using sounds : ^Sounds) {
    music           = rl.LoadMusicStream("res/music/gameplay.wav")
    thrust          = rl.LoadMusicStream("res/music/thrust.wav")

    music.looping   = true
    thrust.looping  = true

    laser           = rl.LoadSound("res/sfx/laser.wav")
    dash            = rl.LoadSound("res/sfx/dash.wav")
    pickup          = rl.LoadSound("res/sfx/pickup.wav")
    explosion       = rl.LoadSound("res/sfx/retro_explosion.wav")
    impact          = rl.LoadSound("res/sfx/retro_impact.wav")

    rl.SetSoundVolume(laser, 0.3)
    rl.SetSoundVolume(explosion, 0.3)
    rl.SetSoundVolume(impact, 0.3)
    rl.SetMusicVolume(thrust, 0)

    rl.SetMasterVolume(0.5)
    rl.PlayMusicStream(music)
    rl.PlayMusicStream(thrust)
}

unload_sounds :: proc(using sounds : ^Sounds) {
    rl.UnloadMusicStream(music)
    rl.UnloadMusicStream(thrust)
    rl.UnloadSound(laser)
    rl.UnloadSound(dash)
    rl.UnloadSound(pickup)
    rl.UnloadSound(explosion)
    rl.UnloadSound(impact)
}

tick_sounds :: proc(using sounds : ^Sounds) {
    rl.UpdateMusicStream(music)
    rl.UpdateMusicStream(thrust)
}