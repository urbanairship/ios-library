/* Copyright 2017 Urban Airship and Contributors */

#import "UAShareActionPredicate.h"

@implementation UAShareActionPredicate

-(BOOL)applyActionArguments:(UAActionArguments *)args {
    return (BOOL)(args.situation != UASituationForegroundPush);
}

@end
