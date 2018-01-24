/* Copyright 2017 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "UAWKWebViewDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@class UAInAppMessageHTMLDisplayContent;
@class UAInAppMessageResolution;

@interface UAInAppMessageHTMLController : NSObject <UAWKWebViewDelegate>

/**
 * The factory method for creating an HTML controller.
 *
 * @param messageID The message identifier.
 * @param displayContent The display content.
 *
 * @return a configured UAInAppMessageFullScreenView instance.
 */
+ (instancetype)htmlControllerWithHTMLMessageID:(NSString *)messageID
                                 displayContent:(UAInAppMessageHTMLDisplayContent *)displayContent;

/**
 * The method to show the HTML controller.
 *
 * @param parentView The parent view.
 * @param completionHandler The completion handler that's called when show operation completes.
 */
- (void)showWithParentView:(UIView *)parentView completionHandler:(void (^)(UAInAppMessageResolution *))completionHandler;

@end

NS_ASSUME_NONNULL_END
