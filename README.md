# bomb-golf

A golf game for the original Game Boy

## What does it do?

The game is very incomplete currently. Right now, it drops you in a course, and you can take swings, interact with some terrain, and curve your shot. On the green, your shots become more precise, but now there are slopes to contend with.

## Where are the bombs?
Currently, there are no bombs. To give you the full story, I'll tell you how this game was imagined:

Nintendo's 'Golf' on the NES is really simple, which makes it fun to play with friends in local multiplayer, even if just by passing a phone around. It's got some neat ideas too: you're intentionally restricted to 16-direction aiming, but if you mistime your shot, the ball will curve. I like how it's possible to intentionally do this to aim more precisely than would otherwise be posssible, and I've recreated that here. The only problem? It's kinda boring... 

The vision for bomb-golf was to keep those great things about NES Golf (simplicity, pass & play multiplayer, neat shot mechanics) and add a heavy dose of chaos to the mix with bombs. Each player would be given a number of bombs that they could hit using the same golf mechanics as with regular bombs. There would not only knock opponents from their position, but also leave massive software-rendered craters as enviornmental hazards.

Will these things ever get implemented? Idk, probably not...

# Setting up

This project has way too many build dependencies. You'll need:
 - RGBDS (at least version 0.6.0)
 - make
 - Python 3
 - superfamiconv (TODO: investivate whether this is still nescessary with new RGBGFX features)
 - tmxrasterizer (a utility bundled with Tiled)
 - idk maybe I'm forgetting something. Let me know if you have troubles.


## Compiling

Simply open you favorite command prompt / terminal, place yourself in this directory (the one the Makefile is located in), and run the command `make`. This should create a bunch of things, including the output in the `bin` folder.

I use WSL to compile the project on my machine. If you're on Windows, I'd recommend that too.

If you get errors that you don't understand, try running `make clean`. If that gives the same error, try deleting the `deps` folder. If that still doesn't work, try deleting the `bin` and `obj` folders as well. If that still doesn't work, ask me, I pobably messed up.

## See also
This is based on the amazing gb-starter-kit by ISSOtm. I'd highly recommend it for any Game Boy project.

I recommend the Emulicious emulator for developing and testing, the debugging features are amazing, and it's extremely accurate.

I used a lot of other tools including:
 - PB8 and PB16 compression by PinoBatch
 - The Title Checksum Hack (titchack.py) by Basxto
 - `romusage` by bbbbbr
 and probably more. You're all awesome!