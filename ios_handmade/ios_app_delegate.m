
#import <mach/mach.h>
#import <mach/mach_init.h>
#import <mach/mach_time.h>
#import <mach/vm_map.h>
#import <AudioUnit/AudioUnit.h>
#import <stdint.h>
#import <math.h>
#import <limits.h>
#import <fcntl.h>
#import <sys/stat.h>
#import "ios_app_delegate.h"
#import "handmade_platform.h"

// NOTE(zach): I dont know if alternating buffers is of any benifit since I don't know how 
// Core Animation renders layers. I won't worry about it since I'm switching to OpenGL
// anyways.
//
// HACK(zach): Fixup these globals later
global_variable ios_offscreen_buffer globalBackBuffers[2];
global_variable ios_sound_output globalSoundOutput;
global_variable ios_state globalState;
global_variable ios_input globalInput;
global_variable ios_input_touch globalLastTouch;
global_variable game_memory globalGameMemory;
global_variable CADisplayLink *globalDisplayLink;

#if HANDMADE_INTERNAL
// NOTE(zach): Not for shipping.
//
// TODO(zach): Need to request change to downstream code to include amount of memory
// requesting to be freed in DEBUG_PLATFORM_FREE_MEMORY implementation. 
// I imagine this will be the case in non-debug code. For now, use free(), and malloc()

internal DEBUG_PLATFORM_FREE_FILE_MEMORY(debugPlatformFreeFileMemory) {
	if (Memory) {
		free(Memory);
	}
}

internal DEBUG_PLATFORM_READ_ENTIRE_FILE(debugPlatformReadEntireFile) {
	debug_read_file_result result = {0};

	char path[IOS_PATH_MAX] = {0};
	char *cptr = globalState.writableDataPath;
	size_t pathInd = 0;
	while (pathInd < IOS_PATH_MAX && (path[pathInd] = *(cptr++)) != '\0') ++pathInd; 
	if (pathInd < IOS_PATH_MAX)
		path[pathInd++] = '/';
	cptr = Filename;
	while (pathInd < IOS_PATH_MAX && (path[pathInd] = *(cptr++)) != '\0') ++pathInd;

	int fd;
	if ((fd = open(path, O_RDONLY)) != -1) {
		struct stat fileStat;
		if (fstat(fd, &fileStat) != -1) {
			size_t fileSize = (size_t)fileStat.st_size;
			if ((result.Contents = malloc(fileSize)) != NULL) {
				if (read(fd, result.Contents, fileSize) == fileSize) {
					result.ContentsSize = (uint32_t)fileSize;
				} else {
					debugPlatformFreeFileMemory(Thread, result.Contents);
					result.ContentsSize = 0;
					// TODO(zach): logging
				}
			} else {
				// TODO(zach): logging
			}
		} else {
			// TODO(zach): logging
		}
		close(fd);
	} else {
		// TODO(zach): logging
	}
	return result;
}

internal DEBUG_PLATFORM_WRITE_ENTIRE_FILE(debugPlatformWriteEntireFile) {
	bool result = false;

	int fd = open(Filename, O_WRONLY | O_CREAT, 0644);
	if (fd != -1) {
		ssize_t BytesWritten = write(fd, Memory, MemorySize);
		if (!(result = (BytesWritten == MemorySize))) {
			// TODO(zach): Logging
		}
		close(fd);
	} else {
		// TODO(zach): Logging
	}
	return (bool32)result;
}

#endif

internal void renderTouch(CGContextRef context, ios_input_touch touch) {
	switch (touch.phase) {
	case UITouchPhaseBegan:
	case UITouchPhaseMoved:
	case UITouchPhaseStationary:
		CGContextSetRGBFillColor(context, 1, 1, 0, 0.5);
		Float32 radius = 20.0f;
		CGRect rect = CGRectMake(
				touch.x - radius,
				touch.y - radius,
				radius * 2,
				radius * 2 );
		CGContextFillEllipseInRect(context, rect);
		break;
	case UITouchPhaseEnded:
	case UITouchPhaseCancelled:
	default:
		break;
	}
}

