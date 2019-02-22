/* Copyright Urban Airship and Contributors */

#import "UAPadding.h"
#import "UAInAppMessageTextStyle.h"
#import "UAInAppMessageButtonStyle.h"
#import "UAInAppMessageMediaStyle.h"
#import "UAInAppMessageStyleProtocol.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * The key representing the additionalPadding in a style plist.
 */
extern NSString *const UABannerAdditionalPaddingKey;

/**
 * The key representing the top-level text style in a style plist.
 */
extern NSString *const UABannerTextStyleKey;

/**
 * The key representing the header style in a style plist.
 */
extern NSString *const UABannerHeaderStyleKey;

/**
 * The key representing the body style in a style plist.
 */
extern NSString *const UABannerBodyStyleKey;

/**
 * The key representing the button style in a style plist.
 */
extern NSString *const UABannerButtonStyleKey;

/**
 * The key representing the media style in a style plist.
 */
extern NSString *const UABannerMediaStyleKey;

/**
 * The key representing the max width in a style plist.
 */
extern NSString *const UABannerMaxWidthKey;


/**
 * Model object representing a custom style to be applied
 * to banner in-app message.
 */
@interface UAInAppMessageBannerStyle : NSObject<UAInAppMessageStyleProtocol>

///---------------------------------------------------------------------------------------
/// @name Banner Style Properties
///---------------------------------------------------------------------------------------

/**
 * The constants added to the default spacing between a view and its parent.
 */
@property(nonatomic, strong, nullable) UAPadding *additionalPadding;

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

/**
 * The max width in points.
 */
@property(nonatomic, strong, nullable) NSNumber *maxWidth;


@end

NS_ASSUME_NONNULL_END

