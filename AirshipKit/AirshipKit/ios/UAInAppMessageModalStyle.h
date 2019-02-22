/* Copyright Urban Airship and Contributors */

#import "UAInAppMessageStyleProtocol.h"
#import "UAPadding.h"
#import "UAInAppMessageTextStyle.h"
#import "UAInAppMessageButtonStyle.h"
#import "UAInAppMessageMediaStyle.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * The key representing the dismissIconResource in a style plist.
 */
extern NSString *const UAModalDismissIconResourceKey;

/**
 * The key representing the additionalPadding in a style plist.
 */
extern NSString *const UAModalAdditionalPaddingKey;

/**
 * The key representing the top-level text style in a style plist.
 */
extern NSString *const UAModalTextStyleKey;

/**
 * The key representing the header style in a style plist.
 */
extern NSString *const UAModalHeaderStyleKey;

/**
 * The key representing the body style in a style plist.
 */
extern NSString *const UAModalBodyStyleKey;

/**
 * The key representing the button style in a style plist.
 */
extern NSString *const UAModalButtonStyleKey;

/**
 * The key representing the media style in a style plist.
 */
extern NSString *const UAModalMediaStyleKey;

/**
 * The key representing the max width in a style plist.
 */
extern NSString *const UAModalMaxWidthKey;

/**
 * The key representing the max height in a style plist.
 */
extern NSString *const UAModalMaxHeightKey;

/**
 * Model object representing a custom style to be applied
 * to modal in-app messages.
 */
@interface UAInAppMessageModalStyle : NSObject<UAInAppMessageStyleProtocol>

///---------------------------------------------------------------------------------------
/// @name Modal Style Properties
///---------------------------------------------------------------------------------------

/**
 * The constants added to the default spacing between a view and its parent.
 */
@property(nonatomic, strong) UAPadding *additionalPadding;

/**
 * The dismiss icon image resource name.
 */
@property(nonatomic, strong, nullable) NSString *dismissIconResource;

/**
 * The max width in points.
 */
@property(nonatomic, strong, nullable) NSNumber *maxWidth;

/**
 * The max height in points.
 */
@property(nonatomic, strong, nullable) NSNumber *maxHeight;

/**
 * The header text style
 */
@property(nonatomic, strong, nullable) UAInAppMessageTextStyle *headerStyle;

/**
 * The body text style
 */
@property(nonatomic, strong, nullable) UAInAppMessageTextStyle *bodyStyle;

/**
 * The button component style
 */
@property(nonatomic, strong, nullable) UAInAppMessageButtonStyle *buttonStyle;

/**
 * The media component style
 */
@property(nonatomic, strong, nullable) UAInAppMessageMediaStyle *mediaStyle;

@end

NS_ASSUME_NONNULL_END

