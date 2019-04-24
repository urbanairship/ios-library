/* Copyright Urban Airship and Contributors */

#import "UAEvent.h"
#import "UAInAppMessage.h"
#import "UAInAppMessageResolution.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * In-app message resolution event.
 */
@interface UAInAppMessageResolutionEvent : UAEvent

/**
 * Creates a replaced in-app resolution event.
 *
 * @param messageID The replaced message ID.
 * @param replacementID The new message ID.
 * @return The resolution event.
 */
+ (instancetype)legacyReplacedEventWithMessageID:(NSString *)messageID
                                   replacementID:(NSString *)replacementID;

/**
 * Creates a direct open in-app resolution event.
 *
 * @param messageID The message ID.
 * @return The resolution event.
 */
+ (instancetype)legacyDirectOpenEventWithMessageID:(NSString *)messageID;

/**
 * Creates a resolution event.
 *
 * @param message The in-app message.
 * @param resolution The in-app message resolution.
 * @param displayTime The amount of time the message was displayed.
 * @return The resolution event.
 */
+ (instancetype)eventWithMessage:(UAInAppMessage *)message
                      resolution:(UAInAppMessageResolution *)resolution
                     displayTime:(NSTimeInterval)displayTime;

/**
 * Creates a resolution event for an expired message.
 *
 * @param message The in-app message.
 * @param expiredDate The expiry date.
 * @return The resolution event.
 */
+ (instancetype)eventWithExpiredMessage:(UAInAppMessage *)message
                            expiredDate:(NSDate *)expiredDate;

@end

NS_ASSUME_NONNULL_END
