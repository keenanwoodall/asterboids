package game

import "core:fmt"
import "core:time"
import "core:math/rand"
import rl "vendor:raylib"

SoundHistory :: struct {
    last_play_time : time.Time
}

Audio :: struct {
    music           : rl.Music,
    laser           : rl.Sound,
    dash            : rl.Sound,
    pickup          : rl.Sound,
    explosion       : rl.Sound,
    impact          : rl.Sound,
    thrust          : rl.Music,

    sound_history   : map[rl.Sound]SoundHistory
}

load_audio :: proc(using audio : ^Audio) {
    sound_history   = make(map[rl.Sound]SoundHistory)

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

unload_audio :: proc(using audio : ^Audio) {
    delete(sound_history)

    rl.UnloadMusicStream(music)
    rl.UnloadMusicStream(thrust)
    rl.UnloadSound(laser)
    rl.UnloadSound(dash)
    rl.UnloadSound(pickup)
    rl.UnloadSound(explosion)
    rl.UnloadSound(impact)
}

tick_audio :: proc(using audio : ^Audio) {
    rl.UpdateMusicStream(music)
    rl.UpdateMusicStream(thrust)

    if rl.IsKeyPressed(.M) {
        if rl.IsMusicStreamPlaying(music) {
            rl.PauseMusicStream(music)
        } 
        else do rl.ResumeMusicStream(music)
    }
}

try_play_sound :: proc(using audio : ^Audio, sound : rl.Sound, debounce := 0.1, pitch_variance :f32= 0.3) {
    now             := time.now()
    history, exists := sound_history[sound]
    if exists {
        if time.duration_seconds(time.since(history.last_play_time)) < debounce {
            return
        }
    }

    sound_history[sound] = { last_play_time = now }

    if !rl.IsSoundPlaying(sound) do rl.SetSoundPitch(sound, 1 + rand.float32_range(-pitch_variance, pitch_variance))

    rl.PlaySound(sound)
}
