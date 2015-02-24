
#import <UIKit/UIKit.h>
#import "ios_app_delegate.h"

@interface Handmade_application : UIApplication
@end

@implementation Handmade_application

- (void)sendEvent:(UIEvent *)event {
	if ([event type] == UIEventTypeTouches)
        [(App_delegate *)[[UIApplication sharedApplication] delegate] touchEvent:event];
	else
		[super sendEvent: event];
}

@end

int main(int argc, char * argv[]) {
	@autoreleasepool {
		return UIApplicationMain(argc, argv, NSStringFromClass([Handmade_application class]),
				NSStringFromClass([App_delegate class]));
	}
}