#if 0
internal OSStatus renderSineWave(
		void *inRefCon,
		AudioUnitRenderActionFlags *ioActionFlags,
		const AudioTimeStamp *inTimeStamp,
		UInt32 inOutputBusNumber,
		UInt32 inNumberFrames,
		AudioBufferList *ioData ) {

	ios_sound_output *soundOutput = (ios_sound_output *)inRefCon;

	local_persist double theta = 0;
	const double amplitude = 10000.0;
	double thetaInc = 2.0 * M_PI * globalLastTouch.x / (float)soundOutput->samplesHz;

	uint32_t *buffer = (uint32_t *)ioData->mBuffers[0].mData;

	for (uint32_t sample = 0; sample < inNumberFrames; ++sample) {
		// Just to show writing to the left and right channel
		buffer[sample] = (uint16_t)(sinf(theta) * amplitude) |
			((uint32_t)(sinf(theta) * amplitude) << 16);
		theta += thetaInc;
		theta -= (theta < 2.0 * M_PI) ? 0 : 2.0 * M_PI;
	}
	return noErr;
}
#endif

internal OSStatus getInputSoundSamples(
		void *inRefCon,
		AudioUnitRenderActionFlags *ioActionFlags,
		const AudioTimeStamp *inTimeStamp,
		UInt32 inOutputBusNumber,
		UInt32 inNumberFrames,
		AudioBufferList *ioData ) {

	thread_context thread = {0};
	game_sound_output_buffer gameSoundBuffer;
	gameSoundBuffer.SamplesPerSecond = ((ios_sound_output *)inRefCon)->samplesHz;
	gameSoundBuffer.SampleCount = inNumberFrames;
	gameSoundBuffer.Samples = ioData->mBuffers[0].mData;
	GameGetSoundSamples(&thread, &globalGameMemory, &gameSoundBuffer);
	return noErr;
}

internal OSStatus iosInitAudioUnit(ios_sound_output* soundOutput) {

	OSErr err;

	AudioComponentDescription outputDescr;
	outputDescr.componentType = kAudioUnitType_Output;
	outputDescr.componentSubType = kAudioUnitSubType_RemoteIO;
	outputDescr.componentManufacturer = kAudioUnitManufacturer_Apple;
	outputDescr.componentFlags = 0;
	outputDescr.componentFlagsMask = 0;
	 
	AudioComponent defaultOutput = AudioComponentFindNext(NULL, &outputDescr);
	 
	if ((err = AudioComponentInstanceNew(defaultOutput, &soundOutput->audioUnit)) != noErr)
		return err;
	 
	AURenderCallbackStruct inputCb;
	// TODO(zach): Get samples from game. For now, render a sine wave
	//inputCb.inputProc = renderSineWave; //getInputSoundSamples;
	inputCb.inputProc = getInputSoundSamples;
	inputCb.inputProcRefCon = soundOutput;
	if ((err = AudioUnitSetProperty(
			soundOutput->audioUnit,
			kAudioUnitProperty_SetRenderCallback,
			kAudioUnitScope_Input,
			0,
			&inputCb,
			sizeof(inputCb) )) != noErr) return err;
	
	// IMPORTANT(zach): PCM, stereo, 16bpc, integer samples, interleaved
	AudioStreamBasicDescription streamFormat = {0};
	streamFormat.mSampleRate = soundOutput->samplesHz;
	streamFormat.mFormatID = kAudioFormatLinearPCM;
	streamFormat.mFormatFlags =
			kAudioFormatFlagIsPacked | kAudioFormatFlagIsSignedInteger;
	streamFormat.mBytesPerPacket = (uint32_t)soundOutput->bytesPerPacket;
	streamFormat.mFramesPerPacket = 1;   
	streamFormat.mBytesPerFrame = (uint32_t)soundOutput->bytesPerPacket;
	streamFormat.mChannelsPerFrame = 2;
	streamFormat.mBitsPerChannel = (uint32_t)soundOutput->bytesPerChannelPerPacket * 8;
	err = AudioUnitSetProperty (
			soundOutput->audioUnit,
			kAudioUnitProperty_StreamFormat,
			kAudioUnitScope_Input,
			0,
			&streamFormat,
			sizeof(AudioStreamBasicDescription) );
	return err;
}

