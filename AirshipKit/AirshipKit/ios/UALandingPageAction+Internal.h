/* Copyright Airship and Contributors */

#import "UAAction.h"
#import "UAInAppMessage.h"
#import "UAInAppMessageScheduleInfo.h"
#import "UALandingPageAction.h"

@interface UALandingPageAction ()

/**
 * Utility method for parsing a landing page URL from action arguments.
 */
- (NSURL *)parseURLFromArguments:(UAActionArguments *)arguments;

@end
