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
 * Factory method for building HTML display content with builder block.
 *
 * @param builderBlock The builder block.
 *
 * @returns the display content if the builder block successfully built it, otherwise nil.
 */
+ (nullable instancetype)displayContentWithBuilderBlock:(void(^)(UAInAppMessageHTMLDisplayContentBuilder *builder))builderBlock;

@end

NS_ASSUME_NONNULL_END

