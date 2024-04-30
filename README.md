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

I actually think it looks good as-is, but as a final step I wanted the smoke to disperse over time. Rather than adding a blur pass, I'm simply setting the filter-mode of the trail render-texture to BILINEAR. This "blurs" each sample a softens the smoke over time.

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
    description : cstring,                      // Description of the modifier. Shown in the level up gui
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

### Summary

I had quite a positive experience learning the basics of Odin and am looking forward to using it for more projects in the future. Odin provides a buttery-smooth entry into low-level programming and I appreciate the lessons its design taught me about writing simpler code. I think there's some good bones here for a proper game so I may continue hacking on it in the future, but for now I've got other projects I need to get back to :)
