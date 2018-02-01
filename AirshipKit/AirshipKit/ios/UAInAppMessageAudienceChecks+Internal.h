/* Copyright 2018 Urban Airship and Contributors */

#import <Foundation/Foundation.h>

@class UAInAppMessageAudience;

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

@end
