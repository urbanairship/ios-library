/* Copyright 2010-2019 Urban Airship and Contributors */

#import "UARateAppActionPredicate+Internal.h"
#import "UARateAppAction.h"
#import "UAirship.h"

@implementation UARateAppActionPredicate

- (BOOL)applyActionArguments:(UAActionArguments *)args {
    return (BOOL)(args.situation != UASituationForegroundPush);
}

@end
