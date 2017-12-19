/* Copyright 2017 Urban Airship and Contributors */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "UAInAppMessageDisplayContent.h"
#import "UAInAppMessageFullScreenDisplayContent.h"
#import "UAInAppMessageTextInfo.h"
#import "UAInAppMessageButtonInfo.h"
#import "UAInAppMessageMediaInfo.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents the possible error conditions when deserializing display content from JSON.
 */
typedef NS_ENUM(NSInteger, UAInAppMessageFullScreenDisplayContentErrorCode) {
    /**
     * Indicates an error with the display content info JSON definition.
     */
    UAInAppMessageFullScreenDisplayContentErrorCodeInvalidJSON,
};

/**
 * Template with display order of header, media, body, buttons, footer.
 */
extern NSString *const UAInAppMessageFullScreenContentLayoutHeaderMediaBody;

/**
 * Template with display order of media, header, body, buttons, footer.
 */
extern NSString *const UAInAppMessageFullScreenContentLayoutMediaHeaderBody;

/**
 * Template with display order of header, body, media, buttons, footer.
 */
extern NSString *const UAInAppMessageFullScreenContentLayoutHeaderBodyMedia;

/**
 * Maximum number of button supported by a full screen.
 */
extern NSUInteger const UAInAppMessageFullScreenMaxButtons;

/**
 * Builder class for a UAInAppMessageFullScreenDisplayContent.
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

/**
 * Display content for a in-app message full screen.
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
@property(nonatomic, copy, nullable, readonly) NSString *buttonLayout;

/**
 * The full screen's layout for the text and media. Defaults to
 * UAInAppMessageFullScreenContentLayoutHeaderMediaBody
 */
@property(nonatomic, copy, nullable, readonly) NSString *contentLayout;

/**
 * The full screen's background color. Defaults to white.
 */
@property(nonatomic, copy, nullable, readonly) NSString *backgroundColor;

/**
 * The full screen's dismiss button color. Defaults to black.
 */
@property(nonatomic, copy, nullable, readonly) NSString *dismissButtonColor;

/**
 * Factory method for building full screen display content with JSON.
 *
 * @param json The json object.
 * @param error The optional error.
 * @returns `YES` if the json was able to be applied, otherwise `NO`.
 */
+ (instancetype)fullScreenDisplayContentWithJSON:(id)json error:(NSError **)error;

/**
 * Factory method for building full screen display content with builder block.
 *
 * @param builderBlock The builder block.
 */
+ (instancetype)fullScreenDisplayContentWithBuilderBlock:(void(^)(UAInAppMessageFullScreenDisplayContentBuilder *builder))builderBlock;

@end

NS_ASSUME_NONNULL_END