internal NSError *iosLoadWritableBundleData(NSString *sourcePath, NSString *destPath) {
	NSFileManager *fs = [NSFileManager defaultManager];
	NSError *error = NULL;
	BOOL destIsDir;
	BOOL destExists = [fs fileExistsAtPath:destPath isDirectory:&destIsDir];
	if (!destExists || !destIsDir) {
		if (![fs createDirectoryAtPath:destPath withIntermediateDirectories:TRUE attributes:nil error:&error]) {
			return error;
		}
	}
	NSArray *contents = [fs contentsOfDirectoryAtPath:sourcePath error:&error];
	if (error)
		return error;

	for (NSString *obj in contents) {
		NSString *objDestPath = [destPath stringByAppendingPathComponent:obj];
		if ([fs fileExistsAtPath: objDestPath]) {
#if HANDMADE_INTERNAL
			if (![fs removeItemAtPath: objDestPath error:&error]) {
				return error;
			}
#else
			continue;
#endif
		}
		if (![fs copyItemAtPath: [sourcePath stringByAppendingPathComponent:obj]
				toPath: objDestPath error:&error] ) {
			return error;
		} else {
			NSLog(@"Loaded: %@\n", objDestPath);
		}
	}
	return error;
}

internal void iosInitInput(ios_input *input, ios_offscreen_buffer *buffer) {

#define ASSERT_BOUNDS(x, y, r) Assert((x) - (r) >= 0) \
	Assert((x) + (r) < buffer->width) \
	Assert((y) - (r) >= 0) \
	Assert((y) + (r) < buffer->height)
	
	const Float32 actionButtonRadius = 45.0;
	const Float32 actionButtonGroupCenterOffsetX = (Float32)buffer->width - 175.0;
	const Float32 actionButtonGroupCenterOffsetY = 175.0;
	const Float32 actionButtonGroupSpreadX = 90.0;
	const Float32 actionButtonGroupSpreadY = 90.0;

	input->actionUp.radius = input->actionDown.radius = input->actionLeft.radius =
		input->actionRight.radius = actionButtonRadius;

	input->actionUp.centerX = actionButtonGroupCenterOffsetX;
	input->actionUp.centerY = actionButtonGroupCenterOffsetY + actionButtonGroupSpreadY;
	ASSERT_BOUNDS(input->actionUp.centerX, input->actionUp.centerY, input->actionUp.radius)

	input->actionDown.centerX = actionButtonGroupCenterOffsetX;
	input->actionDown.centerY = actionButtonGroupCenterOffsetY - actionButtonGroupSpreadY;
	ASSERT_BOUNDS(input->actionDown.centerX, input->actionDown.centerY, input->actionDown.radius)

	input->actionLeft.centerX = actionButtonGroupCenterOffsetX - actionButtonGroupSpreadX;
	input->actionLeft.centerY = actionButtonGroupCenterOffsetY;
	ASSERT_BOUNDS(input->actionLeft.centerX, input->actionLeft.centerY, input->actionLeft.radius)

	input->actionRight.centerX = actionButtonGroupCenterOffsetX + actionButtonGroupSpreadX;
	input->actionRight.centerY = actionButtonGroupCenterOffsetY;
	ASSERT_BOUNDS(input->actionRight.centerX, input->actionRight.centerY, input->actionRight.radius)

	input->joystick.centerX = 175.0;
	input->joystick.centerY = 175.0;
	input->joystick.radius = 100.0;
	ASSERT_BOUNDS(input->joystick.centerX, input->joystick.centerY, input->joystick.radius);
}

