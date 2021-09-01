/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>
#import "UAAppIntegrationDelegate.h"

/**
 * Auto app integration.
 * @note For internal use only. :nodoc:
 */
@interface UAAutoIntegration : NSObject

///---------------------------------------------------------------------------------------
/// @name Auto Integration Internal Methods
///---------------------------------------------------------------------------------------

+ (void)integrateWithDelegate:(id<UAAppIntegrationDelegate>)delegate;

+ (void)reset;

@end
