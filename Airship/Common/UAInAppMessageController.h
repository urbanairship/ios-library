
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
 * @param dismissalBlock A block that will be executed once the message is dismissed.
 */
- (instancetype)initWithMessage:(UAInAppMessage *)message dismissalBlock:(void(^)(void))dismissalBlock;

/**
 * Show the associated message.
 */
- (void)show;

/**
 * Dismiss the associated message.
 */
- (void)dismiss;

@property(nonatomic, readonly) UAInAppMessage *message;

@end

