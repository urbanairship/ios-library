/* Copyright 2010-2019 Urban Airship and Contributors */

#import "UAShareActionPredicate+Internal.h"

@implementation UAShareActionPredicate

-(BOOL)applyActionArguments:(UAActionArguments *)args {
    return (BOOL)(args.situation != UASituationForegroundPush);
}

@end
