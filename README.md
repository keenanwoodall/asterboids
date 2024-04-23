# Asterboids
A simple space-shooter reminiscent of the classic arcade game, Asteroids. The game was a week(ish) long project, with the goal of learning the [Odin](https://odin-lang.org/) language and data-oriented-programming.

__This README will serve as a summary of an OOP-pilled Unity developer's introduction to data-oriented thinking.__

### Why Odin? Why Data-Oriented?
Odin is a system-level programming language with a design that focuses on simplicity, performance and "the joy of programming."

Sounds interesting, right? Well as someone who has been writing primarily object-oriented C# code my entire career I admit I was afraid I would bounce off the language. 
However, to my surprise the exact opposite occured. Unlike my previous forays into other languages like C++ and Rust, I got completely hooked by Odin.
It was a perfect storm... in a good way. 

Over the last few years I've been becoming more atuned to the fact that _something_ about programming hasn't been feeling right. Writing good code has always been very important to me, but despite my best efforts I have rarely (if ever) felt that I've achieved that goal on projects of even moderate complexity. 
For a long time I just accepted that I was either overengineering or being a perfectionist and hoped it would get better with time and effort. It definitely has to an extent, but the sentiment remaines. However, over the last few months I've had time to really step outside of my "bubble" and get a new perspective on how to approach writing software. 

It's not like I've been ignorant to other paradigms like data-oriented programming - I've seen many of the well-known [talks](https://youtu.be/rX0ItVEVjHc) and [video essays](https://youtu.be/QM1iUe6IofM?list=PLrWlVANGG-ij06UCpfdxQ-LBclsWUDLt-) that make a case against object-oriented programming.
They were quite compelling to me, but I didn't feel like I could employ DOP in a meaningful way with my work in Unity. This is of course not true, but in an environment like Unity where everything is object-oriented, using DOP to a significant degree involves going against the grain. 
It can be done, but I don't think it's an ideal environment to learn DOP.

Unity has been working on its Data Oriented Tech Stack (DOTS) for many years, and I have used their job-system heavily which rewards thinking about your program from a data perspective. 
However, Unity's DOTS does a lot of "magic" to run your code and it was hard to make a distinction between Unity's implementation of ECS and the more general principles of DOP. I appreciate what it's doing, but I wanted to dig into DOP in a "pure" environment where the only code that's running is the code I wrote.

My disenchantment with OOP and Unity was growing alongside my blossoming interest in DOP so I was especially motivated to get out of my comfort zone. 
As part of my research, I had been watching Jonathan Blow's [Programming Language For Video Games](https://www.youtube.com/playlist?list=PLmV5I2fxaiCKfxMBrNsU1kgKJXD3PkyxO) series. 
Seeing his process of designing and implementing his language "Jai" gave me more insight into the "why" and "how" of a data-focused language.
Like many others I sent an email requesting access to the language beta, but I wasn't holding my breath. I hoped that if I could find a language with similar goals I could get up and running quite quickly. That's when I found Odin!

### First Steps
I have never _properly_ used a low-level language. So in my eyes, the fact that **within an hour** of downloading Odin - a language I'd never used - I was drawing graphics to a window is a major testament to one of Odin's principles: simplicity.
You can start writing code that actually does something cool in less than a day, and feel quite comfortable with the language in less than a week. Seriously. It sure doesn't hurt that Odin comes with official integrations for many popular libraries and all the major graphics APIs.

Now I'm not going to claim that I immediately understood everything about Odin. I had my fair share of nooby moments (and still do!) Odin's three array types took me a bit to digest. I was also initially confused as to why Odin's Raylib package worked without adding any DLLs to my project files, but _not_ SDL.
Someone on the Odin discord server also kindly pointed out that I was allocating way more things on the heap than was necessary. I saw all of these speed-bumps as natural growing pains.

However, one thing that left a bit to be desired is tooling. Unity and C# have excellent IDE support: auto-complete, refactoring, and attaching a debugger "just works." While the Odin Language Server (ols) is pretty easy to setup and handles the basics, 
I miss certain things I would consider basic functionality like being able to rename a variable across a project.

All that being said, using Odin has been quite a positive experience for me. It provides a buttery smooth entry into the world of low-level data-oriented programming, which I think is largely due to the small number of concepts you need to grok to get started.
This is huge for the learning process because it avoids a "combinatorial explosion" of potential feature interactions, making Odin incredibly easy to read and write.

### Fearless Manual Memory Management
I think a lot of people who have exclusively programmed in garbage collected languages can agree that manual memory management is intimidating. "You're telling me I have to remember to free _everything_!?" 

While you do manage memory manually (try saying that 5 times fast), I found that in practice Odin bears the brunt of the effort, leaving you with all the advantages of manual memory management without the headache.

The first tool Odin puts in your toolbelt is the `defer` keyword. You can use it to "defer" any statement to the end of the current scope. Simple as that.
This is not unique to Odin, but it was pretty novel to me! Deferring allows you to put the code that cleans something up right below the code that initializes it.
```js
big_array := make([]int, 1000000)
defer delete(big_array) // this will get called no matter what!
```
It lets you see at a glance that you've done your housekeeping correctly, rather than scrolling all over the place to make sure every `new` at the top of a function was paired with a `free` at the bottom. 
It also provides definitiveness that no early `return` or other jump in control flow will circumvent a deferred statement. It's a dead simple construct that provides a ton of value.

The next tool in your memory management toolbelt is Odin's allocators. Allocators are a major feature of Odin. As the name implies they provide functionality to allocate memory in various ways.
Not only can you use them to have more control over how _your_ code allocates memory, but how _external_ code allocates as well; using Odin's implicit `context` system. 
There's one allocator in particular that I think is brilliant: Odin's `temp_allocator`. Often times you have some ephemeral data you want to allocate that doesn't need to last for more than a frame.
It can feel a bit long-winded to manually free each of these allocations when you _know_ they're all temporary. Why not just...free those temporary allocations all at once?
The `temp_allocator` makes this super simple. Just use `context.temp_allocator` for temporary allocations and call `free_all(context.temp_allocator)` at the end of your frame. Easy peasy!

While the `temp_allocator` can really lighten the mental load of making small allocations throughout the code-base, how can you be _sure_ that you don't have any leaks?
At one point I was positive I had a big leak in Asterboids, but I couldn't track it down for the life of me. Eventually out of desperation I opened the Odin language [overview](https://odin-lang.org/docs/overview/) and hit Ctrl+F to see if "leak" was mentioned anywhere.
It took me straight to a 20 line example snippet that hooks up the built-in `mem.tracking_allocator` which tracks every allocation and free to make sure you don't have any leaks or incorrect frees. 
I pasted the snippet at the entry point of my game, ran it, and it printed the line number of two different places I had allocated memory that was never freed. Mind blown! Now that's a powerful feature.

When I first started getting into Odin, I was really steeling myself for a world of hurt as I acclimated to the world of manual memory management. I'm happy to report it really wasn't an issue. 
I'm sure there's plenty of places where what I'm doing is suboptimal, but that's bound to happen as I learn the ropes.

### OOPsy Daisy

I must admit, I would feel embarassed about all the mind-numbing work I've done to accomodate OOP in the past, but I know I'm not the only one, and any embarassment is largely eclipsed by a feeling of catharsis.

When writing OOP code in a language like C#, I have so many options for how I architect my program. Abstraction is so easy, that I can't help but wonder about all the vague things I want to ensure my program can handle. 
Having an aresenal of language features that encourage you to plan for an unpredictable future opens the door to a lot of questions that you can't _really_ answer, which results in you throwing abstraction at uncertainty.
In this way, overengineering a problem with OOP is seductively easy. It always feels great at first, like you're doing good work, but when the problem inevitably changes, all the abstractions you put in place turn on you!
All this flexibility you encoded into your architecture is really just a bunch of abitrary barriers. As soon as the problem doesn't fit the abstract mould you made for it, your carefully constructed house of cards falls apart.
True flexibility is writing code that is as simple and direct as possible. The less your code does, the easier it is to read, write and refactor.

Making a tiny game with Odin _forced_ me to discard what I felt were the essential building blocks of a program. I had been clinging to the familiar because it was how my brain understood code. Until recently I couldn't really imagine how I would architect programs any differently.
When I finally started solving problems and implementing features without all the object-oriented bells and whistles I was accustomed to, it quickly became clear to me that I had been making mountains out of molehills. I didn't need to translate my understanding of OOP to DOP, I simply needed to let it go.
It was as if I was the guy flourishing a scimitar in Raiders Of The Lost Ark, with all my interfaces and virtual functions, when most of the code was entirely superfluous.

Now I know I'm still new to this whole DOP thing, and I'm about as far from being a domain expert on the subject as one can be, but I still think this process was worth sharing. Worst case scenario, this will be a fun virtual time-capsule that I can check back in on in the future :)
