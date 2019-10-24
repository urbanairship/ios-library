/* Copyright Airship and Contributors */

@import Foundation;
@import AirshipKit;

@interface MessageCenterDelegate : NSObject <UAMessageCenterDisplayDelegate>

- (instancetype)initWithRootViewController:(UIViewController *)rootViewController;

@end
