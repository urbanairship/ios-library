
#import <Foundation/Foundation.h>

typedef void (^UAInboxMessageIDBlock)(NSString *messageID);

@interface NSDictionary(RichPushData)

- (void)getRichPushMessageIDWithAction:(UAInboxMessageIDBlock)actionBlock;

@end
