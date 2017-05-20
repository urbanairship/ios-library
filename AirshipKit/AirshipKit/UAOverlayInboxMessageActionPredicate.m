/* Copyright 2017 Urban Airship and Contributors */

#import "UAOverlayInboxMessageActionPredicate.h"

@implementation UAOverlayInboxMessageActionPredicate

-(BOOL)applyActionArguments:(UAActionArguments *)args {
    return (BOOL)(args.situation != UASituationForegroundPush);
}

@end
