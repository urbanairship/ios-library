/* Copyright 2010-2019 Urban Airship and Contributors */

#import "UAURLActionPredicate+Internal.h"

@implementation UAURLActionPredicate

-(BOOL)applyActionArguments:(UAActionArguments *)args {
    return (BOOL)(args.situation != UASituationForegroundPush);
}

@end
