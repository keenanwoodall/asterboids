# Asterboids
A very simple space-shooter with rogue-like elements. Loosely inspired by the classic arcade game, Asteroids. The game was meant to be a week-long project, with the goal of learning the [Odin](https://odin-lang.org/) language and data-oriented-programming.
I ended up spending a bit more time on it because I was learning a lot and having so much fun!

https://github.com/keenanwoodall/asterboid/assets/9631530/bce23a20-0bc5-40b5-a939-a0e5d32bfbc7

**Disclaimer**: While you're free to do what you like with the code, the audio files are not mine to give. The game runs without them just fine if needed, and there are no other assets. I have only built and tested this project on Windows.

---

## Project Breakdown

Asterboids is a top-down space shooter where the player fights off waves of enemies from their spaceship. The enemies move in bird-like flocks, hence the name Aster*boids*.

There were three things I thought were particularly satisfying to develop: the smoke trails, enemy flocking simulation and rogue-like perk system.

### Smoke Trails
The original goal was to draw a trail behind the player when they dash. An approach I've gotten a lot of mileage out of in the past is to draw objects that should have a trail directly into a render texture. 
Rather than clearing the render texture each frame, it is drawn into _another_ render texture using a shader that subtracts a little bit of alpha from the entire image. Using this double-buffered render texture aproach lets you create post-processing-like
effects which accumulate over time.

![trail fade](https://github.com/keenanwoodall/asterboid/assets/9631530/f61ea1b0-b8dd-4159-963a-bf146021958a)

The fading trail was working, but I wanted to see if I could add a bit more juice to the effect.

In addition to fading out the trail map over time, I add a little bit of distortion by offsetting the uvs.
This "moves" the pixels in render texture over time. For distortion I'm using simplex noise. Each noise sample is mapped between 0 and TAU, and then used to rotate a unit vector.

This is what the trail effect looks like with the displacement applied. The distortion "forces" are hackily visualized on the right of the screen.

![trail advect](https://github.com/keenanwoodall/asterboid/assets/9631530/7527bc30-37eb-4fc2-9095-b0236af5b264)

I actually think it looks good as-is, but as a final step I wanted the smoke to disperse over time. Rather than adding a blur pass, I'm simply setting the filter-mode of the trail render-texture to BILINEAR. This "blurs" each sample, softening the smoke over time.

![trail disperse](https://github.com/keenanwoodall/asterboid/assets/9631530/b66b1d72-28b2-4b38-8e7e-4355a6b8e1b6)

### Flocking Simulation
I wanted to find an interesting way for enemies to move. Boids seemed interesting, so I went with that!

I started with a naive n² implementation where each enemy checks its distance from every other enemy to find its neighbors.
This worked, but I couldn't have many boids before the frame-rate tanked.
To speed it up I wanted to do some sort of spatial partitioning. I had recently watched a [video](https://youtu.be/oewDaISQpw0) on optimization using spatial hashgrids, and it seemed like a basic implementation would be quite straightforward, so I wrote my own.

Now that boids knew what cell they were in, they only had to check for boids in neighboring cells.

This was a lot faster, but I was interested giving multithreading a go.
I found a [job-system](https://github.com/jakubtomsu/jobs) package on GitHub and threw it in my project.
Rather than processing the simulation boid by boid as I was before, the boids are now simulated cell by cell.
Each cell is simulated in its own job, and the job-system spreads that work across multiple threads automatically.
```js
// Pseudo-code
for boid in boids
  insert(grid, boid)

for cell in grid
  add_job((cell) -> {
    for boid in cell
      flock(boid, cell)
  })

run_jobs()
```
More boids, yay!

![ezgif-3-1f0dd15892](https://github.com/keenanwoodall/asterboid/assets/9631530/6c3c18e8-75e2-451a-8ddf-737fcfcdb245)

### Gameplay Modifiers
Whenever the player levels up they can pick one of three random level-up choices. Each choice is represented by a struct that stores a function for ensuring the modifier is valid given the current game state, and another for actually applying it to the game-state
```js
Modifier :: struct {
    name        : cstring,                      // Name of the modifier. Shown in the level up gui
    description : cstring,                      // Descriptiaon of the modifier. Shown in the level up gui
    is_valid    : proc(game : ^Game) -> bool,   // Function that can be called to check if a modifier is valid
    on_choose   : proc(game : ^Game),           // Function that can be called to apply the modifier to the current game state
}
```
Each modifier is then authored in a big map so it's quite easy to throw together interesting modifiers.
```js
ModifierChoices := [ModifierType]Modifier {
  .RangeFinder = {
    name        = "Range Finder",
    description = "Installs a laser sight onto the player ship",
    on_choose   = proc(game : ^Game) { 
        add_action(&game.weapon.on_draw_weapon, proc(draw : ^bool, game : ^Game) {
            rl.DrawLineV(...)
        })
     }
  },
  ...
}
```

## Summary

I had quite a positive experience learning the basics of Odin and am looking forward to using it for more projects in the future. Odin provides a buttery-smooth entry into low-level programming and I appreciate the lessons its design taught me about writing simpler code. I think there's some good bones here for a proper game so I may continue hacking on it in the future, but for now I've got other projects I need to get back to :)

## Testing

I'm version controlling the executable that's built during the development process, so if you're on Windows you can run that. However I'd recommend just building it just takes a second. 
Simply run `odin run src/ asterboids.exe`

I am developing on Windows and haven't tested on any other platforms so if you run into any issues let me know.

To ease the gameplay testing process there are a few keyboard shortcuts:
- `R` - restart
- `N` - clear current wave and spawn next. helpful for quickly skipping ahead to waves with more enemies
- `L` - level up immediately

## Editing

All of the source code lives in the src/ folder. The entry point into the application is `app.odin`. Within this file is a simple application loop which calls `tick_game()` and `draw_game()`, passing a `Game`  struct.

The `Game` struct holds the entire state of the game. This state is broken up into high-level "systems" like `Enemies`, `Projectiles`, `Player` etc. The `tick_game` and `draw_game` procedures then delegate ticking/drawing to various procedures used by the sub-systems like.

With that in mind, if you want to explore the code-base and start making changes I'd recommend starting from the `tick_game` procedure for game logic and `draw_game` for game rendering. You can drill down into any of the subsystem's draw/tick procedures that catch your interest.

If you're looking for some low-hanging fruit here are some fun/easy things you can mess with:
- **Create your own level-up perk**: Find the `ModifierChoices` map near the top of `modifier.odin` and declare a new `Modifier`. You can also reference the other modifiers to see how they're authored, but the main thing is to assign an `on_choose` callback function and modify the `Game` state however you like from within it. 
- **Give the mouse a smokey trail**: Find where smoke trails are drawn at the top of `draw_game()` proc in `game.odin`. Simply draw a circle at the mouse's position `rl.DrawCircleV(rl.GetMousePosition(), 5, rl.BLUE)`
- **Invincibility**: Find the `tick_game` function in `game.odin` and comment out the `tick_killed_player()` call

<details>
  <summary><h2>Updates</h2></summary>
  
  ### Improved Flocking

  Enemies prioritize following the player less when far away. This helps avoid boids glomming into one big heap and allows them to do more boid-like behavior. Enemies arrive "in formation", and when close, appear to enter a sort of aggro state.
  
  ![image](https://github.com/keenanwoodall/asterboid/assets/9631530/898505db-8c75-4f6e-b8c2-c2c71cf2f711)

  ### Squash and Stretch

  The player now has procedural squash and stretch animation when dashing

  ![asterboid_eCDUk3cDb3](https://github.com/keenanwoodall/asterboid/assets/9631530/a000c040-f3b7-4f50-9895-fd72252b92f0)

  
</details>
