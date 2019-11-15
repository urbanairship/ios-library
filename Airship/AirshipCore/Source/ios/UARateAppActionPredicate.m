/* Copyright Airship and Contributors */

#import "UARateAppActionPredicate+Internal.h"
#import "UARateAppAction.h"
#import "UAirship.h"

@implementation UARateAppActionPredicate

+ (instancetype)predicate {
    return [[self alloc] init];
}

- (BOOL)applyActionArguments:(UAActionArguments *)args {
    return (BOOL)(args.situation != UASituationForegroundPush);
}

@end
