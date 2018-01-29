/* Copyright 2018 Urban Airship and Contributors */

@import UIKit;
@import AirshipKit;

@interface MessageCenterViewController : UAMessageCenterSplitViewController

- (void)displayMessageForID:(NSString *)messageID;

@end
