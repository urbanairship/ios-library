/* Copyright Airship and Contributors */

#import "UAURLActionPredicate+Internal.h"

@implementation UAURLActionPredicate

+ (instancetype)predicate {
    return [[self alloc] init];
}

- (BOOL)applyActionArguments:(UAActionArguments *)args {
    return (BOOL)(args.situation != UASituationForegroundPush);
}

@end
