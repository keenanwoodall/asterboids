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
    impact          : rl.Sound,
    deflect         : rl.Sound,
    dash            : rl.Sound,
    pickup          : rl.Sound,
    explosion       : rl.Sound,
    collect_xp      : rl.Sound,
    collect_hp      : rl.Sound,
    level_up        : rl.Sound,
    level_up_conf   : rl.Sound,
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
    impact          = rl.LoadSound("res/sfx/laser_impact.wav")
    deflect         = rl.LoadSound("res/sfx/laser_deflect.wav")
    dash            = rl.LoadSound("res/sfx/dash.wav")
    pickup          = rl.LoadSound("res/sfx/pickup.wav")
    explosion       = rl.LoadSound("res/sfx/enemy_explosion.wav")

    collect_hp      = rl.LoadSound("res/sfx/collect_hp.wav")
    collect_xp      = rl.LoadSound("res/sfx/collect_xp.wav")
    level_up        = rl.LoadSound("res/sfx/level_up.wav")
    level_up_conf   = rl.LoadSound("res/sfx/level_up_confirm.wav")

    rl.SetSoundVolume(laser, 0.3)
    rl.SetSoundVolume(deflect, 0.2)
    rl.SetSoundVolume(explosion, 0.3)
    rl.SetSoundVolume(impact, 0.3)
    rl.SetSoundVolume(collect_hp, 0.2)
    rl.SetSoundVolume(collect_xp, 0.2)
    rl.SetSoundVolume(level_up, 0.5)
    rl.SetSoundVolume(level_up_conf, 0.5)
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
    rl.UnloadSound(impact)
    rl.UnloadSound(deflect)
    rl.UnloadSound(dash)
    rl.UnloadSound(pickup)
    rl.UnloadSound(explosion)
    rl.UnloadSound(collect_hp)
    rl.UnloadSound(collect_xp)
    rl.UnloadSound(level_up)
    rl.UnloadSound(level_up_conf)
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

try_play_sound :: proc(using audio : ^Audio, sound : rl.Sound, debounce := 0.1, pitch_variance : f32 = 0.2) {
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
