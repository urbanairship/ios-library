#define UA_USE_AIRSHIP_IMPORT 1

#import <UIKit/UIKit.h>

//! Project version number for Airship.
FOUNDATION_EXPORT double AirshipVersionNumber;

//! Project version string for Airship.
FOUNDATION_EXPORT const unsigned char AirshipKitVersionString[];

#import "AirshipLib.h"

#if !TARGET_OS_TV
#import "AirshipAutomationLib.h"
#import "AirshipMessageCenterLib.h"
#import "AirshipExtendedActionsLib.h"
#endif
