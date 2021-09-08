/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAUserData.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Rich Push helper methods.
 */
NS_SWIFT_NAME(InboxUtils)
@interface UAInboxUtils : NSObject

///---------------------------------------------------------------------------------------
/// @name Inbox Utility Methods
///---------------------------------------------------------------------------------------

/**
 *  Retrieves an inbox message ID from a notification dictionary
 *
 * @param notification The notification dictionary.
 * @return a message ID if found, `nil` otherwise
 */
+ (nullable NSString *)inboxMessageIDFromNotification:(NSDictionary *)notification;


/**
 * Retrieves an inbox message ID from an NSArray containing the ID
 * or if the value is the ID.
 *
 * @param values The value of the inbox message ID from a notification.
 * @return a message ID if found, `nil` otherwise
 */
+ (nullable NSString *)inboxMessageIDFromValue:(id)values;

/**
 * Gets the user auth header string for the provided user data.
 *
 * @param userData The user data.
 */
+ (NSString *)userAuthHeaderString:(UAUserData *)userData;


@end

NS_ASSUME_NONNULL_END
