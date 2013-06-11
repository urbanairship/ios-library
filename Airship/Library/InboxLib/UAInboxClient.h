
#import <Foundation/Foundation.h>
#import "UAHTTPConnection.h"
#import "UAInboxMessageList.h"

typedef void (^UAInboxClientSuccessBlock)(void);
typedef void (^UAInboxClientRetrievalSuccessBlock)(NSMutableArray *messages, NSInteger unread);
typedef void (^UAInboxClientFailureBlock)(UAHTTPRequest *request);

@interface UAInboxClient : NSObject

- (void)markMessageRead:(UAInboxMessage *)message
                     onSuccess:(UAInboxClientSuccessBlock)successBlock
                     onFailure:(UAInboxClientFailureBlock)failureBlock;

- (void)retrieveMessageListOnSuccess:(UAInboxClientRetrievalSuccessBlock)successBlock
                           onFailure:(UAInboxClientFailureBlock)failureBlock;

- (void)performBatchUpdateCommand:(UABatchUpdateCommand)command
                      forMessages:(NSArray *)messages
                         onSuccess:(UAInboxClientSuccessBlock)successBlock
                        onFailure:(UAInboxClientFailureBlock)failureBlock;

@end