internal void iosRenderInputHud(CGContextRef context, ios_offscreen_buffer *buffer, ios_input *input) {
	CGContextSetRGBFillColor(context, 0.0, 0.0, 1.0, 0.75);
	CGContextSetRGBStrokeColor(context, 0.0, 0.0, 1.0, 0.75);
	CGContextSetLineWidth(context, 3.0);
	for (size_t i = 0; i < ArrayCount(input->buttons); ++i) {
		ios_input_round_button button = input->buttons[i];
		CGRect rect = CGRectMake(
				button.centerX - button.radius,
				button.centerY - button.radius,
				button.radius * 2,
				button.radius * 2 );
		if (button.isDown)
			CGContextFillEllipseInRect(context, rect);
		else
			CGContextStrokeEllipseInRect(context, rect);
	}	
	CGRect rect = CGRectMake(
			input->joystick.centerX - input->joystick.radius,
			input->joystick.centerY - input->joystick.radius,
			input->joystick.radius * 2,
			input->joystick.radius * 2 );
	CGContextStrokeEllipseInRect(context, rect);

	ios_input_joystick *joystick = &input->joystick;
	if (joystick->stickX != 0 || joystick->stickX != 0) {
#define stickRadius 80.0
		Assert(stickRadius < joystick->radius)
		Float32 radiusDiff = joystick->radius - stickRadius;
		rect = CGRectMake(
				joystick->centerX + joystick->stickX * radiusDiff - stickRadius,
				joystick->centerY + joystick->stickY * radiusDiff - stickRadius,
				stickRadius * 2,
				stickRadius * 2 );
		CGContextFillEllipseInRect(context, rect);
	}

}

internal void iosProccessRoundButtonInput(ios_input_round_button *button, ios_input_touch *touches,
		size_t numTouches) {
	ios_input_touch touch;
	bool buttonPress = false;
	for (size_t i = 0;  !buttonPress && i < numTouches; ++i) {
		touch = touches[i];
		Float32 dX = (button->centerX - touch.x);
		Float32 dY = (button->centerY - touch.y);
		Float32 distance = sqrt(dX * dX + dY * dY);
		if (distance - button->radius - touch.radius < 0) {
			switch (touch.phase) {
			case UITouchPhaseBegan:
			case UITouchPhaseMoved:
			case UITouchPhaseStationary:
				buttonPress = true;
				break;
			case UITouchPhaseEnded:
			case UITouchPhaseCancelled:
			default:
				break;
			}
		}
	}
	button->halfTransitionCount += button->isDown == buttonPress ? 0 : 1;
	button->isDown = buttonPress;
}

internal inline void mapButtonInputToGameInput(ios_input_round_button *iosButton,
		game_button_state *gameButton) {
	gameButton->HalfTransitionCount = iosButton->halfTransitionCount;
	gameButton->EndedDown = iosButton->isDown;
}

internal void mapInputToGame(ios_input *iosInput, game_input *gameInput) {
	game_controller_input *controller = &gameInput->Controllers[0];			
	controller->IsConnected = true;
	
	mapButtonInputToGameInput(&iosInput->actionUp, &controller->ActionUp);
	mapButtonInputToGameInput(&iosInput->actionDown, &controller->ActionDown);
	mapButtonInputToGameInput(&iosInput->actionLeft, &controller->ActionLeft);
	mapButtonInputToGameInput(&iosInput->actionRight, &controller->ActionRight);
	mapButtonInputToGameInput(&iosInput->leftShoulder, &controller->LeftShoulder);
	mapButtonInputToGameInput(&iosInput->rightShoulder, &controller->RightShoulder);
	mapButtonInputToGameInput(&iosInput->back, &controller->Back);
	mapButtonInputToGameInput(&iosInput->start, &controller->Start);
#if 0
	// TODO(zach): Switch this to analog when the game supports it
	controller->IsAnalog = true;
	controller->StickAverageX = iosInput->joystick.stickX;
	controller->StickAverageY = iosInput->joystick.stickY;
#else
	Float32 threshhold = 0.2;
	controller->IsAnalog = (bool32)false;
	if (iosInput->joystick.stickX >= threshhold) {
		controller->MoveRight.EndedDown = (bool32)true;
		controller->MoveRight.HalfTransitionCount = 1;
	} else {
		controller->MoveRight.EndedDown = (bool32)false;
		controller->MoveRight.HalfTransitionCount = 0;
	}

	if (iosInput->joystick.stickX <= -threshhold) {
		controller->MoveLeft.EndedDown = (bool32)true;
		controller->MoveLeft.HalfTransitionCount = 1;
	} else {
		controller->MoveLeft.EndedDown = (bool32)false;
		controller->MoveLeft.HalfTransitionCount = 0;
	}

	if (iosInput->joystick.stickY >= threshhold) {
		controller->MoveUp.EndedDown = (bool32)true;
		controller->MoveUp.HalfTransitionCount = 1;
	} else {
		controller->MoveUp.EndedDown = (bool32)false;
		controller->MoveUp.HalfTransitionCount = 0;
	}

	if (iosInput->joystick.stickY <= -threshhold) {
		controller->MoveDown.EndedDown = (bool32)true;
		controller->MoveDown.HalfTransitionCount = 1;
	} else {
		controller->MoveDown.EndedDown = (bool32)false;
		controller->MoveDown.HalfTransitionCount = 0;	
	}
#endif
}

