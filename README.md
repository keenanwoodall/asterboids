# Asterboids
A very simple space-shooter with rogue-like elements. Loosely inspired by the classic arcade game, Asteroids. The game was meant to be a week-long project, with the goal of learning the [Odin](https://odin-lang.org/) language and data-oriented-programming.
I ended up spending a bit more time on it because I was learning a lot and having so much fun!

## Post-Mortem

*This is a summary of my introduction to Odin/data-oriented programming, and all the revelations you might expect!* :)

Odin is a system-level programming language which focuses on simplicity, performance and "the joy of programming."

Sounds interesting, right? Well as someone who has been writing primarily object-oriented C# code my entire career I admit I was afraid I would bounce off the language. 
However, to my surprise the exact opposite occured! Unlike my previous forays into other languages like C++ and Rust, I got completely hooked by Odin.
As you'll see it was a perfect storm... in a good way. 

### Why Odin? Why Data-Oriented?

Over the last few years I've been becoming a bit jaded towards the code I read and write. Writing good code has always been very important to me, but despite my best efforts I have rarely (if ever) felt that I've achieved that goal on projects of even moderate complexity. 
For a long time I just accepted that I was either over-engineering or being a perfectionist, and trusted it would get better with time and effort. It has to an extent, but the sentiment remains. However, over the last few months I've had time to really step outside of my "bubble" and get a new perspective on how to approach writing software. 

It's not like I've been ignorant to other paradigms like data-oriented programming - I've seen many of the well-known [talks](https://youtu.be/rX0ItVEVjHc) and [video essays](https://youtu.be/QM1iUe6IofM?list=PLrWlVANGG-ij06UCpfdxQ-LBclsWUDLt-) that make a case against object-oriented programming.
They were quite compelling to me, but I didn't feel like I could employ DOP in a meaningful way with my work in Unity. This is of course not true, but in an environment like Unity where everything is object-oriented, using DOP to a significant degree involves going against the grain. 
It can be done, but I don't think it's an ideal environment to learn DOP.

Unity has been working on its Data Oriented Tech Stack (DOTS) for many years. I have used its job-system heavily which rewards thinking about your program from a data perspective. 
However, Unity's DOTS does a lot of "magic" to run your code and it was hard to make a distinction between Unity's implementation of ECS and the more general principles of DOP. I appreciate what it's doing, but I wanted to dig into DOP in a "pure" environment where the only code that's running is the code I wrote.

My disenchantment with OOP/Unity was growing and so was my blossoming interest in DOP. I found myself especially motivated to get out of my comfort zone and tackle something new.
As part of my research, I had been binging Jonathan Blow's [Programming Language For Video Games](https://www.youtube.com/playlist?list=PLmV5I2fxaiCKfxMBrNsU1kgKJXD3PkyxO) series. 
Seeing his process of designing and implementing his language "Jai" gave me more insight into the why and how of a data-focused language.
Like many others I sent an email requesting access to the language beta, but I wasn't holding my breath. I hoped that if I could find a language with similar goals I could get up and running quite quickly. That's when I found Odin!

### First Steps
I have never _properly_ used a low-level language. So in my eyes, the fact that **within an hour** of downloading Odin - a language I'd never used - I was drawing graphics to a window is a testament to Odin's accessibility.
You can start writing code that actually does something cool in less than a day, and feel quite comfortable with the language in less than a week. Seriously. It sure doesn't hurt that Odin comes with official integrations for many popular libraries and all the major graphics APIs.

Now I'm not going to claim that I immediately understood everything about Odin. I had my fair share of stumbles (and still do!) Odin's three array types took me a bit to digest. I was also initially confused as to why Odin's Raylib package worked without adding any DLLs to my project files, but _not_ SDL. 
Now I can appreciate the convenience of header-only libraries! Someone on the Odin discord server also kindly pointed out that I was allocating way more things on the heap than was necessary. Growing pains, but growing nonetheless!

