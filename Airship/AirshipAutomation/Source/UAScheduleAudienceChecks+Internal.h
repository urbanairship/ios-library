/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAScheduleAudience+Internal.h"
#import "UAAirshipAutomationCoreImport.h"
#import "UATagGroups+Internal.h"

/**
 * Class for checking if the current user is a member of an in-app automation audience.
 */
@interface UAScheduleAudienceChecks : NSObject

/**
 * Check scheduling audience conditions.
 *
 * @param audience The specified audience
 * @param isNewUser System flag indicating the current user is a new user
 * @return YES if the current user is a member of the specified audience
 */
+ (BOOL)checkScheduleAudienceConditions:(UAScheduleAudience *)audience isNewUser:(BOOL)isNewUser;

/**
 * Check display audience conditions.
 *
 * @param audience The specified audience
 * @param completionHandler The completion handler
 */
+ (void)checkDisplayAudienceConditions:(UAScheduleAudience *)audience completionHandler:(void (^)(BOOL))completionHandler;

@end