@implementation App_delegate

- (void)touchEvent:(UIEvent *)event {
	NSArray *allTouches = [[event allTouches] allObjects];

// TODO(zach): Find right answer for this
#define MAX_TOUCHES 10

	// TODO(zach): Need to figure out if the touches returned by this function
	// are just the touches that changed, or if they include all active touches.
	ios_input_touch touchInputs[MAX_TOUCHES];
	size_t touchNum = 0;
	for (UITouch *touch in allTouches) {
			CGPoint loc = [touch locationInView:nil];
			touchInputs[touchNum].x = loc.x * globalState.pointToPixelScale;
			touchInputs[touchNum].y = globalBackBuffers[0].height - loc.y * globalState.pointToPixelScale;
			touchInputs[touchNum].radius = (touch.majorRadius + touch.majorRadiusTolerance) *
				globalState.pointToPixelScale;
			touchInputs[touchNum].phase = touch.phase;
			globalLastTouch = touchInputs[touchNum];
			NSLog(@"(%f, %f)\n", touchInputs[touchNum].x, touchInputs[touchNum].y);
			++touchNum;
	}

	for (size_t i = 0; i < ArrayCount(globalInput.buttons); ++i)
		iosProccessRoundButtonInput(&globalInput.buttons[i], touchInputs, touchNum);

	Float32 extraStickToleranceRadius = 200.0;
	ios_input_joystick *joystick = &globalInput.joystick;
	bool joystickActive = false;
	for (size_t i = 0; i < touchNum; ++i) {
		ios_input_touch touch = touchInputs[i];
		Float32 dX = (touch.x - joystick->centerX);
		Float32 dY = (touch.y - joystick->centerY);
		Float32 distance = sqrt(dX * dX + dY * dY);
		if (distance - joystick->radius - touch.radius - extraStickToleranceRadius < 0) {
			Float32 scaleFactor = distance <= joystick->radius ?
				joystick->radius : distance;
			switch (touch.phase) {
			case UITouchPhaseBegan:
			case UITouchPhaseMoved:
			case UITouchPhaseStationary:
				joystick->stickX = dX / scaleFactor;
				joystick->stickY = dY / scaleFactor;
				joystickActive = true;
				break;
			case UITouchPhaseEnded:
			case UITouchPhaseCancelled:
				break;
			default:
				break;
			}
		}
	}
	if (!joystickActive)
		joystick->stickX = joystick->stickY = 0.0;
}

