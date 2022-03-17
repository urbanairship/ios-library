/* Copyright Airship and Contributors */

#import "UAInAppMessageStyleProtocol.h"
#import "UAInAppMessageTextStyle.h"
#import "UAInAppMessageButtonStyle.h"
#import "UAInAppMessageMediaStyle.h"
#import "UAAirshipAutomationCoreImport.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * The key representing the dismissIconResource in a style plist.
 */
extern NSString *const UAHTMLDismissIconResourceKey;

/**
 * The key representing the additionalPadding in a style plist.
 */
extern NSString *const UAHTMLAdditionalPaddingKey;

/**
 * The key representing the max width in a style plist.
 */
extern NSString *const UAHTMLMaxWidthKey;

/**
 * The key representing the max height in a style plist.
 */
extern NSString *const UAHTMLMaxHeightKey;

/**
 * The key representing the hide dismiss icon flag in a style plist.
 */
extern NSString *const UAHTMLHideDismissIconKey;

/**
 * Model object representing a custom style to be applied
 * to HTML in-app messages.
 */
NS_SWIFT_NAME(InAppMessageHTMLStyle)
@interface UAInAppMessageHTMLStyle : NSObject<UAInAppMessageStyleProtocol>

///---------------------------------------------------------------------------------------
/// @name HTML Style Properties
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
 * Flag to hide the dismiss icon.
 */
@property(nonatomic, assign) BOOL hideDismissIcon;

/**
 *  Extend full screen on large device.
 */
@property(nonatomic, assign) BOOL extendFullScreenLargeDevice;

@end

NS_ASSUME_NONNULL_END

