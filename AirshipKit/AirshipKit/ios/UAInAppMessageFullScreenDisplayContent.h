/* Copyright Urban Airship and Contributors */

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
 *
 * Optional.
 */
@property(nonatomic, strong, nullable) UAInAppMessageTextInfo *heading;

/**
 * The full screen's body.
 *
 * Optional.
 */
@property(nonatomic, strong, nullable) UAInAppMessageTextInfo *body;

/**
 * The full screen's media.
 *
 * Optional.
 */
@property(nonatomic, strong, nullable) UAInAppMessageMediaInfo *media;

/**
 * The full screen's footer.
 *
 * Optional. Defaults to nil.
 */
@property(nonatomic, strong, nullable) UAInAppMessageButtonInfo *footer;

/**
 * The full screen's buttons.
 *
 * Required.
 */
@property(nonatomic, copy, nullable) NSArray<UAInAppMessageButtonInfo *> *buttons;

/**
 * The full screen's button layout.
 *
 * Optional. Defaults to UAInAppMessageButtonLayoutSeparate.
 * If more than 2 buttons are supplied, forces to UAInAppMessageButtonLayoutStacked.
 */
@property(nonatomic, assign) UAInAppMessageButtonLayoutType buttonLayout;

/**
 * The full screen's layout for the text and media.
 *
 * Optional. Defaults to UAInAppMessageFullScreenContentLayoutHeaderMediaBody
 */
@property(nonatomic, assign) UAInAppMessageFullScreenContentLayoutType contentLayout;

/**
 * The full screen's background color.
 *
 * Optional. Defaults to white.
 */
@property(nonatomic, strong) UIColor *backgroundColor;

/**
 * The full screen's dismiss button color.
 *
 * Optional. Defaults to black.
 */
@property(nonatomic, strong) UIColor *dismissButtonColor;

/**
 * Checks if the builder is valid and will produce an display content instance.
 * @return YES if the builder is valid, otherwise NO.
 */
- (BOOL)isValid;

@end

/**
 * Display content for a full screen in-app message.
 *
 * @note This object is built using `UAInAppMessageFullScreenDisplayContentBuilder`.
 */
@interface UAInAppMessageFullScreenDisplayContent : UAInAppMessageDisplayContent

/**
 * The full screen's heading.
 */
@property(nonatomic, nullable, readonly) UAInAppMessageTextInfo *heading;

/**
 * The full screen's body.
 */
@property(nonatomic, nullable, readonly) UAInAppMessageTextInfo *body;

/**
 * The full screen's media.
 */
@property(nonatomic, nullable, readonly) UAInAppMessageMediaInfo *media;

/**
 * The full screen's footer.
 */
@property(nonatomic, nullable, readonly) UAInAppMessageButtonInfo *footer;

/**
 * The full screen's buttons.
 */
@property(nonatomic, readonly) NSArray<UAInAppMessageButtonInfo *> *buttons;

/**
 * The full screen's button layout.
 *
 * Optional. Defaults to UAInAppMessageButtonLayoutSeparate.
 * If more than 2 buttons are supplied, forces to UAInAppMessageButtonLayoutStacked.
 */
@property(nonatomic, readonly) UAInAppMessageButtonLayoutType buttonLayout;

/**
 * The full screen's layout for the text and media.
 *
 * Optional. Defaults to UAInAppMessageFullScreenContentLayoutHeaderMediaBody
 */
@property(nonatomic, readonly) UAInAppMessageFullScreenContentLayoutType contentLayout;

/**
 * The full screen's background color.
 *
 * Optional. Defaults to white.
 */
@property(nonatomic, readonly) UIColor *backgroundColor;

/**
 * The full screen's dismiss button color.
 *
 * Optional. Defaults to black.
 */
@property(nonatomic, readonly) UIColor *dismissButtonColor;

/**
 * Factory method for building full screen display content with a builder block.
 *
 * @param builderBlock The builder block.
 * @return The display content if the builder block successfully built it, otherwise nil.
 */
+ (nullable instancetype)displayContentWithBuilderBlock:(void(^)(UAInAppMessageFullScreenDisplayContentBuilder *builder))builderBlock;

/**
 * Extends a full screen display content with a builder block.
 *
 * @param builderBlock The builder block.
 * @return An extended instance of UAInAppMessageFullScreenDisplayContent.
 */
- (nullable UAInAppMessageFullScreenDisplayContent *)extend:(void(^)(UAInAppMessageFullScreenDisplayContentBuilder *builder))builderBlock;

@end

NS_ASSUME_NONNULL_END

