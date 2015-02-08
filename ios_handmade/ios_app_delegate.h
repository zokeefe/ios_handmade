
#ifndef IOS_APP_DELEGATE_H
#define IOS_APP_DELEGATE_H

#import <UIKit/UIKit.h>
#import <AudioUnit/AudioUnit.h>
#import <limits.h>
#import "handmade_platform.h"

// TODO(zach): Make this error proof.
#define IOS_PATH_MAX PATH_MAX

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
// IMPORTANT(zach): Everything above here must be the same layout as game_offscreen_buffer
	float pointToPixelScale;
} ios_offscreen_buffer;

typedef struct {
	size_t totalMemorySize;
	void *memory;
	char writableDataPath[IOS_PATH_MAX];
} ios_state;

// TODO(zach): Need whilst we don't load game code dynamically.
GAME_UPDATE_AND_RENDER(GameUpdateAndRender);
GAME_GET_SOUND_SAMPLES(GameGetSoundSamples);

@interface App_delegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

- (void)touchEvent:(UIEvent *)event;

@end

#endif
