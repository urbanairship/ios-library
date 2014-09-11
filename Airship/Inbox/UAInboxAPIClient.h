
#import <Foundation/Foundation.h>
#import "UAHTTPConnection.h"
#import "UAInboxMessageList.h"

typedef void (^UAInboxClientFailureBlock)(UAHTTPRequest *request);
typedef void (^UAInboxClientSuccessBlock)(void);
typedef void (^UAInboxClientMessageRetrievalSuccessBlock)(NSInteger status, NSArray *messages, NSInteger unread);


/**
* A high level abstraction for performing Rich Push API requests.
*/
@interface UAInboxAPIClient : NSObject

/**
 * Retrieves the full message list from the server.
 *
 * @param successBlock A block to be executed when the call completes successfully.
 * @param failureBlock A block to be executed if the call fails.
 */
- (void)retrieveMessageListOnSuccess:(UAInboxClientMessageRetrievalSuccessBlock)successBlock
                           onFailure:(UAInboxClientFailureBlock)failureBlock;

/**
 * Performs a batch delete request on the server.
 *
 * @param messages An NSArray of messages to be deleted.
 * @param successBlock A block to be executed when the call completes successfully.
 * @param failureBlock A block to be executed if the call fails.
 */

- (void)performBatchDeleteForMessages:(NSArray *)messages
                         onSuccess:(UAInboxClientSuccessBlock)successBlock
                        onFailure:(UAInboxClientFailureBlock)failureBlock;

/**
 * Performs a batch mark-as-read request on the server.
 *
 * @param messages An NSArray of messages to be marked as read.
 * @param successBlock A block to be executed when the call completes successfully.
 * @param failureBlock A block to be executed if the call fails.
 */

- (void)performBatchMarkAsReadForMessages:(NSArray *)messages
                        onSuccess:(UAInboxClientSuccessBlock)successBlock
                        onFailure:(UAInboxClientFailureBlock)failureBlock;

/**
 * Cancels all in-flight API requests.
 */
- (void)cancelAllRequests;

@end
