/* Copyright Airship and Contributors */

@import Foundation;
@import Airship;

@interface MessageCenterDelegate : NSObject <UAMessageCenterDisplayDelegate>

- (instancetype)initWithRootViewController:(UIViewController *)rootViewController;

@end
