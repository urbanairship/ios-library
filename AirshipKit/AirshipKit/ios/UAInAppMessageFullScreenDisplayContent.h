/* Copyright 2018 Urban Airship and Contributors */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "UAInAppMessageDisplayContent.h"
#import "UAInAppMessageFullScreenDisplayContent.h"
#import "UAInAppMessageTextInfo.h"
#import "UAInAppMessageButtonInfo.h"
#import "UAInAppMessageMediaInfo.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Content layout.
 */
typedef NS_ENUM(NSInteger, UAInAppMessageFullScreenContentLayoutType) {
    /**
     * Header, Media, Body
     */
    UAInAppMessageFullScreenContentLayoutHeaderMediaBody,

    /**
     * Media, Header, Body
     */
    UAInAppMessageFullScreenContentLayoutMediaHeaderBody,

    /**
     * Header, Body, Media
     */
    UAInAppMessageFullScreenContentLayoutHeaderBodyMedia,
};

/**
 * Maximum number of button supported by a full screen.
 */
extern NSUInteger const UAInAppMessageFullScreenMaxButtons;

/**
 * Builder class for UAInAppMessageFullScreenDisplayContent.
 */
@interface UAInAppMessageFullScreenDisplayContentBuilder : NSObject

/**
 * The full screen's heading.
 */
@property(nonatomic, strong, nullable) UAInAppMessageTextInfo *heading;

/**
 * The full screen's body.
 */
@property(nonatomic, strong, nullable) UAInAppMessageTextInfo *body;

/**
 * The full screen's media.
 */
@property(nonatomic, strong, nullable) UAInAppMessageMediaInfo *media;

/**
 * The full screen's footer.
 */
@property(nonatomic, strong, nullable) UAInAppMessageButtonInfo *footer;

/**
 * The full screen's buttons.
 */
@property(nonatomic, copy, nullable) NSArray<UAInAppMessageButtonInfo *> *buttons;

/**
 * The full screen's button layout. Defaults to UAInAppMessageButtonLayoutSeparate.
 * If more than 2 buttons are supplied, defaults to UAInAppMessageButtonLayoutStacked.
 */
@property(nonatomic, assign) UAInAppMessageButtonLayoutType buttonLayout;

/**
 * The full screen's layout for the text and media. Defaults to
 * UAInAppMessageFullScreenContentLayoutHeaderMediaBody
 */
@property(nonatomic, assign) UAInAppMessageFullScreenContentLayoutType contentLayout;

/**
 * The full screen's background color. Defaults to white.
 */
@property(nonatomic, strong, nullable) UIColor *backgroundColor;

/**
 * The full screen's dismiss button color. Defaults to black.
 */
@property(nonatomic, strong, nullable) UIColor *dismissButtonColor;

/**
 * Checks if the builder is valid and will produce an display content instance.
 * @return YES if the builder is valid, otherwise NO.
 */
- (BOOL)isValid;

@end

/**
 * Display content for a full screen in-app message.
 */
@interface UAInAppMessageFullScreenDisplayContent : UAInAppMessageDisplayContent

/**
 * The full screen's heading.
 */
@property(nonatomic, strong, nullable, readonly) UAInAppMessageTextInfo *heading;

/**
 * The full screen's body.
 */
@property(nonatomic, strong, nullable, readonly) UAInAppMessageTextInfo *body;

/**
 * The full screen's media.
 */
@property(nonatomic, strong, nullable, readonly) UAInAppMessageMediaInfo *media;

/**
 * The full screen's footer.
 */
@property(nonatomic, strong, nullable, readonly) UAInAppMessageButtonInfo *footer;

/**
 * The full screen's buttons. Defaults to UAInAppMessageButtonLayoutSeparate
 */
@property(nonatomic, copy, nullable, readonly) NSArray<UAInAppMessageButtonInfo *> *buttons;

/**
 * The full screen's button layout. Defaults to UAInAppMessageButtonLayoutSeparate.
 * If more than 2 buttons are supplied, defaults to UAInAppMessageButtonLayoutStacked.
 */
@property(nonatomic, assign, readonly) UAInAppMessageButtonLayoutType buttonLayout;

/**
 * The full screen's layout for the text and media. Defaults to
 * UAInAppMessageFullScreenContentLayoutHeaderMediaBody
 */
@property(nonatomic, assign, readonly) UAInAppMessageFullScreenContentLayoutType contentLayout;

/**
 * The full screen's background color. Defaults to white.
 */
@property(nonatomic, strong, readonly) UIColor *backgroundColor;

/**
 * The full screen's dismiss button color. Defaults to black.
 */
@property(nonatomic, strong, readonly) UIColor *dismissButtonColor;

/**
 * Factory method for building full screen display content with builder block.
 *
 * @param builderBlock The builder block.
 *
 * @returns the display content if the builder block successfully built it, otherwise nil.
 */
+ (nullable instancetype)displayContentWithBuilderBlock:(void(^)(UAInAppMessageFullScreenDisplayContentBuilder *builder))builderBlock;

@end

NS_ASSUME_NONNULL_END

