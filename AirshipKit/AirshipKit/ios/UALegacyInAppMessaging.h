/* Copyright 2017 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "UALegacyInAppMessageControllerDelegate.h"

@class UALegacyInAppMessage;

NS_ASSUME_NONNULL_BEGIN

/**
 * Delegate protocol for receiving in-app messaging related
 * callbacks.
 */
@protocol UALegacyInAppMessagingDelegate <NSObject>

@optional

///---------------------------------------------------------------------------------------
/// @name In App Messaging Delegate Methods
///---------------------------------------------------------------------------------------

/**
 * Indicates that an in-app message has been stored as pending.
 * @param message The associated in-app message.
 */
- (void)pendingMessageAvailable:(UALegacyInAppMessage *)message;

/**
 * Indicates that an in-app message will be automatically displayed.
 * @param message The associated in-app message.
 */
- (void)messageWillBeDisplayed:(UALegacyInAppMessage *)message;

/**
 * Indicates that an in-app message body has been tapped.
 */
- (void)messageTapped:(UALegacyInAppMessage *)message;

/**
 * Indicates that an in-app message button has been tapped.
 */
- (void)messageButtonTapped:(UALegacyInAppMessage *)message buttonIdentifier:(NSString *)identifier;

/**
 * Indicates that an in-app message has been dismissed by the user or a timeout.
 */
- (void)messageDismissed:(UALegacyInAppMessage *)message timeout:(BOOL)timedOut;

@end


/**
 * Manager class for in-app messaging.
 */
@interface UALegacyInAppMessaging : NSObject

///---------------------------------------------------------------------------------------
/// @name In App Messaging Properties
///---------------------------------------------------------------------------------------

/**
* The pending in-app message.
*/
@property(nonatomic, copy, nullable) UALegacyInAppMessage *pendingMessage;

/**
* Enables/disables auto-display of in-app messages.
*/
@property(nonatomic, assign, getter=isAutoDisplayEnabled) BOOL autoDisplayEnabled;

/**
 * The desired font to use when displaying in-app messages.
 * Defaults to a bold system font 12 points in size.
 */
@property(nonatomic, strong) UIFont *font;

/**
 * The default primary color for messages (background and button color). Colors sent in
 * an in-app message payload will override this setting. Defaults to white.
 */
@property(nonatomic, strong) UIColor *defaultPrimaryColor;

/**
 * The default secondary color for messages (text and border color). Colors sent in
 * an in-app message payload will override this setting. Defaults to gray (#282828).
 */
@property(nonatomic, strong) UIColor *defaultSecondaryColor;

/**
 * The initial delay before displaying an in-app message. The timer begins when the
 * application becomes active. Defaults to 3 seconds.
 */
@property(nonatomic, assign) NSTimeInterval displayDelay;

/**
 * Whether to display an incoming message as soon as possible, as opposed to on app foreground
 * transitions. If set to `YES`, and if automatic display is enabled, when a message arrives in
 * the foreground it will be automatically displayed as soon as it has been received. Otherwise
 * the message will be stored as pending. Defaults to `NO`.
 */
@property(nonatomic, assign, getter=isDisplayASAPEnabled) BOOL displayASAPEnabled;

/**
 * An optional delegate to receive in-app messaging related callbacks.
 */
@property(nonatomic, weak, nullable) id<UALegacyInAppMessagingDelegate> messagingDelegate;

/**
 * A optional delegate for configuring and providing custom UI during message display.
 */
@property(nonatomic, weak, nullable) id<UALegacyInAppMessageControllerDelegate> messageControllerDelegate;

///---------------------------------------------------------------------------------------
/// @name In App Messaging Display and Management
///---------------------------------------------------------------------------------------

/**
 * Displays the provided message. Expired messages will be
 * ignored.
 *
 * @param message The message to display.
 */
- (void)displayMessage:(UALegacyInAppMessage *)message;

/*
 * Displays the pending message if it is available.
 */
- (void)displayPendingMessage;

/**
 * Deletes the pending message if it matches the
 * provided message argument.
 *
 * @param message The message to delete.
 */
- (void)deletePendingMessage:(UALegacyInAppMessage *)message;

@end

NS_ASSUME_NONNULL_END