- (void)doFrame:(CADisplayLink *)sender {
	local_persist size_t bufferNo = 0;

	ios_offscreen_buffer activeBuffer = globalBackBuffers[bufferNo ^= 1];

	// TODO(zach): Should we use CGColorSpaceCreateCalibratedRGB() ?
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

	// IMPORTANT(zach): 32bpp, 8bpc, ARGB, premultiplied alpha, little endian.
	// Left channel is the lower 16 bits, right is the higher 16 bits.
	CGContextRef context = CGBitmapContextCreate(
			activeBuffer.memory,
			activeBuffer.width,
			activeBuffer.height,
			8,
			activeBuffer.pitch,
			colorSpace,
			(CGBitmapInfo)(kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little) );
	
	CGColorSpaceRelease(colorSpace);

	if (context) {
		CGContextSetRGBFillColor(context, 0, 0, 0, 1);
		CGContextFillRect(context, CGRectMake(0, 0, activeBuffer.width, activeBuffer.height));

		thread_context thread = {0};

		game_offscreen_buffer gameBuffer;
		gameBuffer.Memory = activeBuffer.memory;
#define HANDMADE_PIXEL_WIDTH 960
#define HANDMADE_PIXEL_HEIGHT 540 
		// NOTE(zach): Casey's software renderer does not scale right now. It expects
		// a 960x540 pixel buffer to render into
		gameBuffer.Width = MIN(HANDMADE_PIXEL_WIDTH, activeBuffer.width);
		gameBuffer.Height = MIN(HANDMADE_PIXEL_HEIGHT, activeBuffer.height);;
		gameBuffer.Pitch = activeBuffer.pitch;
		gameBuffer.BytesPerPixel = activeBuffer.bytesPerPixel;

		game_input gameInput = {0};
		mapInputToGame(&globalInput, &gameInput);

		local_persist uint64_t last = 0;
		local_persist real32 machToNano = 0.0;
		uint64_t now = mach_absolute_time();
		if (machToNano == 0.0 ) {
			mach_timebase_info_data_t sTimebaseInfo;
			mach_timebase_info(&sTimebaseInfo);
			machToNano = (real32)sTimebaseInfo.numer / (real32)sTimebaseInfo.denom;
		}
#define NANOSECONDS_PER_S 1000000000 
		gameInput.dtForFrame = (real32)(now - last) * machToNano / (real32)NANOSECONDS_PER_S;
		last = now;

		GameUpdateAndRender(&thread, &globalGameMemory, &gameInput, &gameBuffer);
		iosRenderInputHud(context, &activeBuffer, &globalInput);
		renderTouch(context, globalLastTouch);

		// NOTE(zach): For now, blit the bitmap returned by game code directly to screen.
		// I.e. don't scale the image to fit screen. Not that it would be hard to do so,
		// but because 1->1 byte to pixel mapping is usefull during development, and I'm
		// not sure if Casey will be doing scaling in his software render.
		CGImageRef image = CGBitmapContextCreateImage(context);
		CGContextRelease(context);

		// NOTE(zach): Initial testing shows this is faster than drawRect: or drawLayer:InContext:
		self.window.layer.contents = (id)image;

		// layer.contents is strong reference so can release immidiatly
		CGImageRelease(image);
	} else {
		NSLog(@"Couldn't create graphics context\n");
		// TODO(zach): logging
	}
}

- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

	NSString *sourcePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"data"];
	NSString *destPath = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) firstObject];
	// TODO(zach): Probably don't need to do this everytime.
	NSError *loadErr = iosLoadWritableBundleData(sourcePath, destPath);
	if (loadErr) {
		// TODO(zach): Logging.
	}
	if (![destPath getCString:globalState.writableDataPath
			maxLength:ArrayCount(globalState.writableDataPath)
			encoding:NSASCIIStringEncoding]) {
		// TODO(zach): Logging.
	}

	// NOTE(zach): Set frame after window gets it's orientation. When landscape app is ran
	// from portrait, need to do this so window has the right frame.
	//
	// http://stackoverflow.com/questions/25963101/unexpected-nil-window-in-uiapplicationhandleeventfromqueueevent
	self.window = [[UIWindow alloc] init];
	[self.window makeKeyAndVisible];
	self.window.frame = [[UIScreen mainScreen] bounds];

    self.window.rootViewController = [[UIViewController alloc] init];
    
	// IMPORTANT(zach): Make sure there exists a launch screen for the suitable device. If you don't
	// have a launch screen for a particular screen size, Apple interprets this as your app not
	// supporting that screen size, and will launch in letterbox mode.

	globalState.pointToPixelScale = [UIScreen mainScreen].scale;
	CGSize screen = [[UIScreen mainScreen] nativeBounds].size;
	int pixelWidth = (int)(screen.width + 0.5);
	int pixelHeight = (int)(screen.height + 0.5);
	if (pixelWidth < pixelHeight) {
		int tmp = pixelWidth;
		pixelWidth = pixelHeight;
		pixelHeight = tmp;
	}
	int bytesPerPixel = 4;

	globalBackBuffers[0].height = pixelHeight;
	globalBackBuffers[0].width = pixelWidth;
	globalBackBuffers[0].bytesPerPixel = bytesPerPixel;
	globalBackBuffers[0].pitch = pixelWidth * bytesPerPixel;
	globalBackBuffers[1] = globalBackBuffers[0];

	globalGameMemory.PermanentStorageSize = Megabytes(64);
	globalGameMemory.TransientStorageSize = Megabytes(64);
	globalGameMemory.IsInitialized = (bool32)false;

