
#import "UAInboxMessage.h"
#import "UAInboxAPIClient.h"
#import "UAInboxMessageData.h"

@interface UAInboxMessage ()

@property(nonatomic, strong) UAInboxMessageData *data;

+ (instancetype)messageWithData:(UAInboxMessageData *)data;

@end
