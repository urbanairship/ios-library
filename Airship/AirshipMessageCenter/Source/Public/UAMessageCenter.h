/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "UAAirshipMessageCenterCoreImport.h"

@class UADefaultMessageCenterUI;
@class UAInboxMessageList;
@class UAMessageCenterStyle;
@class UAUser;

NS_ASSUME_NONNULL_BEGIN

/**
 * Delegate protocol for receiving callbacks related to message center.
 */
NS_SWIFT_NAME(MessageCenterDisplayDelegate)
@protocol UAMessageCenterDisplayDelegate <NSObject>

@required

/**
 * Called when a message is requested to be displayed.
 *
 * @param messageID The message ID.
 * @param animated Whether the transition should be animated.
 */
- (void)displayMessageCenterForMessageID:(NSString *)messageID animated:(BOOL)animated;

/**
 * Called when the message center is requested to be displayed.
 *
 * @param animated Whether the transition should be animated.
 */
- (void)displayMessageCenterAnimated:(BOOL)animated;

/**
 * Called when the message center is requested to be dismissed.
 *
 * @param animated Whether the transition should be animated.
 */
- (void)dismissMessageCenterAnimated:(BOOL)animated;

@end

/**
 * The UAMessageCenter class provides a default implementation of a
 * message center, as well as a high-level interface for its configuration and display.
 */
NS_SWIFT_NAME(MessageCenter)
@interface UAMessageCenter : NSObject <UAComponent>

/**
 * The message scheme
 */
extern NSString *const UAMessageDataScheme;


///---------------------------------------------------------------------------------------
/// @name Message Center Properties
///---------------------------------------------------------------------------------------

/**
 * Display delegate that can be used to provide a custom message center implementation.
 */
@property (nonatomic, weak) id<UAMessageCenterDisplayDelegate> displayDelegate;

/**
 * The default display if a `displayDelegate` is not set.
 */
@property (nonatomic, readonly) UADefaultMessageCenterUI *defaultUI;

/**
 * The list of messages.
 */
@property (nonatomic, readonly) UAInboxMessageList *messageList;

/**
 * The user.
 */
@property (nonatomic, readonly) UAUser *user;


///---------------------------------------------------------------------------------------
/// @name Message Center Methods
///---------------------------------------------------------------------------------------

/**
 * The shared message center instance.
 */
@property (class, nonatomic, readonly, null_unspecified) UAMessageCenter *shared;

/**
 * Display the message center.
 *
 * @param animated Whether the transition should be animated.
 */
- (void)display:(BOOL)animated;

/**
 * Display the message center with animation.
 */
- (void)display;

/**
 * Display the given message.
 *
 * @pararm messageID The messageID of the message.
 * @param animated Whether the transition should be animated.
 */
- (void)displayMessageForID:(NSString *)messageID animated:(BOOL)animated;

/**
 * Display the given message with animation.
 *
 * @pararm messageID The messageID of the message.
 */
- (void)displayMessageForID:(NSString *)messageID;

/**
 * Dismiss the message center.
 *
 * @param animated Whether the transition should be animated.
 */
- (void)dismiss:(BOOL)animated;

/**
 * Dismiss the message center with animation.
 */
- (void)dismiss;

@end

NS_ASSUME_NONNULL_END
