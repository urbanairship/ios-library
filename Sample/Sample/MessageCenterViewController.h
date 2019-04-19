/* Copyright Urban Airship and Contributors */

@import UIKit;
@import AirshipKit;

@interface MessageCenterViewController : UAMessageCenterSplitViewController

- (void)showInbox;
- (void)displayMessageForID:(NSString *)messageID;

@end
