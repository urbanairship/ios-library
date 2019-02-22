/* Copyright Urban Airship and Contributors */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "UAInAppMessageDisplayContent.h"
#import "UAInAppMessageBannerDisplayContent.h"
#import "UAInAppMessageTextInfo.h"
#import "UAInAppMessageButtonInfo.h"
#import "UAInAppMessageMediaInfo.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Banner placement.
 */
typedef NS_ENUM(NSInteger, UAInAppMessageBannerPlacementType) {
    /**
     * Banner placement top
     */
    UAInAppMessageBannerPlacementTop,

    /**
     * Banner placement bottom
     */
    UAInAppMessageBannerPlacementBottom,
};

/**
 * Content layout.
 */
typedef NS_ENUM(NSInteger, UAInAppMessageBannerContentLayoutType) {
    /**
     * Media on the left
     */
    UAInAppMessageBannerContentLayoutTypeMediaLeft,

    /**
     * Media on the right
     */
    UAInAppMessageBannerContentLayoutTypeMediaRight,
};

/**
 * Maximum number of button supported by a banner.
 */
extern NSUInteger const UAInAppMessageBannerMaxButtons;

/**
 * Builder class for UAInAppMessageBannerDisplayContent.
 */
@interface UAInAppMessageBannerDisplayContentBuilder : NSObject

/**
 * The banner's heading.
 *
 * Optional. Defaults to nil.
 */
@property(nonatomic, strong, nullable) UAInAppMessageTextInfo *heading;

/**
 * The banner's body.
 *
 * Optional. Defaults to nil.
 */
@property(nonatomic, strong, nullable) UAInAppMessageTextInfo *body;

/**
 * The banner's media.
 *
 * Optional. Defaults to nil.
 */
@property(nonatomic, strong, nullable) UAInAppMessageMediaInfo *media;

/**
 * The banner's buttons.
 *
 * Required.
 */
@property(nonatomic, copy, nullable) NSArray<UAInAppMessageButtonInfo *> *buttons;

/**
 * The banner's button layout.
 *
 * Optional. Defaults to UAInAppMessageButtonLayoutSeparate.
 */
@property(nonatomic, assign) UAInAppMessageButtonLayoutType buttonLayout;

/**
 * The banner's placement.
 *
 * Optional. Defaults to UAInAppMessageBannerPlacementBottom.
 */
@property(nonatomic, assign) UAInAppMessageBannerPlacementType placement;

/**
 * The banner's layout for the text and media.
 *
 * Optional. Defaults to UAInAppMessageBannerContentLayoutTypeMediaLeft.
 */
@property(nonatomic, assign) UAInAppMessageBannerContentLayoutType contentLayout;

/**
 * The banner's display duration in seconds.
 *
 * Optional. Defaults to 30 seconds.
 *
 * @deprecated Deprecated - to be removed in SDK version 11.0. Please use `durationSeconds`.
 */
@property(nonatomic, assign) NSUInteger duration DEPRECATED_MSG_ATTRIBUTE("Deprecated - to be removed in SDK version 11.0. Please use durationSeconds.");

/**
 * The banner's display duration in seconds.
 *
 * Optional. Defaults to 30 seconds.
 */
@property(nonatomic, assign) NSTimeInterval durationSeconds;

/**
 * The banner's background color.
 *
 * Optional. Defaults to white.
 */
@property(nonatomic, strong) UIColor *backgroundColor;

/**
 * The banner's dismiss button color.
 *
 * Optional. Defaults to black.
 */
@property(nonatomic, strong) UIColor *dismissButtonColor;

/**
 * The banner's border radius.
 *
 * Optional. Defaults to 0.
 *
 * @deprecated Deprecated - to be removed in SDK version 11.0. Please use `borderRadiusPoints`.
 */
@property(nonatomic, assign) NSUInteger borderRadius DEPRECATED_MSG_ATTRIBUTE("Deprecated - to be removed in SDK version 11.0. Please use borderRadiusPoints.");

