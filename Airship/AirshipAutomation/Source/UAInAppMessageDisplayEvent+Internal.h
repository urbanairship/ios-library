/* Copyright Airship and Contributors */

#import "UAInAppMessage.h"
#import "UAAirshipAutomationCoreImport.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * In-app message display event.
 */
@interface UAInAppMessageDisplayEvent : UAEvent

///---------------------------------------------------------------------------------------
/// @name In App Display Event Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Factory method to create an event.
 * @param messageID The message ID.
 * @param message The in-app message.
 * @return An in-app display event.
 */
+ (instancetype)eventWithMessageID:(NSString *)messageID
                           message:(UAInAppMessage *)message;

@end

NS_ASSUME_NONNULL_END
