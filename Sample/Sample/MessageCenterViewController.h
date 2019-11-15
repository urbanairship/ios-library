/* Copyright Airship and Contributors */

@import UIKit;
@import Airship;

@interface MessageCenterViewController : UAMessageCenterSplitViewController

- (void)showInbox;
- (void)displayMessageForID:(NSString *)messageID;

@end
