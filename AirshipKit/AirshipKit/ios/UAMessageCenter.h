/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class UAInboxMessage;
@class UAMessageCenterStyle;
@class UAConfig;

/**
 * The UAMessageCenter class provides a default implementation of a
 * message center, as well as a high-level interface for its configuration and display.
 */
@interface UAMessageCenter : NSObject

///---------------------------------------------------------------------------------------
/// @name Default Message Center Properties
///---------------------------------------------------------------------------------------

/**
 * The title of the message center.
 */
@property (nonatomic, strong) NSString *title;

/**
 * The style to apply to the default message center.
 */
@property (nonatomic, strong) UAMessageCenterStyle *style;

/**
 * An optional predicate for filtering messages.
 */
@property (nonatomic, strong) NSPredicate *filter;

/**
 * Disables 3D touching and long pressing on links in messages.
 */
@property (nonatomic) BOOL disableMessageLinkPreviewAndCallouts;

///---------------------------------------------------------------------------------------
/// @name Default Message Center Factory
///---------------------------------------------------------------------------------------

/**
 * Factory method for creating message center with style specified in a config.
 *
 * @return A Message Center instance initialized with the style specified in the provided config.
 */
+ (instancetype)messageCenterWithConfig:(UAConfig *)config;

///---------------------------------------------------------------------------------------
/// @name Default Message Center Display
///---------------------------------------------------------------------------------------

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
 * Display the given message without animation.
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
