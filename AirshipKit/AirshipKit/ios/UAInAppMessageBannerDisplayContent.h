/* Copyright 2018 Urban Airship and Contributors */

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
 */
@property(nonatomic, strong, nullable) UAInAppMessageTextInfo *heading;

/**
 * The banner's body.
 */
@property(nonatomic, strong, nullable) UAInAppMessageTextInfo *body;

/**
 * The banner's media.
 */
@property(nonatomic, strong, nullable) UAInAppMessageMediaInfo *media;

/**
 * The banner's buttons.
 */
@property(nonatomic, copy, nullable) NSArray<UAInAppMessageButtonInfo *> *buttons;

/**
 * The banner's button layout. Defaults to UAInAppMessageButtonLayoutSeparate
 */
@property(nonatomic, assign) UAInAppMessageButtonLayoutType buttonLayout;

/**
 * The banner's placement. Defaults to UAInAppMessageBannerPlacementBottom
 */
@property(nonatomic, assign) UAInAppMessageBannerPlacementType placement;

/**
 * The banner's layout for the text and media. Defaults to
 * UAInAppMessageBannerContentLayoutTypeMediaLeft
 */
@property(nonatomic, assign) UAInAppMessageBannerContentLayoutType contentLayout;

/**
 * The banner's display duration. Defaults to UAInAppMessageBannerDefaultDuration.
 */
@property(nonatomic, assign) NSUInteger duration;

/**
 * The banner's background color. Defaults to white.
 */
@property(nonatomic, strong, nullable) UIColor *backgroundColor;

/**
 * The banner's dismiss button color. Defaults to black.
 */
@property(nonatomic, strong, nullable) UIColor *dismissButtonColor;

/**
 * The banner's border radius. Defaults to 0.
 */
@property(nonatomic, assign) NSUInteger borderRadius;

/**
 * The banner's actions.
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
 */
@interface UAInAppMessageBannerDisplayContent : UAInAppMessageDisplayContent

/**
 * The banner's heading.
 */
@property(nonatomic, strong, nullable, readonly) UAInAppMessageTextInfo *heading;

/**
 * The banner's body.
 */
@property(nonatomic, strong, nullable, readonly) UAInAppMessageTextInfo *body;

/**
 * The banner's media.
 */
@property(nonatomic, strong, nullable, readonly) UAInAppMessageMediaInfo *media;

/**
 * The banner's buttons. Defaults to UAInAppMessageButtonLayoutSeparate
 */
@property(nonatomic, copy, nullable, readonly) NSArray<UAInAppMessageButtonInfo *> *buttons;

/**
 * The banner's button layout.
 */
@property(nonatomic, assign, readonly) UAInAppMessageButtonLayoutType buttonLayout;

/**
 * The banner's placement. Defaults to UAInAppMessageBannerPlacementBottom
 */
@property(nonatomic, assign, readonly) UAInAppMessageBannerPlacementType placement;

/**
 * The banner's layout for the text and media. Defaults to
 * UAInAppMessageBannerContentLayoutTypeMediaLeft
 */
@property(nonatomic, assign, readonly) UAInAppMessageBannerContentLayoutType contentLayout;

/**
 * The banner's display duration. Defaults to UAInAppMessageBannerDefaultDuration.
 */
@property(nonatomic, assign, readonly) NSUInteger duration;

/**
 * The banner's background color. Defaults to white.
 */
@property(nonatomic, strong, nullable, readonly) UIColor *backgroundColor;

/**
 * The banner's dismiss button color. Defaults to black.
 */
@property(nonatomic, strong, nullable, readonly) UIColor *dismissButtonColor;

/**
 * The banner's border radius. Defaults to 0.
 */
@property(nonatomic, assign, readonly) NSUInteger borderRadius;

/**
 * The banner's actions.
 */
@property(nonatomic, copy, nullable, readonly) NSDictionary *actions;


/**
 * Factory method for building banner display content with builder block.
 *
 * @param builderBlock The builder block.
 *
 * @returns the display content if the builder block successfully built it, otherwise nil.
 */
+ (nullable instancetype)displayContentWithBuilderBlock:(void(^)(UAInAppMessageBannerDisplayContentBuilder *builder))builderBlock;

@end

NS_ASSUME_NONNULL_END

