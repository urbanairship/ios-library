/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAAirshipAutomationCoreImport.h"
#import "UAInAppMessage.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * In-app message page view event.
 */
@interface UAInAppMessagePageViewEvent : NSObject<UAEvent>

///---------------------------------------------------------------------------------------
/// @name In App Page View Event Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Factory method to create an event.
 * @param message The message.
 * @param messageID The message ID.
 * @param pagerID The pager ID.
 * @param pageIndex The page index.
 * @param pageCount The page count.
 * @param completed Indicates if the user reached the end of the pager or not.
 * @param reportingContext The in-app message reporting context.
 * @param campaigns The campaign info.
 * @return An in-app page view form event.
 */
+ (instancetype)eventWithMessage:(UAInAppMessage *)message
                       messageID:(NSString *)messageID
                 pagerIdentifier:(NSString *)pagerID
                       pageIndex:(NSInteger)pageIndex
                       pageCount:(NSInteger)pageCount
                       completed:(BOOL)completed
                reportingContext:(NSDictionary *)reportingContext
                       campaigns:(nullable NSDictionary *)campaigns;

@end

NS_ASSUME_NONNULL_END

