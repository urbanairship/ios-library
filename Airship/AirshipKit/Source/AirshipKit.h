
#import <UIKit/UIKit.h>

//! Project version number for AirshipKit.
FOUNDATION_EXPORT double AirshipKitVersionNumber;

//! Project version string for AirshipKit.
FOUNDATION_EXPORT const unsigned char AirshipKitVersionString[];

#import "AirshipCore.h"

#if !TARGET_OS_TV
#import "AirshipAutomation.h"
#import "AirshipMessageCenter.h"
#import "AirshipExtendedActions.h"
#endif
