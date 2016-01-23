# ios_handmade
Ongoing iOS port of Casey Muratori's awesome [Handmade Hero](https://handmadehero.org/) project.

### Goals
1. To learn about the iOS platform
2. To be able to drop-in Casey's platform-independent game source code and have it run unchanged

### Current status - Day 69

![screenshot](/screenshots/day69.png)

- [x] CoreAudio sound
- [x] Quartz graphics. Currently blitting game buffer directly to screen without scaling.
- [x] UIKit touch input
- [ ] OpenGLES graphics
- [X] Live-loop replays
- [ ] Live-loop editing. So iOS 9 *does* support dynamic libraries; however, for the platform layer to have visability of a newly-compiled game library, we have to be running on Simulator (and even then, not sure if it's possible).

Code is still just debug-quality.

### Prerequisites
* Preorder of Handmade Hero! This is possibly the coolest game project ever, and is the only way to get access to the source code which you'll need to build this game. Handmade Hero can be preordered from the project's main site here ([https://handmadehero.org/](https://handmadehero.org/))
* A Mac with Xcode and the latest SDK (current 9.2)

### How-to (Changes from last update)
1. Clone this repository with `clone --recursive`. This will also clone Casey's GitHub repo into the **handmade/** directory (*if you have access!*)
2. Unzip the game's assets into **handmade/data/**.
3. Build using Xcode and run on the Simulator (or on a device if you have an iOS Developers Membership). I don't know how to run iOS app any other way other than through Xcode. Depending on the day you're building, you may have to manually add/remove compile targets and files from the project. Currently, the project is setup for day 69.

### Directory structure ###

```
ios_handmade/ios_handmade - my code
ios_handmade/handmade/code - Casey's code
ios_handmade/handmade/data - Casey's unzipped data
```

### Controls ###
* Analog left-thumbstick maps to movement
* 4 blue buttons on lower-right map to Action[Up/Down/Left/Right]
* 2 blue buttons on top-left map to Back/Start
* Red button in top-right is for live-loop replay recording and playback

### Licensing
Casey Muratori is the author of Handmade Hero. I am writing this port with his permission. Please checkout the project here ([https://handmadehero.org/](https://handmadehero.org/)).

### Contributing
This is my first OS project - I'm doing this for fun, to learn about the iOS platform. If you have any thoughts, concerns, tips or tricks, feel free to contact me at [zach@okeefe.io](mailto:zach@okeefe.io).
