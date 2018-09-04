/* Copyright 2018 Urban Airship and Contributors */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#import "UAInAppMessageDisplayContent.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Builder class for UAInAppMessageHTMLDisplayContent.
 */
@interface UAInAppMessageHTMLDisplayContentBuilder : NSObject

/**
 * The message's background color. Defaults to white.
 */
@property(nonatomic, strong, nullable) UIColor *backgroundColor;

/**
 * The message's dismiss button color. Defaults to black.
 */
@property(nonatomic, strong, nullable) UIColor *dismissButtonColor;

/**
 * The message's URL.
 */
@property(nonatomic, copy, nullable) NSString *url;

/**
 * The HTML message's border radius. Defaults to 0.
 */
@property(nonatomic, assign) NSUInteger borderRadius;

/**
 * Flag indicating the HTML view should display as full screen on compact devices.
 * Defaults to NO.
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
 */
@interface UAInAppMessageHTMLDisplayContent : UAInAppMessageDisplayContent

/**
 * The message's URL.
 */
@property(nonatomic, copy, readonly) NSString *url;

/**
 * The message's background color. Defaults to white.
 */
@property(nonatomic, strong, readonly) UIColor *backgroundColor;

/**
 * The message's dismiss button color. Defaults to black.
 */
@property(nonatomic, strong, readonly) UIColor *dismissButtonColor;

/**
 * The HTML message's border radius. Defaults to 0.
 */
@property(nonatomic, assign, readonly) NSUInteger borderRadius;

/**
 * Flag indicating the HTML view should display as full screen on compact devices.
 * Defaults to NO.
 */
@property(nonatomic, assign, readonly) BOOL allowFullScreenDisplay;

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
- (UAInAppMessageHTMLDisplayContent *)extend:(void(^)(UAInAppMessageHTMLDisplayContentBuilder *builder))builderBlock;

@end

NS_ASSUME_NONNULL_END

