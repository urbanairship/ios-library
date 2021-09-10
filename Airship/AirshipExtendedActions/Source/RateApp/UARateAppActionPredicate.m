/* Copyright Airship and Contributors */

#import "UARateAppActionPredicate+Internal.h"
#import "UARateAppAction.h"

#if __has_include("Airship/Airship-Swift.h")
#import <Airship/Airship-Swift.h>
#elif __has_include("Airship-Swift.h")
#import "Airship-Swift.h"
#else
@import AirshipCore;
#endif

@implementation UARateAppActionPredicate

- (BOOL)applyActionArguments:(UAActionArguments *)args {
    return (BOOL)(args.situation != UASituationForegroundPush);
}

@end
