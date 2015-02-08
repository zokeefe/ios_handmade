# ios_handmade
Ongoing iOS port of Casey Muratori's awesome [Handmade Hero](https://handmadehero.org/) project.

### Goals
1. To learn about the iOS platform
2. To be able to drop-in Casey's platform-independent game source code and have it run unchanged

### Current status - Day 40 (Not working)

![screenshot](/screenshots/day40.png)

Currently using:

* CoreAudio for sound
* Quartz for graphics
* UIKit touches for input (not yet working, still need to map input)

TODO:

* Switch to OpenGLES
* Support live-loop replays
* Find out if live code update is possible on iOS. iOS 8 *does* support dynamic libraries, but don't know how to load the recompiled game library into the device mid-exection

### Prerequisites
* Preorder of Handmade Hero! This is possibly the coolest game project ever, and is the only way to get access to the source code which you'll need to build this game. Handmade Hero can be preordered from the project's main site here ([https://handmadehero.org/](https://handmadehero.org/))
* A Mac with Xcode and the latest SDK

### How-to
1. Clone or update this repository
2. Copy over Casey's platform-independent game source code into the top-level **handmade/** directory
3. Unzip the game's assets directly to the top-level **data/** directory as-is. Don't flatten the paths. For example, if `test/test_background.bmp` is an unzipped asset, it's path after copying should be `ios_handmade/data/test/test_background.bmp`
4. Build using Xcode and run on the Simulator (or on a device if you have an iOS Developers Membership). I don't know how to run iOS app any other way other than through Xcode

### Licensing
Casey Muratori is the author of Handmade Hero. I am writing this port with his permission. Please checkout the project here ([https://handmadehero.org/](https://handmadehero.org/)).

### Contributing
This is my first (real) iOS project - I'm doing this for fun, to learn about low-level iOS game programming. If you have any thoughts, concerns, tips or tricks, feel free to contact me at [zach@okeefe.io](mailto:zach@okeefe.io).
