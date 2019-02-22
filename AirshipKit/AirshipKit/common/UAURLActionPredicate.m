/* Copyright Urban Airship and Contributors */

#import "UAURLActionPredicate+Internal.h"

@implementation UAURLActionPredicate

-(BOOL)applyActionArguments:(UAActionArguments *)args {
    return (BOOL)(args.situation != UASituationForegroundPush);
}

@end
