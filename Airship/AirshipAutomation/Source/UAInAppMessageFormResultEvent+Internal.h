/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAAirshipAutomationCoreImport.h"
#import "UAInAppMessage.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * In-app message form result event.
 */
@interface UAInAppMessageFormResultEvent : NSObject<UAEvent>

///---------------------------------------------------------------------------------------
/// @name In App Form Result Event Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Factory method to create an event.
 * @param message The message.
 * @param messageID The message ID.
 * @param formID The form ID.
 * @param formData The form data.
 * @param reportingContext The in-app message reporting context.
 * @param campaigns The campaign info.
 * @return An in-app form result event.
 */
+ (instancetype)eventWithMessage:(UAInAppMessage *)message
                       messageID:(NSString *)messageID
                  formIdentifier:(NSString *)formID
                        formData:(NSDictionary *)formData
                reportingContext:(NSDictionary *)reportingContext
                       campaigns:(nullable NSDictionary *)campaigns;

@end

NS_ASSUME_NONNULL_END
