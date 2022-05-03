/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppMessage.h"
#import "UAInAppMessageAdapterProtocol.h"
#import "UAInAppMessageDisplayCoordinator.h"
#import "UAInAppMessageAssetManager.h"
#import "UAAirshipAutomationCoreImport.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Delegate protocol for receiving in-app messaging related
 * callbacks.
 */
NS_SWIFT_NAME(InAppMessagingDelegate)
@protocol UAInAppMessagingDelegate <NSObject>

@optional

///---------------------------------------------------------------------------------------
/// @name In App Messaging Delegate Methods
///---------------------------------------------------------------------------------------

/**
 * Allows the delegate to provide a custom display coordinator for the provided message.
 *
 * @param message The message.
 * @return An object implementing the UAInAppMessageDisplayCoordinator protocol or nil
 * if no suitable display coordinator is available.
 */
- (nullable id<UAInAppMessageDisplayCoordinator>)displayCoordinatorForMessage:(UAInAppMessage *)message;

/**
 * Allows the delegate to extend a message before display.
 *
 * @param message The message.
 * @return An extended instance of the message.
 */
- (UAInAppMessage *)extendMessage:(UAInAppMessage *)message;

/**
 * Indicates that an in-app message will be displayed.
 * @param message The associated in-app message.
 * @param scheduleID The schedule ID.
 */
- (void)messageWillBeDisplayed:(UAInAppMessage *)message scheduleID:(NSString *)scheduleID;

/**
 * Indicates that an in-app message has finished displaying.
 * @param message The associated in-app message.
 * @param scheduleID The schedule ID.
 * @param resolution The resolution info.
 */
- (void)messageFinishedDisplaying:(UAInAppMessage *)message scheduleID:(NSString *)scheduleID resolution:(UAInAppMessageResolution *)resolution;

/**
 * Allows the delegate to override the the choice of window scene for displaying the message.
 *
 * @param message The message.
 * @param defaultScene The window scene chosen for displaying the message, or nil if one could not be found.
 * @return A window scene if the delegate chooses to override the choice of scene, or nil otherwise.
 */
- (UIWindowScene *)sceneForMessage:(UAInAppMessage *)message defaultScene:(nullable UIWindowScene *)defaultScene API_AVAILABLE(ios(13.0));

/**
 * Delegate method to check if an In-App message is ready for display or not. This method will be called for
 * every message that is pending display whenever a display condition changes. Use `notifyDisplayConditionsChanged`
 * to notify whenever a condition changes to reevaluate the pending In-App messages.
 *
 * This method is called on the main queue.
 *
 * @return `true` if the message is ready to be displayed, otherwise `false.
 */
- (BOOL)isMessageReadyForDisplay:(UAInAppMessage *)message;

@end

/**
 * Provides a control interface for creating, canceling and executing in-app message schedules.
 */
NS_SWIFT_NAME(InAppMessageManager)
@interface UAInAppMessageManager : NSObject

/**
 * In-app messaging delegate.
 */
@property (nonatomic, weak) id<UAInAppMessagingDelegate> delegate;

/**
 * Message display interval.
 */
@property(nonatomic, assign) NSTimeInterval displayInterval;

/**
 * In-app messaging asset manager.
 */
@property(nonatomic, strong, readonly) UAInAppMessageAssetManager *assetManager;

/**
 * Allows setting factory blocks that builds InAppMessageAdapters for each given display type.
 *
 * @param displayType The display type.
 * @param factory The adapter factory.
 */
- (void)setFactoryBlock:(id<UAInAppMessageAdapterProtocol> (^)(UAInAppMessage* message))factory
         forDisplayType:(UAInAppMessageDisplayType)displayType;

/**
 * Notifies In-App messages that the display conditions should be reevaluated.
 *
 * This should only be called when state that was used to prevent a display with  `UAInAppMessagingDelegate` changes.
 */
- (void)notifyDisplayConditionsChanged;

@end

NS_ASSUME_NONNULL_END
