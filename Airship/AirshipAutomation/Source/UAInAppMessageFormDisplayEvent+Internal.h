/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAAirshipAutomationCoreImport.h"
#import "UAInAppMessage.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * In-app message display form event.
 */
@interface UAInAppMessageFormDisplayEvent : NSObject<UAEvent>

///---------------------------------------------------------------------------------------
/// @name In App Display Form Event Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Factory method to create an event.
 * @param message The message.
 * @param messageID The message ID.
 * @param formID The form ID.
 * @param reportingContext The in-app message reporting context.
 * @param campaigns The campaign info.
 * @return An in-app display form event.
 */
+ (instancetype)eventWithMessage:(UAInAppMessage *)message
                       messageID:(NSString *)messageID
                  formIdentifier:(NSString *)formID
                reportingContext:(NSDictionary *)reportingContext
                       campaigns:(nullable NSDictionary *)campaigns;

@end

NS_ASSUME_NONNULL_END

