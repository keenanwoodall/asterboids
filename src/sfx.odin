// This code handles loading game sounds and music.
// It also provides some utility pitch variance and debouncing.
package game

import "core:fmt"
import "core:time"
import "core:math/rand"
import rl "vendor:raylib"

// A simple struct to record the last time a sound was played.
// Used for debounce (preventing sounds from being played too quickly in succession)
SoundHistory :: struct {
    last_play_time : time.Time
}

// The Audio struct stores all loaded sounds/music, as well as when each sound was last played.
Audio :: struct {
    music           : rl.Music,
    damage          : rl.Sound,
    die             : rl.Sound,
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
    thrust          : rl.Music, // Thrust is loaded as music so that it loops when played.
                                // If there's a way to loop sounds this is unnecessary.

    sound_history   : map[rl.Sound]SoundHistory
}

// Called when the game is loaded.
// Loads music and soud files and performs minor mixing.
load_audio :: proc(using audio : ^Audio) {
    sound_history   = make(map[rl.Sound]SoundHistory)

    music           = rl.LoadMusicStream("res/music/gameplay.wav")
    thrust          = rl.LoadMusicStream("res/music/thrust.wav")

    music.looping   = true
    thrust.looping  = true

    damage          = rl.LoadSound("res/sfx/damage.wav")
    die             = rl.LoadSound("res/sfx/die.wav")
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
    rl.SetSoundVolume(damage, 0.3)
    rl.SetSoundVolume(die, 0.5)
    rl.SetSoundVolume(deflect, 0.2)
    rl.SetSoundVolume(explosion, 0.3)
    rl.SetSoundVolume(impact, 0.3)
    rl.SetSoundVolume(collect_hp, 0.2)
    rl.SetSoundVolume(collect_xp, 0.2)
    rl.SetSoundVolume(level_up, 0.5)
    rl.SetSoundVolume(level_up_conf, 0.5)
    rl.SetMusicVolume(thrust, 0)

    rl.SetMasterVolume(0.5)
    //rl.PlayMusicStream(music)
    rl.PlayMusicStream(thrust)
}

// Called when the game is unloaded. Unloads sound and music from memory.
unload_audio :: proc(using audio : ^Audio) {
    delete(sound_history)

    rl.UnloadMusicStream(music)
    rl.UnloadMusicStream(thrust)
    rl.UnloadSound(laser)
    rl.UnloadSound(damage)
    rl.UnloadSound(die)
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

// Tick functions are called every frame by the game
// Ticks the game music. Music streams must be updated each frame.
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

// Utility function to play a sound. Sound will not play if it was last played within the debounce time.
try_play_sound :: proc(using audio : ^Audio, sound : rl.Sound, debounce := 0.1, pitch_variance : f32 = 0.2) {
    // Get the current time and check if the sound has been played before.
    now             := time.now()
    history, exists := sound_history[sound]
    // If the sound has been played before, return early if it was played within the debounce time.
    if exists && time.duration_seconds(time.since(history.last_play_time)) < debounce {
        return
    }

    // We can play the sound, so update the sound history to store the current time
    sound_history[sound] = { last_play_time = now }

    // If the sound isn't currently playing, apply pitch variation.
    // This code was written before I know about sound aliases. 
    // Because there are not aliases, pitch should not be changed while a sound is playing for risk of popping.
    if !rl.IsSoundPlaying(sound) {
        rl.SetSoundPitch(sound, 1 + rand.float32_range(-pitch_variance, pitch_variance))
    }

    rl.PlaySound(sound)
}
