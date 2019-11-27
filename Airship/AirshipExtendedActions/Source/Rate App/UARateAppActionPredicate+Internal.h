/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

#if UA_USE_MODULE_AIRSHIP_IMPORTS
@import AirshipCore;
#else
#import "UAAction.h"
#import "UAActionPredicateProtocol.h"
#endif

/**
 * Default predicate for rate app action.
 */
@interface UARateAppActionPredicate: NSObject<UAActionPredicateProtocol>

@end
