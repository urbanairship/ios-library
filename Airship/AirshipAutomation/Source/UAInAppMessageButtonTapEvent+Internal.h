/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAAirshipAutomationCoreImport.h"
#import "UAInAppMessage.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * In-app message button tap event.
 */
@interface UAInAppMessageButtonTapEvent : NSObject<UAEvent>

///---------------------------------------------------------------------------------------
/// @name In App Button Tap Event Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Factory method to create an event.
 * @param message The message.
 * @param messageID The message ID.
 * @param buttonID The button ID.
 * @param reportingContext The in-app message reporting context.
 * @param campaigns The campaign info.
 * @return An in-app button tap form event.
 */
+ (instancetype)eventWithMessage:(UAInAppMessage *)message
                       messageID:(NSString *)messageID
                buttonIdentifier:(NSString *)buttonID
                reportingContext:(NSDictionary *)reportingContext
                       campaigns:(nullable NSDictionary *)campaigns;

@end

NS_ASSUME_NONNULL_END

