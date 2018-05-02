/* Copyright 2018 Urban Airship and Contributors */

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
 */
@property(nonatomic, strong, nullable) UAInAppMessageTextInfo *heading;

/**
 * The modal message's body.
 */
@property(nonatomic, strong, nullable) UAInAppMessageTextInfo *body;

/**
 * The modal message's media.
 */
@property(nonatomic, strong, nullable) UAInAppMessageMediaInfo *media;

/**
 * The modal message's footer.
 */
@property(nonatomic, strong, nullable) UAInAppMessageButtonInfo *footer;

/**
 * The modal message's buttons.
 */
@property(nonatomic, copy, nullable) NSArray<UAInAppMessageButtonInfo *> *buttons;

/**
 * The modal message's button layout. Defaults to UAInAppMessageButtonLayoutSeparate.
 */
@property(nonatomic, assign) UAInAppMessageButtonLayoutType buttonLayout;

/**
 * The modal message's layout for the text and media. Defaults to
 * UAInAppMessageModalContentLayoutHeaderMediaBody
 */
@property(nonatomic, assign) UAInAppMessageModalContentLayoutType contentLayout;

/**
 * The modal message's background color. Defaults to white.
 */
@property(nonatomic, strong, nullable) UIColor *backgroundColor;

/**
 * The modal message's dismiss button color. Defaults to black.
 */
@property(nonatomic, strong, nullable) UIColor *dismissButtonColor;

/**
 * The modal message's border radius. Defaults to 0.
 */
@property(nonatomic, assign) NSUInteger borderRadius;

/**
 * Flag indicating the modal should display as full screen on compact devices.
 * Defaults to NO.
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
 */
@interface UAInAppMessageModalDisplayContent : UAInAppMessageDisplayContent

/**
 * The modal message's heading.
 */
@property(nonatomic, strong, nullable, readonly) UAInAppMessageTextInfo *heading;

/**
 * The modal message's body.
 */
@property(nonatomic, strong, nullable, readonly) UAInAppMessageTextInfo *body;

/**
 * The modal message's media.
 */
@property(nonatomic, strong, nullable, readonly) UAInAppMessageMediaInfo *media;

/**
 * The modal message's footer.
 */
@property(nonatomic, strong, nullable, readonly) UAInAppMessageButtonInfo *footer;

/**
 * The modal message's buttons.
 */
@property(nonatomic, copy, nullable, readonly) NSArray<UAInAppMessageButtonInfo *> *buttons;

/**
 * The modal message's button layout. Defaults to UAInAppMessageButtonLayoutSeparate.
 */
@property(nonatomic, assign, readonly) UAInAppMessageButtonLayoutType buttonLayout;

/**
 * The modal message's layout for the text and media. Defaults to
 * UAInAppMessageModalContentLayoutHeaderMediaBody
 */
@property(nonatomic, assign, readonly) UAInAppMessageModalContentLayoutType contentLayout;

/**
 * The modal message's background color. Defaults to white.
 */
@property(nonatomic, strong, readonly) UIColor *backgroundColor;

/**
 * The modal message's dismiss button color. Defaults to black.
 */
@property(nonatomic, strong, readonly) UIColor *dismissButtonColor;

/**
 * The modal message's border radius. Defaults to 0.
 */
@property(nonatomic, assign, readonly) NSUInteger borderRadius;

/**
 * Flag indicating the modal should display as full screen on compact devices.
 * Defaults to NO.
 */
@property(nonatomic, assign, readonly) BOOL allowFullScreenDisplay;

/**
 * Factory method for building modal message display content with builder block.
 *
 * @param builderBlock The builder block.
 *
 * @returns the display content if the builder block successfully built it, otherwise nil.
 */
+ (nullable instancetype)displayContentWithBuilderBlock:(void(^)(UAInAppMessageModalDisplayContentBuilder *builder))builderBlock;

@end

NS_ASSUME_NONNULL_END

