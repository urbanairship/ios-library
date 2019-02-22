/* Copyright Urban Airship and Contributors */

#import <UIKit/UIKit.h>
#import "UAInAppMessageMediaInfo.h"
#import "UAInAppMessageMediaStyle.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * The in-app message text view that can be populated with an image, video or YouTube clip
 */
@interface UAInAppMessageMediaView : UIView

/**
 * Hide the message window when the video becomes full screen.
 *
 * Set to YES to hide the message window when the video becomes full screen, and make the message
 * window visible again when the full screen video is closed. Handles problem with full screen
 * video appearing behind modal message. Use whenever a message is creating a new UIWindow.
 *
 * Defaults to `NO`.
 */
@property (nonatomic, assign) BOOL hideWindowWhenVideoIsFullScreen;

/**
 * The in-app message media container. This view is used to internally pad the media view.
 */
@property (nonatomic, strong) UIView *mediaContainer;

/**
 * The in-app message media view styling.
 */
@property(nonatomic, strong) UAInAppMessageMediaStyle *style;

/**
 * Factory method for creating an in-app message media view.
 *
 * @param mediaInfo The media info.
 */
+ (instancetype)mediaViewWithMediaInfo:(UAInAppMessageMediaInfo *)mediaInfo;

/**
 * Factory method for creating an in-app message media view with image data.
 *
 * @param mediaInfo The media info.
 * @param imageData The image data.
 */

+ (instancetype)mediaViewWithMediaInfo:(UAInAppMessageMediaInfo *)mediaInfo imageData:(NSData *)imageData;



@end

NS_ASSUME_NONNULL_END
