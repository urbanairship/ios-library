/* Copyright 2017 Urban Airship and Contributors */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "UAInAppMessageDisplayContent.h"
#import "UAInAppMessageFullScreenDisplayContent.h"
#import "UAInAppMessageTextInfo.h"
#import "UAInAppMessageButtonInfo.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Builder class for a UAInAppMessageFullScreenDisplayContent.
 */
@interface UAInAppMessageFullScreenDisplayContentBuilder ()

/**
 * Applies fields from a JSON object.
 *
 * @param json The json object.
 * @param error The optional error.
 * @returns `YES` if the json was able to be applied, otherwise `NO`.
 */
- (BOOL)applyFromJSON:(id)json error:(NSError * _Nullable *)error;

@end

@interface UAInAppMessageFullScreenDisplayContent ()

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
 * The full screen's buttons. Defaults to UAInAppMessageButtonLayoutSeparate
 */
@property(nonatomic, copy, nullable) NSArray<UAInAppMessageButtonInfo *> *buttons;

/**
 * The full screen's button layout. Defaults to UAInAppMessageButtonLayoutSeparate.
 * If more than 2 buttons are supplied, defaults to UAInAppMessageButtonLayoutStacked.
 */
@property(nonatomic, copy, nullable) NSString *buttonLayout;

/**
 * The full screen's layout for the text and media. Defaults to
 * UAInAppMessageFullScreenContentLayoutHeaderMediaBody
 */
@property(nonatomic, copy, nullable) NSString *contentLayout;

/**
 * The full screen's background color. Defaults to white.
 */
@property(nonatomic, copy, nullable) NSString *backgroundColor;

/**
 * The full screen's dismiss button color. Defaults to black.
 */
@property(nonatomic, copy, nullable) NSString *dismissButtonColor;


@end

NS_ASSUME_NONNULL_END

