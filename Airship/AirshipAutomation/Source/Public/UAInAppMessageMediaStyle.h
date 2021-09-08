/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "UAInAppMessageStyleProtocol.h"
#import "UAAirshipAutomationCoreImport.h"

@class UAPadding;

NS_ASSUME_NONNULL_BEGIN


/**
 * Model object representing a custom style to be applied
 * to an in-app message media component. Nil parameters are given
 * default styling.
 */
NS_SWIFT_NAME(InAppMessageMediaStyle)
@interface UAInAppMessageMediaStyle : NSObject

/**
 * Padding adds constant values to the media component's top, bottom, trailing or leading
 * constraints within its parent view.
 */
@property(nonatomic, strong, nullable) UAPadding *additionalPadding;

/**
 * Media style factory method.
 *
 * @param additionalPadding The media view additional padding.
 *
 * @return Media Style with specified styling. Nil parameters will be given
 * default styling.
 */
+ (instancetype)styleWithAdditionalPadding:(nullable UAPadding *)additionalPadding;

/**
 * Media style factory method for styling from a plist.
 *
 * @return Media Style with specified styling. Nil parameters will be given
 * default styling.
 */
+ (instancetype)styleWithDictionary:(nullable NSDictionary *)mediaStyleDict;

@end

NS_ASSUME_NONNULL_END
