/* Copyright Airship and Contributors */

@import Foundation;
@import AirshipMessageCenter;

@interface MessageCenterDelegate : NSObject <UAMessageCenterDisplayDelegate, UAMessageCenterMessagePresentationDelegate>

- (instancetype)initWithRootViewController:(UIViewController *)rootViewController;

@end
