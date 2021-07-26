/* Copyright Airship and Contributors */

#import "UAAddCustomEventActionPredicate+Internal.h"
#import "UAActionArguments.h"
#import "UAActionResult.h"

@implementation UAAddCustomEventActionPredicate

+ (instancetype)predicate {
    return [[self alloc] init];
}

- (BOOL)applyActionArguments:(UAActionArguments *)args {
    BOOL foregroundPresentation = args.metadata[UAActionMetadataForegroundPresentationKey] != nil;
    return (BOOL)!foregroundPresentation;
}

@end
