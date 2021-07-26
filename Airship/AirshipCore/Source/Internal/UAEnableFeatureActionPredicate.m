/* Copyright Airship and Contributors */

#import "UAEnableFeatureActionPredicate+Internal.h"
#import "UAActionArguments.h"
#import "UAActionResult.h"

@implementation UAEnableFeatureActionPredicate

+ (instancetype)predicate {
    return [[self alloc] init];
}

- (BOOL)applyActionArguments:(UAActionArguments *)args {
    BOOL foregroundPresentation = args.metadata[UAActionMetadataForegroundPresentationKey] != nil;
    return (BOOL)!foregroundPresentation;
}

@end
