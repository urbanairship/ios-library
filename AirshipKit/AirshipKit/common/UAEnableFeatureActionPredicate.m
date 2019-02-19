/* Copyright 2010-2019 Urban Airship and Contributors */

#import "UAEnableFeatureActionPredicate+Internal.h"

@implementation UAEnableFeatureActionPredicate

-(BOOL)applyActionArguments:(UAActionArguments *)args {
    BOOL foregroundPresentation = args.metadata[UAActionMetadataForegroundPresentationKey] != nil;
    return (BOOL)!foregroundPresentation;
}

@end
