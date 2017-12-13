/* Copyright 2017 Urban Airship and Contributors */

#import <Foundation/Foundation.h>

@class UAInAppMessageAudience;

/**
 * Class for checking if the current user is a member of an In App Message audience.
 */
@interface UAInAppMessageAudienceChecks : NSObject

/**
 * Check if the user is part of the specified audience
 *
 * @param audience The specified audience
 * @param isNewUser System flag indicating the current user is a new user
 * @return YES if the current user is a member of the specified audience
 */
+ (BOOL)checkAudience:(UAInAppMessageAudience *)audience isNewUser:(BOOL)isNewUser;

/**
 * Check if the user is part of the specified audience
 *
 * @param audience The specified audience
 * @return YES if the current user is a member of the specified audience
 */
+ (BOOL)checkAudience:(UAInAppMessageAudience *)audience;

@end