#if HANDMADE_INTERNAL
	globalGameMemory.DEBUGPlatformFreeFileMemory = debugPlatformFreeFileMemory;
	globalGameMemory.DEBUGPlatformReadEntireFile = debugPlatformReadEntireFile;
	globalGameMemory.DEBUGPlatformWriteEntireFile = debugPlatformWriteEntireFile;
#endif

	int bitmapSize = pixelWidth * pixelHeight * bytesPerPixel;

	globalState.totalMemorySize = 
		globalGameMemory.PermanentStorageSize +
		globalGameMemory.TransientStorageSize +
		bitmapSize * 2;

	// TODO(zach): Prefer this over mmap() ?
	vm_address_t baseAddress;
	kern_return_t result = vm_allocate(
			(vm_map_t)mach_task_self(), 
			&baseAddress,
			(vm_size_t)(globalState.totalMemorySize),
			(boolean_t)true );
	if (result != KERN_SUCCESS) {
		// TODO(zach): logging
	}

	// NOTE(zach): vm_allocate() initializes pages to 0 as required by game code
	globalGameMemory.PermanentStorage = (void *)baseAddress;
	globalGameMemory.TransientStorage = (void *)(baseAddress +
			globalGameMemory.PermanentStorage);
	globalBackBuffers[0].memory = (void *)(baseAddress +
			globalGameMemory.PermanentStorageSize +
			globalGameMemory.TransientStorageSize);
	globalBackBuffers[1].memory = (void *)(baseAddress +
			globalGameMemory.PermanentStorageSize +
			globalGameMemory.TransientStorageSize +
			bitmapSize);

	globalSoundOutput.samplesHz = 44100;
	globalSoundOutput.bytesPerChannelPerPacket = sizeof(uint16_t);
	globalSoundOutput.bytesPerPacket = 2 * sizeof(uint16_t);

	OSErr soundErr;
	if ((soundErr = iosInitAudioUnit(&globalSoundOutput)) != noErr) {
		// TODO(zach): Logging
	} else if ((soundErr = AudioUnitInitialize(globalSoundOutput.audioUnit)) != noErr) {
		// TODO(zach): Logging
	} else if ((soundErr = AudioOutputUnitStart(globalSoundOutput.audioUnit)) != noErr ) {
		// IDEA(zach): Maybe manually ask AudioUnit to render? That way we can sync with
		// drawing and provide our own memory
		//
		// TODO(zach): Logging
	}

	iosInitInput(&globalInput, &globalBackBuffers[0]);

	// NOTE(zach): Testing looks like CADisplayLink waits for vsync.
	// Regardless of frameInterval, if you miss a frame, CADisplayLink will be
	// called on next possible vsync - even if it is not a multiple of frameInterval.
	//
	// TODO(zach): Need to look more into what CADisplayLink does when we miss a frame, since
	// potentially can be wasting a lot of time waiting for vsync if we overshoot
	// our frame by just a little.
	//
	// http://www.gamasutra.com/blogs/KwasiMensah/20110211/88949/Game_Loops_on_IOS.php
	globalDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(doFrame:)];
	globalDisplayLink.frameInterval = 2;
	[globalDisplayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];

	return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
	// Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
	// Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
	// Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
	// If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
	// Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
	// Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
	// Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end


