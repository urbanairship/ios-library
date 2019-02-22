/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppMessageStyleProtocol.h"
#import "UAPadding.h"
#import "UAInAppMessageTextStyle.h"
#import "UAInAppMessageButtonStyle.h"
#import "UAInAppMessageMediaStyle.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * The key representing the dismissIconResource in a style plist.
 */
extern NSString *const UAFullScreenDismissIconResourceKey;

/**
 * The key representing the additionalPadding in a style plist.
 */
extern NSString *const UAFullScreenAdditonalPaddingKey;

/**
 * The key representing the top-level text style in a style plist.
 */
extern NSString *const UAFullScreenTextStyleKey;

/**
 * The key representing the header style in a style plist.
 */
extern NSString *const UAFullScreenHeaderStyleKey;

/**
 * The key representing the body style in a style plist.
 */
extern NSString *const UAFullScreenBodyStyleKey;

/**
 * The key representing the button style in a style plist.
 */
extern NSString *const UAFullScreenButtonStyleKey;

/**
 * The key representing the media style in a style plist.
 */
extern NSString *const UAFullScreenMediaStyleKey;

/**
 * Model object representing a custom style to be applied
 * to full screen in-app message.
 */
@interface UAInAppMessageFullScreenStyle : NSObject<UAInAppMessageStyleProtocol>

///---------------------------------------------------------------------------------------
/// @name Full Screen Style Properties
///---------------------------------------------------------------------------------------

/**
 * The dismiss icon image resource name.
 */
@property(nonatomic, strong, nullable) NSString *dismissIconResource;

/**
 * The header text style
 */
@property(nonatomic, strong, nullable) UAInAppMessageTextStyle *headerStyle;

/**
 * The body text style
 */
@property(nonatomic, strong, nullable) UAInAppMessageTextStyle *bodyStyle;

/**
 * The button style
 */
@property(nonatomic, strong, nullable) UAInAppMessageButtonStyle *buttonStyle;

/**
 * The media style
 */
@property(nonatomic, strong, nullable) UAInAppMessageMediaStyle *mediaStyle;

@end

NS_ASSUME_NONNULL_END
