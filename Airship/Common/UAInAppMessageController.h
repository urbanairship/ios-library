
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class UAInAppMessage;

/**
 * Controller interface for showing and dismissing in-app
 * messages.
 */
@interface UAInAppMessageController : NSObject<UIGestureRecognizerDelegate>

/**
 * UAInAppMessageController initializer.
 * @param message An instance of UAInAppMessage.
 */
- (instancetype)initWithMessage:(UAInAppMessage *)message;

/**
 * Show the associated message.
 */
- (void)show;

/**
 * Dismiss the associated message.
 */
- (void)dismiss;

@end

