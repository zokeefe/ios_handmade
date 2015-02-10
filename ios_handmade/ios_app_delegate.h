
#ifndef IOS_APP_DELEGATE_H
#define IOS_APP_DELEGATE_H

#import <UIKit/UIKit.h>
#import <AudioUnit/AudioUnit.h>
#import <limits.h>
#import "handmade_platform.h"

// TODO(zach): Make this error proof.
#define IOS_PATH_MAX PATH_MAX

#define MAX(x, y) (x) > (y) ? (x) : (y)
#define MIN(x, y) (x) < (y) ? (x) : (y)

typedef struct {
	int samplesHz;
	size_t bytesPerChannelPerPacket;
	size_t bytesPerPacket;
	AudioComponentInstance audioUnit;
} ios_sound_output;

typedef struct {
	void *memory;
	int width;
	int height;
	int pitch;
	int bytesPerPixel;
} ios_offscreen_buffer;

typedef struct {
	size_t totalMemorySize;
	void *memory;
	char writableDataPath[IOS_PATH_MAX];
	float pointToPixelScale;
} ios_state;

typedef struct {
	Float32 centerX;
	Float32 centerY;
	Float32 radius;
	bool isDown;
	int halfTransitionCount;
} ios_input_round_button;

typedef struct {
	Float32 centerX;
	Float32 centerY;
	Float32 radius;
	// NOTE(zach): Stick X,Y in range of [-1.0, 1.0]
	Float32 stickX;
	Float32 stickY;
} ios_input_joystick;

typedef struct {
	Float32 x;
	Float32 y;
	Float32 radius;
	UITouchPhase phase;
} ios_input_touch;

typedef struct {
	ios_input_joystick joystick;

	union {
		ios_input_round_button buttons[8];
		struct {
			ios_input_round_button actionUp;
			ios_input_round_button actionDown; 
			ios_input_round_button actionLeft;
			ios_input_round_button actionRight;

			ios_input_round_button leftShoulder;
			ios_input_round_button rightShoulder;

			ios_input_round_button back;
			ios_input_round_button start;
		};
	};
} ios_input;

// TODO(zach): Need whilst we don't load game code dynamically.
GAME_UPDATE_AND_RENDER(GameUpdateAndRender);
GAME_GET_SOUND_SAMPLES(GameGetSoundSamples);

@interface App_delegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

- (void)touchEvent:(UIEvent *)event;

@end

#endif
