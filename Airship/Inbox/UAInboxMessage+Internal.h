
#import "UAInboxMessage.h"
#import "UAInboxAPIClient.h"
#import "UAInboxMessageData.h"

@interface UAInboxMessage ()
@property (nonatomic, strong) UAInboxMessageData *data;
@property (nonatomic, weak) UAInboxMessageList *inbox;

+ (instancetype)messageWithData:(UAInboxMessageData *)data;


/**
 * Mark the message as read.
 *
 * @param completionHandler A block to be executed on completion.
 * @return A UADisposable which can be used to cancel callback execution.
 */
- (UADisposable *)markMessageReadWithCompletionHandler:(UAInboxMessageCallbackBlock)completionHandler;

@end
