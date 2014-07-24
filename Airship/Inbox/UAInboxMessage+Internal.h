
#import "UAInboxMessage.h"
#import "UAInboxAPIClient.h"
#import "UAInboxMessageData.h"

@interface UAInboxMessage ()

@property(nonatomic, strong) UAInboxAPIClient *client;
@property(nonatomic, strong) UAInboxMessageData *data;

@property (nonatomic, copy) NSString *messageID;
@property (nonatomic, strong) NSURL *messageBodyURL;
@property (nonatomic, strong) NSURL *messageURL;
@property (nonatomic, copy) NSString *contentType;
@property (nonatomic, assign) BOOL unread;
@property (nonatomic, strong) NSDate *messageSent;
@property (nonatomic, strong) NSDate *messageExpiration;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, strong) NSDictionary *extra;
@property (nonatomic, strong) NSDictionary *rawMessageObject;
@property (weak) UAInboxMessageList *inbox;

+ (instancetype)messageWithData:(UAInboxMessageData *)data;

@end