/**
 * The banner's border radius. Use to set the border radius
 * to non-integer values.
 *
 * Optional. Defaults to 0.
 */
@property(nonatomic, assign) CGFloat borderRadiusPoints;

/**
 * The banner's actions. Only supported for Legacy In-App Messaging.
 *
 * Optional.
 */
@property(nonatomic, copy, nullable) NSDictionary *actions;

/**
 * Checks if the builder is valid and will produce an display content instance.
 * @return YES if the builder is valid, otherwise NO.
 */
- (BOOL)isValid;

@end

/**
 * Display content for a banner in-app message.
 *
 * @note This object is built using `UAInAppMessageBannerDisplayContentBuilder`.
 */
@interface UAInAppMessageBannerDisplayContent : UAInAppMessageDisplayContent

/**
 * The banner's heading.
 */
@property(nonatomic, nullable, readonly) UAInAppMessageTextInfo *heading;

/**
 * The banner's body.
 */
@property(nonatomic, nullable, readonly) UAInAppMessageTextInfo *body;

/**
 * The banner's media.
 */
@property(nonatomic, nullable, readonly) UAInAppMessageMediaInfo *media;

/**
 * The banner's buttons.
 */
@property(nonatomic, readonly) NSArray<UAInAppMessageButtonInfo *> *buttons;

/**
 * The banner's button layout. Defaults to UAInAppMessageButtonLayoutSeparate.
 */
@property(nonatomic, readonly) UAInAppMessageButtonLayoutType buttonLayout;

/**
 * The banner's placement.
 */
@property(nonatomic, readonly) UAInAppMessageBannerPlacementType placement;

/**
 * The banner's layout for the text and media.
 */
@property(nonatomic, readonly) UAInAppMessageBannerContentLayoutType contentLayout;

/**
 * The banner's display duration in seconds.
 *
 * @deprecated Deprecated - to be removed in SDK version 11.0. Please use `durationSeconds`.
 */
@property(nonatomic, readonly) NSUInteger duration DEPRECATED_MSG_ATTRIBUTE("Deprecated - to be removed in SDK version 11.0. Please use durationSeconds.");

/**
 * The banner's display duration in seconds.
 */
@property(nonatomic, readonly) NSTimeInterval durationSeconds;


/**
 * The banner's background color.
 */
@property(nonatomic, readonly) UIColor *backgroundColor;

/**
 * The banner's dismiss button color.
 */
@property(nonatomic, readonly) UIColor *dismissButtonColor;

/**
 * The banner's border radius.
 *
 * @deprecated Deprecated - to be removed in SDK version 11.0. Please use `borderRadiusPoints`.
 */
@property(nonatomic, assign, readonly) NSUInteger borderRadius DEPRECATED_MSG_ATTRIBUTE("Deprecated - to be removed in SDK version 11.0. Please use borderRadiusPoints.");

/**
 * The banner's border radius in points.
 */
@property(nonatomic, assign, readonly) CGFloat borderRadiusPoints;

/**
 * The banner's actions. Only supported for Legacy In-App Messaging.
 */
@property(nonatomic, nullable, readonly) NSDictionary *actions;

/**
 * Factory method for building banner display content with a builder block.
 *
 * @param builderBlock The builder block.
 * @return The display content if the builder block successfully built it, otherwise nil.
 */
+ (nullable instancetype)displayContentWithBuilderBlock:(void(^)(UAInAppMessageBannerDisplayContentBuilder *builder))builderBlock;

/**
 * Extends a banner display content with a builder block.
 *
 * @param builderBlock The builder block.
 * @return An extended instance of UAInAppMessageBannerDisplayContent.
 */
- (nullable UAInAppMessageBannerDisplayContent *)extend:(void(^)(UAInAppMessageBannerDisplayContentBuilder *builder))builderBlock;

@end

NS_ASSUME_NONNULL_END

