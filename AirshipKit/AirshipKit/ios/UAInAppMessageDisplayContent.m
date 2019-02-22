/* Copyright Urban Airship and Contributors */

#import "UAInAppMessageDisplayContent.h"

@implementation UAInAppMessageDisplayContent

/**
 * Button Layout
 */
NSString *const UAInAppMessageButtonLayoutStackedValue = @"stacked";
NSString *const UAInAppMessageButtonLayoutSeparateValue = @"separate";
NSString *const UAInAppMessageButtonLayoutJoinedValue = @"joined";

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
NSString *const UAInAppMessageModalAllowsFullScreenKey = @"allow_fullscreen_display";
NSString *const UAInAppMessageHTMLAllowsFullScreenKey = @"allow_fullscreen_display";

/*
 * Sub-classes must override this method
 */
- (NSDictionary *)toJSON {
    return nil;
}

@end

