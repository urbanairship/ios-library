
#import "UAInboxMessageList.h"
#import "UAInboxAPIClient.h"

@interface UAInboxMessageList ()

@property (nonatomic, strong) UAInboxAPIClient *client;
@property (atomic, assign) NSUInteger batchOperationCount;
@property (atomic, assign) NSUInteger retrieveOperationCount;
@property (nonatomic, strong) NSOperationQueue *queue;

/**
 * Marks messages read. They will be marked locally as read and synced with
 * the Urban Airship on the next message retrieval.
 *
 * @param messages The array of messages to be marked read.
 * @param completionHandler An optional completion handler.
 * @return A UADisposable token which can be used to cancel callback execution.
 */
- (UADisposable *)markMessagesRead:(NSArray *)messages completionHandler:(void (^)())completionHandler;

/**
 * Marks messages read. They will be marked locally as read and synced with
 * the Urban Airship on the next message retrieval.
 *
 * @param messages The array of messages to be marked read.
 * @param delegate An object implementing the `UAInboxMessageListDelegate` protocol.
 * @return A UADisposable token which can be used to cancel callback execution.
 */
- (UADisposable *)markMessagesRead:(NSArray *)messages delegate:(id<UAInboxMessageListDelegate>)delegate;

/**
 * Marks messages deleted. They will be marked locally as deleted and synced with
 * the Urban Airship on the next message retrieval.
 *
 * @param messages The array of messages to be marked deleted.
 * @param completionHandler An optional completion handler.
 * @return A UADisposable token which can be used to cancel callback execution.
 */
- (UADisposable *)markMessagesDeleted:(NSArray *)messages completionHandler:(void (^)())completionHandler;

/**
 * Marks messages deleted. They will be marked locally as deleted and synced with
 * the Urban Airship on the next message retrieval.
 *
 * @param messages The array of messages to be marked deleted.
 * @param delegate An object implementing the `UAInboxMessageListDelegate` protocol.
 * @return A UADisposable token which can be used to cancel callback execution.
 */
- (UADisposable *)markMessagesDeleted:(NSArray *)messages delegate:(id<UAInboxMessageListDelegate>)delegate;


/**
 * Loads the inbox with the current saved messages.
 */
- (void)loadSavedMessages;

@end
