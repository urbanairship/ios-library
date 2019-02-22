/* Copyright Urban Airship and Contributors */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#import "UAInAppMessageDisplayContent.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Builder class for UAInAppMessageHTMLDisplayContent.
 */
@interface UAInAppMessageHTMLDisplayContentBuilder : NSObject

/**
 * The message's URL.
 *
 * Required
 */
@property(nonatomic, copy, nullable) NSString *url;

/**
 * The message's background color.
 *
 * Optional. Defaults to white.
 */
@property(nonatomic, strong) UIColor *backgroundColor;

/**
 * The message's dismiss button color.
 *
 * Optional. Defaults to black.
 */
@property(nonatomic, strong) UIColor *dismissButtonColor;

/**
 * The HTML message's border radius.
 *
 * Optional. Defaults to 0.
 *
 * @deprecated Deprecated - to be removed in SDK version 11.0. Please use `borderRadiusPoints`.
 */
@property(nonatomic, assign) NSUInteger borderRadius DEPRECATED_MSG_ATTRIBUTE("Deprecated - to be removed in SDK version 11.0. Please use borderRadiusPoints.");

/**
 * The HTML message's border radius. Use to set the border radius
 * to non-integer values.
 *
 * Optional. Defaults to 0.
 */
@property(nonatomic, assign) CGFloat borderRadiusPoints;

/**
 * Flag indicating the HTML view should display as full screen on compact devices.
 *
 * Optional. Defaults to `NO`.
 */
@property(nonatomic, assign) BOOL allowFullScreenDisplay;

/**
 * Checks if the builder is valid and will produce an display content instance.
 * @return YES if the builder is valid, otherwise NO.
 */
- (BOOL)isValid;

@end

/**
 * Display content for an HTML in-app message.
 *
 * @note This object is built using `UAInAppMessageHTMLDisplayContentBuilder`.
 */
@interface UAInAppMessageHTMLDisplayContent : UAInAppMessageDisplayContent

/**
 * The message's URL.
 */
@property(nonatomic, readonly) NSString *url;

/**
 * The message's background color.
 */
@property(nonatomic, readonly) UIColor *backgroundColor;

/**
 * The message's dismiss button color.
 */
@property(nonatomic, readonly) UIColor *dismissButtonColor;

/**
 * The HTML message's border radius.
 *
 * @deprecated Deprecated - to be removed in SDK version 11.0. Please use `borderRadiusPoints`.
 */
@property(nonatomic, readonly) NSUInteger borderRadius DEPRECATED_MSG_ATTRIBUTE("Deprecated - to be removed in SDK version 11.0. Please use borderRadiusPoints.");

/**
 * The HTML message's border radius.
 */
@property(nonatomic, readonly) CGFloat borderRadiusPoints;

/**
 * Flag indicating the HTML view should display as full screen on compact devices.
 */
@property(nonatomic, readonly) BOOL allowFullScreenDisplay;

/**
 * Factory method for building HTML display content with a builder block.
 *
 * @param builderBlock The builder block.
 * @return the display content if the builder block successfully built it, otherwise nil.
 */
+ (nullable instancetype)displayContentWithBuilderBlock:(void(^)(UAInAppMessageHTMLDisplayContentBuilder *builder))builderBlock;

/**
 * Extends an HTML display content with a builder block.
 *
 * @param builderBlock The builder block.
 * @return An extended instance of UAInAppMessageHTMLDisplayContent.
 */
- (nullable UAInAppMessageHTMLDisplayContent *)extend:(void(^)(UAInAppMessageHTMLDisplayContentBuilder *builder))builderBlock;

@end

NS_ASSUME_NONNULL_END

