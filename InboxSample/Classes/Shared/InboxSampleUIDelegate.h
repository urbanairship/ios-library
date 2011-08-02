
#import "UAInboxUI.h"

@interface InboxSampleUIDelegate : NSObject <UAInboxUIDelegateProtocol>

- (void)displayInbox;
- (void)displayMessage:(NSString *)messageID;

@end
