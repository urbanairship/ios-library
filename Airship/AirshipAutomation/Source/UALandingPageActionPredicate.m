/* Copyright Urban Airship and Contributors */

#import "UALandingPageActionPredicate+Internal.h"
#import "UALandingPageAction.h"
#import "UAAirshipAutomationCoreImport.h"

@implementation UALandingPageActionPredicate


- (BOOL)applyActionArguments:(UAActionArguments *)args {
    return (BOOL)(args.situation != UASituationForegroundPush);
}

@end

