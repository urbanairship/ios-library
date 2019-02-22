/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppMessageAudience+Internal.h"
#import "UATagGroups+Internal.h"


/**
 * Class for checking if the current user is a member of an in-app message audience.
 */
@interface UAInAppMessageAudienceChecks : NSObject

/**
 * Check scheduling audience conditions.
 *
 * @param audience The specified audience
 * @param isNewUser System flag indicating the current user is a new user
 * @return YES if the current user is a member of the specified audience
 */
+ (BOOL)checkScheduleAudienceConditions:(UAInAppMessageAudience *)audience isNewUser:(BOOL)isNewUser;

/**
 * Check display audience conditions.
 *
 * @param audience The specified audience
 * @return YES if the current user is a member of the specified audience
 */
+ (BOOL)checkDisplayAudienceConditions:(UAInAppMessageAudience *)audience;

/**
 * Check display audience conditions.
 *
 * @param audience The specified audience
 * @param tagGroups An instance of UATagGroups to match against.
 * @return YES if the current user is a member of the specified audience
 */
+ (BOOL)checkDisplayAudienceConditions:(UAInAppMessageAudience *)audience tagGroups:(UATagGroups *)tagGroups;

@end
