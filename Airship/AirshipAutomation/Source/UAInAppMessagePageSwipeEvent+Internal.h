/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAAirshipAutomationCoreImport.h"
#import "UAInAppMessage.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * In-app message page swipe event.
 */
@interface UAInAppMessagePageSwipeEvent : NSObject<UAEvent>

///---------------------------------------------------------------------------------------
/// @name In App Page Swipe Event Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Factory method to create an event.
 * @param message The message.
 * @param messageID The message ID.
 * @param pagerID The pager ID.
 * @param fromIndex The previous page index.
 * @param toIndex The current page index.
 * @param reportingContext The in-app message reporting context.
 * @param campaigns The campaign info.
 * @return An in-app page swipe form event.
 */
+ (instancetype)eventWithMessage:(UAInAppMessage *)message
                       messageID:(NSString *)messageID
                 pagerIdentifier:(NSString *)pagerID
                       fromIndex:(NSInteger)fromIndex
                       toIndex:(NSInteger)toIndex
                reportingContext:(NSDictionary *)reportingContext
                       campaigns:(nullable NSDictionary *)campaigns;

@end

NS_ASSUME_NONNULL_END