One thing that left a bit to be desired is tooling. Unity and C# have excellent IDE support: auto-complete, refactoring, and attaching a debugger "just works." While the Odin Language Server (ols) is pretty easy to setup and handles the basics, 
I miss certain things I would consider basic functionality like being able to rename a variable across a project.

All that being said, using Odin has been quite a positive experience for me. It provides a buttery smooth entry into the world of low-level data-oriented programming, which I think is largely due to the small number of concepts you need to grok to get started.
The simplicity of the language is a big win for the learning process because it avoids a "combinatorial explosion" of potential feature interactions, making Odin incredibly easy to read and write.

### Learning Manual Memory Management
I think a lot of people who have exclusively programmed in garbage collected languages would agree that manual memory management is intimidating. "You're telling me I have to remember to free _everything_!?" 

While you do manage memory manually (try saying that 5 times fast), I found that in practice Odin provides some really helpful facilities which leave you with the advantages of manual memory management without much of the headache.

The first tool Odin puts in your toolbelt is the `defer` keyword. You can use it to "defer" any statement to the end of the current scope. Simple as that.
This is not unique to Odin, but it was novel to me! Deferring allows you to put the code that cleans something up right next to the code that initializes it.
```js
big_array := make([]int, 1000000)
defer delete(big_array) // this will get called no matter what!

// * do a bunch of stuff
```
It lets you see at a glance that you've done your housekeeping correctly, rather than scrolling all over the place to make sure every `new` at the top of a function was paired with a `free` at the bottom. 
It also provides definitiveness. No early `return` or other jump in control flow will circumvent a deferred statement. It's a dead simple construct that provides a ton of value.

The next tool in your memory management toolbelt is Odin's allocators. Allocators are a major feature of Odin. As the name implies they provide functionality to allocate memory in various ways.
Not only can you use them to have more control over how _your_ code allocates memory, but how _external_ code allocates as well; using Odin's implicit `context` system. 
There's one allocator in particular that I think is brilliant: Odin's `temp_allocator`. 

Often times you have some ephemeral data you want to allocate that doesn't need to last for more than a frame.
It can feel a bit tedious to manually free each of these allocations when you _know_ they're all temporary. Why not just...free those temporary allocations all at once?
The `temp_allocator` makes this super simple. Just use `context.temp_allocator` for temporary allocations and call `free_all(context.temp_allocator)` at the end of your frame. Easy peasy!

While the `temp_allocator` can really take a load off cleaning up small allocations throughout your code-base, how can you be _sure_ that you don't have any leaks?
At one point I was positive I had a big leak in Asterboids, but I couldn't track it down for the life of me. Eventually, out of desperation, I opened the Odin language [overview](https://odin-lang.org/docs/overview/) and hit Ctrl+F to see if "leak" was mentioned anywhere.
It took me straight to a 20-line example snippet that makes use of the (new to me) `mem.tracking_allocator`, which tracks every allocation and free to make sure you don't have any leaks or incorrect frees. 
I pasted the snippet at the entry point of my game, ran then closed it, and it printed the line number of two different places I had allocated memory that was never freed. Mind blown! Now that's a powerful feature.

When I first started getting into Odin, I was really steeling myself for a world of hurt as I acclimated to the arduous process of manual memory management. I'm happy to report it really wasn't an issue. 
I'm sure there's plenty of places where what I'm doing is sub-optimal, but that's bound to happen as I learn the ropes.

### Learning Data Oriented Programming

Unity was the vessel through which I originally learned programming. It's a very object-oriented ecosystem so I've been a very object-oriented programmer. My noggin has been trained to break down problems in a very abstract way.
Until recently I couldn't really imagine how I would architect programs any differently. While I could see the sense in other's criticisms of OOP, I still didn't have a concrete understanding of what a data oriented program would look like.

Making a tiny game with Odin _forced_ me to discard what I had felt were the most basic "primitives" of a program architecture.
When I finally started solving problems and implementing features without all the object-oriented bells and whistles I was accustomed to, it quickly became clear to me that I had been making mountains out of molehills.
I didn't need to "translate" my understanding of OOP to DOP, I simply needed to let it go. It was as if DOP was the natural state of a program, and OOP was a convolution.

