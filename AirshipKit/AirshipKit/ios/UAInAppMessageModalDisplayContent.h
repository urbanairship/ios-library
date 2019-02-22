/* Copyright Urban Airship and Contributors */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "UAInAppMessageDisplayContent.h"
#import "UAInAppMessageModalDisplayContent.h"
#import "UAInAppMessageTextInfo.h"
#import "UAInAppMessageButtonInfo.h"
#import "UAInAppMessageMediaInfo.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Content layout.
 */
typedef NS_ENUM(NSInteger, UAInAppMessageModalContentLayoutType) {
    /**
     * Header, Media, Body
     */
    UAInAppMessageModalContentLayoutHeaderMediaBody,

    /**
     * Media, Header, Body
     */
    UAInAppMessageModalContentLayoutMediaHeaderBody,

    /**
     * Header, Body, Media
     */
    UAInAppMessageModalContentLayoutHeaderBodyMedia,
};

/**
 * Maximum number of button supported by a modal message.
 */
extern NSUInteger const UAInAppMessageModalMaxButtons;

/**
 * Builder class for UAInAppMessageModalDisplayContent.
 */
@interface UAInAppMessageModalDisplayContentBuilder : NSObject

/**
 * The modal message's heading.
 *
 * Optional.
 */
@property(nonatomic, strong, nullable) UAInAppMessageTextInfo *heading;

/**
 * The modal message's body.
 *
 * Optional.
 */
@property(nonatomic, strong, nullable) UAInAppMessageTextInfo *body;

/**
 * The modal message's media.
 *
 * Optional.
 */
@property(nonatomic, strong, nullable) UAInAppMessageMediaInfo *media;

/**
 * The modal message's footer.
 *
 * Optional. Defaults to nil.
 */
@property(nonatomic, strong, nullable) UAInAppMessageButtonInfo *footer;

/**
 * The modal message's buttons.
 *
 * Required
 */
@property(nonatomic, copy, nullable) NSArray<UAInAppMessageButtonInfo *> *buttons;

/**
 * The modal message's button layout.
 *
 * Optional. Defaults to UAInAppMessageButtonLayoutSeparate.
 */
@property(nonatomic, assign) UAInAppMessageButtonLayoutType buttonLayout;

/**
 * The modal message's layout for the text and media.
 *
 * Optional. Defaults to UAInAppMessageModalContentLayoutHeaderMediaBody.
 */
@property(nonatomic, assign) UAInAppMessageModalContentLayoutType contentLayout;

/**
 * The modal message's background color.
 *
 * Optional. Defaults to white.
 */
@property(nonatomic, strong) UIColor *backgroundColor;

/**
 * The modal message's dismiss button color.
 *
 * Optional. Defaults to black.
 */
@property(nonatomic, strong) UIColor *dismissButtonColor;

/**
 * The modal message's border radius.
 *
 * Optional. Defaults to 0.
 *
 * @deprecated Deprecated - to be removed in SDK version 11.0. Please use `borderRadiusPoints`.
 */
@property(nonatomic, assign) NSUInteger borderRadius DEPRECATED_MSG_ATTRIBUTE("Deprecated - to be removed in SDK version 11.0. Please use borderRadiusPoints.");

/**
 * The modal message's border radius. Use to set the border radius
 * to non-integer values.
 *
 * Optional. Defaults to 0.
 */
@property(nonatomic, assign) CGFloat borderRadiusPoints;

/**
 * Flag indicating the modal should display as full screen on compact devices.
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
 * Display content for a modal in-app message.
 *
 * @note This object is built using `UAInAppMessageModalDisplayContentBuilder`.
 */
@interface UAInAppMessageModalDisplayContent : UAInAppMessageDisplayContent

/**
 * The modal message's heading.
 */
@property(nonatomic, nullable, readonly) UAInAppMessageTextInfo *heading;

/**
 * The modal message's body.
 */
@property(nonatomic, nullable, readonly) UAInAppMessageTextInfo *body;

/**
 * The modal message's media.
 */
@property(nonatomic, nullable, readonly) UAInAppMessageMediaInfo *media;

/**
 * The modal message's footer.
 */
@property(nonatomic, nullable, readonly) UAInAppMessageButtonInfo *footer;

/**
 * The modal message's buttons.
 */
@property(nonatomic, readonly) NSArray<UAInAppMessageButtonInfo *> *buttons;

/**
 * The modal message's button layout.
 */
@property(nonatomic, readonly) UAInAppMessageButtonLayoutType buttonLayout;

/**
 * The modal message's layout for the text and media.
 */
@property(nonatomic, readonly) UAInAppMessageModalContentLayoutType contentLayout;

/**
 * The modal message's background color.
 */
@property(nonatomic, readonly) UIColor *backgroundColor;

/**
 * The modal message's dismiss button color.
 */
@property(nonatomic, readonly) UIColor *dismissButtonColor;

/**
 * The modal message's border radius.
 *
 * @deprecated Deprecated - to be removed in SDK version 11.0. Please use `borderRadiusPoints`.
 */
@property(nonatomic, assign, readonly) NSUInteger borderRadius DEPRECATED_MSG_ATTRIBUTE("Deprecated - to be removed in SDK version 11.0. Please use borderRadiusPoints.");

/**
 * The modal message's border radius in points.
 */
@property(nonatomic, assign, readonly) CGFloat borderRadiusPoints;

/**
 * Flag indicating the modal should display as full screen on compact devices.
 */
@property(nonatomic, readonly) BOOL allowFullScreenDisplay;

/**
 * Factory method for building modal message display content with a builder block.
 *
 * @param builderBlock The builder block.
 * @return The display content if the builder block successfully built it, otherwise nil.
 */
+ (nullable instancetype)displayContentWithBuilderBlock:(void(^)(UAInAppMessageModalDisplayContentBuilder *builder))builderBlock;

/**
 * Extends a modal display content with a builder block.
 *
 * @param builderBlock The builder block.
 * @return An extended instance of UAInAppMessageModalDisplayContent.
 */
- (nullable UAInAppMessageModalDisplayContent *)extend:(void(^)(UAInAppMessageModalDisplayContentBuilder *builder))builderBlock;

@end

NS_ASSUME_NONNULL_END

