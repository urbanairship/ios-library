/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

#if __has_include(<AirshipCore/AirshipCore.h>)
#import <AirshipCore/AirshipCore.h>
#else
#import "UAAction.h"
#import "UAActionPredicateProtocol.h"
#endif

/**
 * Default predicate for rate app action.
 */
@interface UARateAppActionPredicate: NSObject<UAActionPredicateProtocol>

@end