---

Let's take a look at the boids simulation whose implementation was changed multiple times.
My first implementation was very slow. Here was the pseudo code:
```js
for boid in boids
  flock(boid, boids) // alignment, cohesion, separation
```
Each boid checks every other boid in the `flock` procedure to find nearby neighbors. With this implementation I couldn't have more than a few hundred boids before the framerate tanked.
To speed it up I wanted to break up the space into a grid of cells. If boids know what cell they're in, they just have to check for boids in neighboring cells.
So the (pseudo)code became this:
```js
for boid in boids
  insert(grid, boid)

for boid in boids
  for nearby_boids in nearby_cells(grid, boid.position)
    flock(boid, nearby_boids)
```
This was a lot faster, but still not perfect. There are many ways to speed it up, but I figured I'd get the biggest bang for my buck by multithreading it.
I found a [job system ](https://github.com/jakubtomsu/jobs) on GitHub and refactored the boid simulation so that each cell is simulated by a different job:
```js
for boid in boids
  insert(grid, boid)

for cell in grid
  add_job(() -> {
    for boid in cell
      flock(boid, cell)
  })

run_jobs()
```
This is a **very** big simplification, but hopefully you can see how naturally the high-level logic evolved between each iteration.

I admit, I can't claim as a fact that this would have gone less smoothly in an object-oriented language like C#.
OOP vs DOP comparisons are hard to make because OOP examples are arbitrarily over-engineered; however I think that gets at the heart of the issue!
OOP developers are presented with, and encouraged to use, an arsenal of abstract constructs to represent their code. There's an arbitrarity to how OOP solves problems, so the odds of two OOP developers implementing something the same way is very slim.
All I can really say is that the process of improving the boid simulation went very smoothly for me. It's a microcosm of my experience with Odin/DOP. At no point was wracking my brain trying to understand what my code was doing. Nor was I doing sweeping refactors as the problem-space changed.

With DOP I've noticed there's a "pit of succes" for code complexity. Without a bunch of facilities for adding abstraction, you naturally solve problems in a straight-forward manner. It takes effort to add unnecessary abstraction.
With OOP it feels more like a "hill of failure" because it's expected that you represent your problem with abstract concepts which end up biting you in the ass.

![OOP vs DOP](https://github.com/keenanwoodall/asterboid/assets/9631530/c247d4e8-6810-4242-b6e7-486eb6d7651d)

### OOPsy Daisy

I must admit, I would feel embarassed about all the mind-numbing gymnastics I've done to accomodate OOP in the past, but I know I'm not the only one, and any embarassment is largely eclipsed by a feeling of catharsis.

When writing OOP code in a language like C#, I have so many options for how I architect my program. Abstraction is so easy, that I can't help but wonder about all the vague things I want to ensure my program can handle. 
Having an aresenal of language features that encourage you to plan for an unpredictable future opens the door to a lot of questions that you can't _really_ answer, which results in you throwing abstraction at uncertainty.
In this way, overengineering a problem with OOP is seductively easy. It always feels great at first, like you're doing good work, but when the problem inevitably changes, all the abstractions you put in place turn on you!
All this flexibility you encoded into your architecture is really just a bunch of abitrary barriers. As soon as the problem doesn't fit the mould you made for it, your carefully constructed house of cards falls apart.
True flexibility is writing code that is as simple and direct as possible. The less your code does, the easier it is to read, write and refactor.

Now I know I'm still new to this whole DOP thing, and I'm about as far from being a domain expert on the subject as one can be, but I still think this process was worth sharing. Maybe there are some other programmers in a similar boat as me who will find it interesting.

### Summary

This little venture was surpisingly fun and productive! It gave me some much needed perspective, and I am looking forward to applying the lessons I've learned to future work. 
I have a better understanding of what it feels like to program without unncessary abstraction and will be much more careful about how and when I use it in the future.
