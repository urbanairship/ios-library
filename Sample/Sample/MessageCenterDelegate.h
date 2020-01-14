/* Copyright Airship and Contributors */

@import Foundation;
@import AirshipMessageCenter;

@interface MessageCenterDelegate : NSObject <UAMessageCenterDisplayDelegate>

- (instancetype)initWithRootViewController:(UIViewController *)rootViewController;

@end
