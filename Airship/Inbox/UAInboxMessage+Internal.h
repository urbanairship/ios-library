
#import "UAInboxMessage.h"
#import "UAInboxAPIClient.h"
#import "UAInboxMessageData.h"

@interface UAInboxMessage ()
@property (nonatomic, strong) UAInboxMessageData *data;
@property (nonatomic, weak) UAInboxMessageList *inbox;

+ (instancetype)messageWithData:(UAInboxMessageData *)data;

@end
