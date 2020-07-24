/* Copyright Airship and Contributors */

#import "UAInAppMessage.h"
#import "UALandingPageAction.h"
#import "UAAirshipAutomationCoreImport.h"

@interface UALandingPageAction ()

/**
 * Utility method for parsing a landing page URL from action arguments.
 */
- (NSURL *)parseURLFromArguments:(UAActionArguments *)arguments;

@end
