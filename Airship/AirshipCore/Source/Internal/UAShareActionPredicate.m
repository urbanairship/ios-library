/* Copyright Airship and Contributors */

#import "UAShareActionPredicate+Internal.h"
#import "UAActionArguments.h"

@implementation UAShareActionPredicate

+ (instancetype)predicate {
    return [[self alloc] init];
}

- (BOOL)applyActionArguments:(UAActionArguments *)args {
    return (BOOL)(args.situation != UASituationForegroundPush);
}

@end
