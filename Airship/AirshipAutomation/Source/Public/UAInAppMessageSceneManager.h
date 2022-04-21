/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "UAInAppMessage.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Delegate protocol for receiving in-app scene related callbacks.
 */
NS_SWIFT_NAME(InAppMessageSceneDelegate)
@protocol UAInAppMessageSceneDelegate <NSObject>

@optional
/**
 * Allows the delegate to override the choice of window scene for displaying the message.
 *
 * @param message The message.
 * @param defaultScene The window scene that will be used if the delegate does not override, or nil if a default scene could not be found.
 * @return A window scene if the delegate chooses to override the choice of scene, or nil otherwise.
 */
- (nullable UIWindowScene *)sceneForMessage:(UAInAppMessage *)message defaultScene:(nullable UIWindowScene *)defaultScene API_AVAILABLE(ios(13.0));

@end

/**
 *  Scene manager for in-app messages.
 */
NS_SWIFT_NAME(InAppMessageSceneManager)
@interface UAInAppMessageSceneManager : NSObject

/**
 * In-app scene delegate.
 */
@property (nonatomic, weak) id<UAInAppMessageSceneDelegate> delegate;

/**
 * Shared instance.
 */
@property (nonatomic, readonly, class) UAInAppMessageSceneManager *shared;

/**
 *  Called to get the scene for an in-app message.
 *
 * @param message The message.
 * @return A window scene if available, or nil.
 */
- (nullable UIWindowScene *)sceneForMessage:(UAInAppMessage *)message API_AVAILABLE(ios(13.0));

@end

NS_ASSUME_NONNULL_END
