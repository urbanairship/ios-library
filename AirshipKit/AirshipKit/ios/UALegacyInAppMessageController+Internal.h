/* Copyright 2017 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "UALegacyInAppMessageControllerDelegate.h"

@class UALegacyInAppMessage;
@class UALegacyInAppMessageControllerDefaultDelegate;

NS_ASSUME_NONNULL_BEGIN

/**
 * Controller interface for showing and dismissing in-app
 * messages.
 */
@interface UALegacyInAppMessageController : NSObject<UIGestureRecognizerDelegate>

///---------------------------------------------------------------------------------------
/// @name In App Message Controller Internal Properties
///---------------------------------------------------------------------------------------

/**
 * The in app message
 */
@property(nonatomic, readonly) UALegacyInAppMessage *message;

/**
 * Whether the associated in-app message is currently showing
 */
@property (nonatomic, readonly) BOOL isShowing;

/**
 * The default delegate
 */
@property (nonatomic, strong) UALegacyInAppMessageControllerDefaultDelegate *defaultDelegate;

/**
 * The optional controller delegate that can be implemented by the user
 */
@property (nonatomic, strong, nullable) id <UALegacyInAppMessageControllerDelegate> userDelegate;

///---------------------------------------------------------------------------------------
/// @name In App Message Controller Internal Display Methods
///---------------------------------------------------------------------------------------

/**
 * UAInAppMessageController initializer.
 * @param message An instance of UAInAppMessage.
 * @param delegate An object implementing the UALegacyInAppMessageControllerDelegate protocol.
 * @param dismissalBlock A block that will be executed once the message is dismissed.
 * @return An instance of UAInAppMessageController.
 */
+ (instancetype)controllerWithMessage:(UALegacyInAppMessage *)message
                             delegate:(id<UALegacyInAppMessageControllerDelegate>)delegate
                       dismissalBlock:(void(^)(UALegacyInAppMessageController *))dismissalBlock;
/**
 * Show the associated message. If the message has already been shown,
 * this will be a no-op.
 *
 * @return `YES` if the message could be displayed, `NO` otherwise.
 */
- (BOOL)show;

/**
 * Dismiss the associated message. If the message has already been dismissed,
 * this will be a no-op.
 */
- (void)dismiss;

@end

NS_ASSUME_NONNULL_END


