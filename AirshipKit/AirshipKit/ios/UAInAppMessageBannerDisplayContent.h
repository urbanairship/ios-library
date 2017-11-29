/* Copyright 2017 Urban Airship and Contributors */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "UAInAppMessageDisplayContent.h"
#import "UAInAppMessageBannerDisplayContent.h"
#import "UAInAppMessageTextInfo.h"
#import "UAInAppMessageButtonInfo.h"
#import "UAInAppMessageMediaInfo.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents the possible error conditions when deserializing display content from JSON.
 */
typedef NS_ENUM(NSInteger, UAInAppMessageBannerDisplayContentErrorCode) {
    /**
     * Indicates an error with the display content info JSON definition.
     */
    UAInAppMessageBannerDisplayContentErrorCodeInvalidJSON,
};

/**
 * Display the message on top of the screen.
 */
extern NSString *const UAInAppMessageBannerPlacementTop;

/**
 * Display the message on bottom of the screen.
 */
extern NSString *const UAInAppMessageBannerPlacementBottom;

/**
 * Template to display the optional media on the left.
 */
extern NSString *const UAInAppMessageBannerContentLayoutMediaLeft;

/**
 * Template to display the optional media on the right.
 */
extern NSString *const UAInAppMessageBannerContentLayoutMediaRight;

/**
 * Default duration in milliseconds.
 */
extern NSUInteger const UAInAppMessageBannerDefaultDuration;

/**
 * Maximum number of button supported by a banner.
 */
extern NSUInteger const UAInAppMessageBannerMaxButtons;

/**
 * JSON key for actions. Not supported in the API but is needed for compatibility of v1 banners.
 */
extern NSString *const UAInAppMessageBannerActions;

/**
 * Builder class for a UAInAppMessageBannerDisplayContent.
 */
@interface UAInAppMessageBannerDisplayContentBuilder : NSObject

/**
 * The banner's heading.
 */
@property(nonatomic, strong, nullable) UAInAppMessageTextInfo *heading;

/**
 * The banner's body.
 */
@property(nonatomic, strong) UAInAppMessageTextInfo *body;

/**
 * The banner's media.
 */
@property(nonatomic, strong, nullable) UAInAppMessageMediaInfo *media;

/**
 * The banner's buttons. Defaults to UAInAppMessageButtonLayoutSeparate
 */
@property(nonatomic, copy, nullable) NSArray<UAInAppMessageButtonInfo *> *buttons;

/**
 * The banner's button layout.
 */
@property(nonatomic, copy, nullable) NSString *buttonLayout;

/**
 * The banner's placement. Defaults to UAInAppMessageBannerPlacementBottom
 */
@property(nonatomic, copy) NSString *placement;

/**
 * The banner's layout for the text and media. Defaults to
 * UAInAppMessageBannerImageLeft
 */
@property(nonatomic, copy, nullable) NSString *contentLayout;

/**
 * The banner's display duration. Defaults to UAInAppMessageBannerDefaultDuration.
 */
@property(nonatomic, assign) NSUInteger duration;

/**
 * The banner's background color. Defaults to white.
 */
@property(nonatomic, copy, nullable) NSString *backgroundColor;

/**
 * The banner's dismiss button color. Defaults to black.
 */
@property(nonatomic, copy, nullable) NSString *dismissButtonColor;

/**
 * The banner's border radius. Defaults to 0.
 */
@property(nonatomic, assign) NSUInteger borderRadius;

/**
 * The banner's actions.
 */
@property(nonatomic, copy, nullable) NSDictionary *actions;

@end

/**
 * Display content for a in-app message banner.
 */
@interface UAInAppMessageBannerDisplayContent : UAInAppMessageDisplayContent

/**
 * Factory method for building banner display content with JSON.
 *
 * @param json The json object.
 * @param error The optional error.
 * @returns `YES` if the json was able to be applied, otherwise `NO`.
 */
+ (instancetype)bannerDisplayContentWithJSON:(id)json error:(NSError **)error;

/**
 * Factory method to create a JSON dictionary from an in-app message banner display content.
 *
 * @param displayContent An in-app message banner display content.
 * @return The JSON dictionary.
 */
+ (NSDictionary *)JSONWithBannerDisplayContent:(UAInAppMessageBannerDisplayContent *_Nonnull)displayContent;

/**
 * Factory method for building banner display content with JSON.
 *
 * @param builderBlock The builder block.
 */
+ (instancetype)bannerDisplayContentWithBuilderBlock:(void(^)(UAInAppMessageBannerDisplayContentBuilder *builder))builderBlock;

@end

NS_ASSUME_NONNULL_END

