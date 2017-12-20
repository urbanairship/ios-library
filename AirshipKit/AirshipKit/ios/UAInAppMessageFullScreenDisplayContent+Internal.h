/* Copyright 2017 Urban Airship and Contributors */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "UAInAppMessageDisplayContent.h"
#import "UAInAppMessageFullScreenDisplayContent.h"
#import "UAInAppMessageTextInfo.h"
#import "UAInAppMessageButtonInfo.h"

NS_ASSUME_NONNULL_BEGIN

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
@property(nonatomic, assign) UAInAppMessageButtonLayoutType buttonLayout;

/**
 * The full screen's layout for the text and media. Defaults to
 * UAInAppMessageFullScreenContentLayoutHeaderMediaBody
 */
@property(nonatomic, assign) UAInAppMessageFullScreenContentLayoutType contentLayout;

/**
 * The full screen's background color. Defaults to white.
 */
@property(nonatomic, strong) UIColor *backgroundColor;

/**
 * The full screen's dismiss button color. Defaults to black.
 */
@property(nonatomic, strong) UIColor *dismissButtonColor;


@end

NS_ASSUME_NONNULL_END

