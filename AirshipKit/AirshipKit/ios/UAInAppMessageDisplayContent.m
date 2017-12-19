/* Copyright 2017 Urban Airship and Contributors */

#import "UAInAppMessageDisplayContent.h"

@implementation UAInAppMessageDisplayContent

/**
 * Button Layout
 */
NSString *const UAInAppMessageButtonLayoutStacked = @"stacked";
NSString *const UAInAppMessageButtonLayoutSeparate = @"separate";
NSString *const UAInAppMessageButtonLayoutJoined = @"joined";

/**
 * JSON Keys
 */
NSString *const UAInAppMessageBodyKey = @"body";
NSString *const UAInAppMessageHeadingKey = @"heading";
NSString *const UAInAppMessageBackgroundColorKey = @"background_color";
NSString *const UAInAppMessagePlacementKey = @"placement";
NSString *const UAInAppMessageContentLayoutKey = @"template";
NSString *const UAInAppMessageBorderRadiusKey = @"border_radius";
NSString *const UAInAppMessageButtonLayoutKey = @"button_layout";
NSString *const UAInAppMessageButtonsKey = @"buttons";
NSString *const UAInAppMessageMediaKey = @"media";
NSString *const UAInAppMessageFooterKey = @"footer";
NSString *const UAInAppMessageDismissButtonColorKey = @"dismiss_button_color";
NSString *const UAInAppMessageDurationKey = @"duration";

/*
 * Sub-classes must override this method
 */
- (NSDictionary *)toJsonValue {
    return nil;
}

@end

