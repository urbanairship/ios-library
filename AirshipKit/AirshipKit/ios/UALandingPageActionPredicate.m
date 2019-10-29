/* Copyright Urban Airship and Contributors */

#import "UALandingPageActionPredicate+Internal.h"
#import "UALandingPageAction.h"
#import "UAirship.h"
#import "UAApplicationMetrics.h"

@implementation UALandingPageActionPredicate

+ (instancetype)predicate {
    return [[self alloc] init];
}

- (BOOL)applyActionArguments:(UAActionArguments *)args {
    return (BOOL)(args.situation != UASituationForegroundPush);
}

@end

