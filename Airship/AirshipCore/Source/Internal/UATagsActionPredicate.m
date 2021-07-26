/* Copyright Airship and Contributors */

#import "UATagsActionPredicate+Internal.h"
#import "UAActionArguments.h"

@implementation UATagsActionPredicate

+ (instancetype)predicate {
    return [[self alloc] init];
}

- (BOOL)applyActionArguments:(UAActionArguments *)args {
    BOOL foregroundPresentation = args.metadata[UAActionMetadataForegroundPresentationKey] != nil;
    return (BOOL)!foregroundPresentation;
}

@end
