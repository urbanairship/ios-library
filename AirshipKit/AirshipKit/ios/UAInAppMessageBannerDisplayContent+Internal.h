/* Copyright 2017 Urban Airship and Contributors */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "UAInAppMessageDisplayContent.h"
#import "UAInAppMessageBannerDisplayContent.h"
#import "UAInAppMessageTextInfo.h"
#import "UAInAppMessageButtonInfo.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Builder class for a UAInAppMessageBannerDisplayContent.
 */
@interface UAInAppMessageBannerDisplayContentBuilder ()

/**
 * Applies fields from a JSON object.
 *
 * @param json The json object.
 * @param error The optional error.
 * @returns `YES` if the json was able to be applied, otherwise `NO`.
 */
- (BOOL)applyFromJSON:(id)json error:(NSError * _Nullable *)error;

@end

@interface UAInAppMessageBannerDisplayContent ()

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
@property(nonatomic, copy, nullable) NSString *placement;

/**
 * The banner's layout for the text and media. Defaults to
 * UAInAppMessageBannerContentLayoutMediaLeft
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

NS_ASSUME_NONNULL_END
