/* Copyright Airship and Contributors */

@import UIKit;
@import AirshipMessageCenter;

@interface MessageCenterViewController : UADefaultMessageCenterSplitViewController

- (void)showInbox;
- (void)displayMessageForID:(NSString *)messageID;

@end
