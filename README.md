# Asterboids
A very simple space-shooter with rogue-like elements. Loosely inspired by the classic arcade game, Asteroids. The game was meant to be a week-long project, with the goal of learning the [Odin](https://odin-lang.org/) language and data-oriented-programming.
I ended up spending a bit more time on it because I was learning a lot and having so much fun!

https://github.com/keenanwoodall/asterboid/assets/9631530/bce23a20-0bc5-40b5-a939-a0e5d32bfbc7

---

## Introduction

I have been a Unity developer for a bit, and as such I've grown accustomed to OOP and high(ish)-level programming. However over the last couple years I've started feeling a bit jaded towards a lot of the code I read and write.
It's not like I've been ignorant to other paradigms like data-oriented programming - I've seen many of the well-known [talks](https://youtu.be/rX0ItVEVjHc) and [video essays](https://youtu.be/QM1iUe6IofM?list=PLrWlVANGG-ij06UCpfdxQ-LBclsWUDLt-) which were quite compelling to me - 
but I didn't feel like I could employ DOP in a meaningful way in Unity without going against the grain.
This frustration with Unity and OOP in conjunction with a blossoming interest in data-oriented programming led me to Odin!

Now I must admit - I was afraid I would bounce off the language. However, to my surprise the exact opposite occured! Unlike my previous forays into other languages like C++ and Rust, I got completely hooked by Odin.

The following breakdown will be composed of two different parts: an overview of my process learning Odin as a Unity developer, and a breakdown of the project itself.



## Project Breakdown

Asterboids is a top-down space shooter where the player fights off waves of enemies from their spaceship. The enemies move in bird-like flocks, hence the name Aster*boids*.
Enemies drop orbs which can be picked up to gain health and xp. When the player levels up they can pick a perk that affects the gameplay in some way, like you'd find in a rogue-like.

This project might not be a shining example of how to program in Odin, but I was still really happy with how straightfoward its development felt. It's a simple game, and so is the codebase!
With that in mind, this might be a good resource for other newbies who are looking into Odin. I've left plenty of thorough comments breaking most of it down.

Now lets jump behind the scenes. When working on the game, there were two things I thought were particularly satisfying to develop: the smoke trails and enemy flocking simulation,

### Smoke Trails
It started as me just wanting to draw a trail behind the player when they dash. An approach I've gotten a lot of mileage out of in the past is to draw the objects that should have a trail directly into a render texture. 
Rather than clearing the render texture each frame, it is drawn into _another_ render texture using a shader that subtracts a little bit of alpha from the entire image. Using this double-buffered render texture aproach lets you create post-processing-like
effects which accumulate over time.
![asterboid_TJDXf7NdIz](https://github.com/keenanwoodall/asterboid/assets/9631530/da811728-5787-479e-8934-015611e05447)

The fading trail was working, but I wanted to see if I could add a bit more juice to the effect. I recalled two interesting references which inspired the effect:
1. This [tweet](https://x.com/SoerbGames/status/1570773880444448773) by a game developer showing their screen-space smoke sim
2. The [vfx breakdown](https://youtu.be/6-SRtd9NTvw?t=66) of Remedy's Control, which showcases some fancy re-projection tech for their pseudo-3D smoke sim

I went for a very simple approach that's similar to the technique used in the first link. In addition to fading out the trail map over time, I add a little bit of displacement to where each pixel is sampled using noise.
This essentially "moves" pixels in the trail map over time using a noise function as a flow field. I first tried using 2D gradient noise for the displacement, but the results were awkward. Rather than flowing, the pixels just awkwardly rolled along the flow map until they hit a valley and got stuck.
I opted for using a 1d noise output and mapping it between 0 and TAU to represent an angle. Then each noise sample represents the rotation of a vector used to displace the pixel sample. This helped the pixels move more fluidly, though I imagine it could look even better with a different type of noise.
```glsl
// The "lifetime" of the current pixel will be 1-alpha, since the longer it's alive the lower its alpha should be.
float lifetime = 1 - texture(texture0, uv).a;
// Offset the uv by the noise direction.
// We'll use the pixel "lifetime" (again, just the alpha) plugged into a power curve to approximate drag.
// This way low opacity pixels get moved less.
float drag = pow(lifetime, .7);
float force = 0.1;
uv += noiseDir * force * drag * dt;

vec4 new_color = texture(texture0, uv);
```
This is what the trail effect looks like with the displacement applied. The flow map is visualized on the right of the screen.

![asterboid_pHHbExaKcR](https://github.com/keenanwoodall/asterboid/assets/9631530/b8ba88bf-7fa2-46ea-849f-98be9099ec17)

I actually think it looks good as-is, but as a final step I wanted the smoke to disperse over time. Rather than adding a blur pass, I'm simply setting the filter-mode of the trail render-texture to BILINEAR. This allows for a cheap blur effect, though I think the rate it blurs over time is tied to framerate which isn't ideal.

![asterboid_9h8g1vTNVx](https://github.com/keenanwoodall/asterboid/assets/9631530/d76d8c29-cb39-42fa-90cf-8acacc5b50f4)

Right now the forces are calculated on the fly via procedural noise, but if instead I stored forces in a render texture, I could "draw" arbitrary forces into the flow map. This would be useful for things like the player's thruster, which could add a force behind the player that pushes the 
trail pixels away. It could also allow for events like explosions; to render a radial force into the flow map which repulses the nearby trail map pixels away from the source of the explosion.

### Flocking Simulation
Considering how straightforward a wave-based space shooter is, I wanted to find an interesting way for enemies to move. I'm particularly drawn towards simulations and generative art whose logic is derived from simple rules. 
When thinking about how the enemies would be designed I considered Cellular Automata, [Particle Life](https://youtu.be/p4YirERTVF0) and Boids - all of which are mesmerizing in their own way. Boids seemed like the easiest thing to use for enemy movement, so I went with that - tho I think Particle Life could be a really cool way to model enemy behavior in a different game.

My take on boids is not novel by any means, but I thought the process with Odin was particularly pleasant compared to how it could have gone in Unity.
I started with a naive n² implementation where each enemy checks each other enemy to find its neighbors.
Each enemy then calculates the average velocity, average position and distances of its neighbors, so that the enemy can steer itself using the three boid behaviors: alignment, cohesion and separation.
```js
// Pseudo-code
for boid in boids
  flock(boid, boids) // alignment, cohesion, and separation forces
```
This worked, but I couldn't have more than a few hundred boids in the simulation before the frame-rate tanked.
To speed it up I wanted to do some sort of spatial partitioning. I had recently watched a cool [video](https://youtu.be/oewDaISQpw0) on optimization using spatial hashgrids and it seemed like a basic implementation and usage would be quite straightforward, so I wrote my own.
My hashgrid is basically just a map of 2d coordinates to dynamic arrays of arbitrary data - with some accompanying utility methods to get/set cell data.
```js
HGrid :: struct($T : typeid) {
    cells      : map[int2][dynamic]T,
    cell_size  : f32,
    min, max   : [2]int,
}
```
I imagine this is not optimal, but it was easy to make and it definitely sped things up!
Now that boids knew what cell they were in, they only had to check for boids in neighboring cells.
```js
// populate grid
for boid in boids
  insert(grid, boid)

// iterate over boids
for boid in boids
  // iterate over boids in neighboring cells
  for nearby_boids in nearby_cells(grid, boid.position)
    // calculate steering forces to nearby boids
    flock(boid, nearby_boids)
```

https://github.com/keenanwoodall/asterboid/assets/9631530/ac757855-8855-454b-b0d0-b01ceec85df0

This was a lot faster, but still not perfect. I was interested giving multithreading a go, and it seemed like an easy speed things up.
I really like Unity's job-system, so I was curious if anything similar existed for Odin. After some googling I found a [job-system](https://github.com/jakubtomsu/jobs) package on GitHub and threw it in my project.
I was a bit intimidated to dive in, but after a bunch of crashes I finally got it working! Rather than processing the simulation boid by boid as I was before, the boids are now simulated cell by cell.
Each cell is simulated in its own job, and the job-system spreads that work across multiple threads automatically.
```js
// Pseudo-code
for boid in boids
  insert(grid, boid)

for cell in grid
  add_job(() -> {
    for boid in cell
      flock(boid, cell)
  })

run_jobs()
```

### Summary
The smoke sim and flocking sim were my favorite things to implement, but there were a few less notable bits that I enjoyed putting together. I built a little collection of utility functions to split, pad, center and subdivide rects to compensate for Raylib GUI system which I found a bit lacking.
Starting with a single rect and chopping it up into bits was actually a pretty solid way to layout UI. I'm used to automatic imgui layouts, or manually authoring them in an editor like Unity, so I was a little surprised at how _not_ awful laying out the rects was with my handful of utility functions.
I think one thing that really helped was how arrays can be "value types" in Odin. In C# arrays are almost always allocated on the heap which I think subconsiously deterred me from trying something this simple in the past.
## Learning Odin
### First Steps

I have never properly used a low-level language. So in my eyes, the fact that within an hour of downloading Odin - a language I'd never used - I was drawing graphics to a window is a testament to Odin's accessibility. 
You can start writing code that actually does something cool in less than a day, and feel quite comfortable with the language in less than a week.

Now I'm not going to claim that I immediately understood everything about Odin. I had my fair share of stumbles (and still do!)
Some of the speedbumps were just due to me not understanding unspoked fundamentals. For instance, I was initially confused as to why Raylib "just worked", when SDL only worked with its DLL added to my project.
That led to me learning about static vs dynamic linking and the convenience of header-only libraries.
There were also a couple hiccups regarding manual memory management - mostly just me allocating stuff unnecessarily on the heap and taking a bit to understand Odin's different array types.
Growing pains, but growing nonetheless!

One thing that left a bit to be desired is tooling. Unity and C# have excellent IDE support: auto-complete, refactoring, and attaching a debugger "just works." 
While the Odin Language Server (ols) is pretty easy to setup and handles the basics, I miss certain things I would consider basic functionality like being able to rename a variable across a project.

All that being said, learning Odin has been quite a positive experience for me. Thanks to its focus on simplicity, Odin provided a buttery smooth entry into the world of low-level data-oriented programming.

### Manual Memory Management

I think a lot of people who have exclusively programmed in garbage collected languages would agree that manual memory management is intimidating. "You're telling me I have to remember to free everything!?"

While you do manage memory manually (try saying that 5 times fast), I found that in practice Odin provides some really helpful facilities which leave you with the advantages of manual memory management without much of the headache.

The `defer` keyword allows you to put the code that cleans something up right next to the code that initializes it. I love this because with it you can see at a glance that you've done your housekeeping correctly

Odin's allocators are also really helpful, even for someone like me who hasn't gone very deep into optimizing memory usage. Often times you have some ephemeral data you want to allocate that doesn't need to last for more than a frame.
Rather tham cleaning them up individually, I just used the builtin `context.temp_allocator` and called `free_all(context.temp_allocator)` at the end of each frame to free all my little allocations in one go. Easy peasy!

There was one moment in particular that I thought was pretty magical. I was testing how my game handled being restarted, and noticed that the memory usage kept increasing in Task Manager. I started looking through my code to find a leak, but couldn't track it down for the life of me!
Eventually, out of desperation, I opened the Odin language overview and hit Ctrl+F to see if "leak" was mentioned anywhere. It took me straight to a 20-line example snippet that sets up a "tracking" allocator. I pasted it at the top of my program, ran my game, and it printed the line numbers of
two different places where I allocated memory that was never freed. My mind was blown!

When I first started getting into Odin, I was really steeling myself for a world of hurt as I acclimated to the process of manual memory management. I'm happy to report it really wasn't an issue. I'm sure there's plenty of places where what I'm doing is sub-optimal, but that's bound to happen.
The `defer` keyword and temp/tracking allocators really helped cushion the transition away from GC and I found I quite preferred managing memory explicitly as opposed to the weird meta-game I'm used to playing to appease the garbage collector.

### Data Oriented Programming

Unity was the vessel through which I originally learned programming. It's a very object-oriented ecosystem so I've been a very object-oriented programmer. My noggin has been trained to break down problems in a very abstract way. 
Until recently I couldn't really imagine how I would architect programs any differently. While I could see the sense in other's criticisms of OOP, I still didn't have a concrete understanding of what a data oriented program would look like.

Making a tiny game with Odin forced me to discard what I had felt were the most basic "primitives" of a program architecture. When I finally started solving problems and implementing features without all the object-oriented bells and whistles I was accustomed to, it quickly became clear to me that I had been making mountains out of molehills. 
I was pretty amazed at how everything just...kept staying simple? I know I'm a bit late to the DOP (data-oriented party), but man what a breath of fresh air. I'd be lying if I said I didn't feel a bit of catharsis!
