/* Copyright Airship and Contributors */

@import UIKit;
@import AirshipMessageCenter;

@interface MessageCenterViewController : UAMessageCenterSplitViewController

- (void)showInbox;
- (void)displayMessageForID:(NSString *)messageID;

@end
