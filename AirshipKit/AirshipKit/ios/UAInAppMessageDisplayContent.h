/* Copyright 2017 Urban Airship and Contributors */

#import <Foundation/Foundation.h>

/**
 * Display content for a in-app message.
 */
@interface UAInAppMessageDisplayContent : NSObject

/**
 * Buttons are displayed with a space between them.
 */
extern NSString *const UAInAppMessageButtonLayoutStacked;

/**
 * Buttons are displayed right next to each other.
 */
extern NSString *const UAInAppMessageButtonLayoutSeparate;

/**
 * Buttons are stacked.
 */
extern NSString *const UAInAppMessageButtonLayoutJoined;

/**
 * JSON keys.
 */
extern NSString *const UAInAppMessageBodyKey;
extern NSString *const UAInAppMessageHeadingKey;
extern NSString *const UAInAppMessageBackgroundColorKey;
extern NSString *const UAInAppMessagePlacementKey;
extern NSString *const UAInAppMessageContentLayoutKey;
extern NSString *const UAInAppMessageBorderRadiusKey;
extern NSString *const UAInAppMessageButtonLayoutKey;
extern NSString *const UAInAppMessageButtonsKey;
extern NSString *const UAInAppMessageMediaKey;
extern NSString *const UAInAppMessageURLKey;
extern NSString *const UAInAppMessageDismissButtonColorKey;
extern NSString *const UAInAppMessageFooterKey;
extern NSString *const UAInAppMessageDurationKey;


@end

