/* Copyright Airship and Contributors */

#import "UAInAppMessage+Internal.h"
#import "UAInAppMessageResolution.h"
#import "UAAirshipAutomationCoreImport.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * In-app message resolution event.
 */
@interface UAInAppMessageResolutionEvent : NSObject<UAEvent>

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
 * @param messageID The message ID.
 * @param source The in-app message source.
 * @param resolution The in-app message resolution.
 * @param displayTime The amount of time the message was displayed.
 * @param campaigns The campaigns info.
 * @return The resolution event.
 */
+ (instancetype)eventWithMessageID:(NSString *)messageID
                            source:(UAInAppMessageSource)source
                        resolution:(UAInAppMessageResolution *)resolution
                       displayTime:(NSTimeInterval)displayTime
                         campaigns:(nullable NSDictionary *)campaigns;

@end

NS_ASSUME_NONNULL_END
