/*
Copyright 2009-2014 Urban Airship Inc. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
list of conditions and the following disclaimer.

2. Redistributions in binaryform must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation
and/or other materials provided withthe distribution.

THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#import <Foundation/Foundation.h>

#import "UAInboxMessageListDelegate.h"
#import "UAUser.h"
#import "UADisposable.h"


/**
 * A completion block for message list operations.
 */
typedef void (^UAInboxMessageListCallbackBlock)(void);

/**
 * NSNotification posted when the message list is about to update.
 *
 * Note: this notification is posted regardless of the type of update (retrieval, batch).
 */
extern NSString * const UAInboxMessageListWillUpdateNotification;

/**
 * NSNotification posted when the message list is finished updating.
 *
 * Note: this notification is posted regardless of the type of update (retrieval, batch)
 * and regardless of the success/failure of the underlying operation.
 */
extern NSString * const UAInboxMessageListUpdatedNotification;

@class UAInboxMessage;

/**
 * An enum expressing the two possible batch update commands,
 * delete and mark-as-read.
 *
 * @deprecated As of 5.0.
 */
typedef NS_ENUM(NSInteger, UABatchUpdateCommand) {
    /**
     * Update the message list by marking messages as read.
     */
    UABatchReadMessages,

    /**
     * Update the message list by deleting messages.
     */
    UABatchDeleteMessages
};


/**
 * The primary interface to the contents of the inbox.
 * Use this class to asychronously retrieve messges from the server,
 * delete or mark messages as read, retrieve individual messages from the
 * list.
 */
@interface UAInboxMessageList : NSObject


/**
 * Marks messages read. They will be marked locally as read and synced with
 * Urban Airship on the next message retrieval.
 *
 * @param messages The array of messages to be marked read.
 * @param completionHandler An optional completion handler.
 * @return A UADisposable token which can be used to cancel callback execution.
 */
- (UADisposable *)markMessagesRead:(NSArray *)messages completionHandler:(UAInboxMessageListCallbackBlock)completionHandler;

/**
 * Marks messages deleted. They will be marked locally as deleted and synced with
 * Urban Airship on the next message retrieval.
 *
 * @param messages The array of messages to be marked deleted.
 * @param completionHandler An optional completion handler.
 * @return A UADisposable token which can be used to cancel callback execution.
 */
- (UADisposable *)markMessagesDeleted:(NSArray *)messages completionHandler:(UAInboxMessageListCallbackBlock)completionHandler;

/**
 * Fetch new messages from the server. If the associated user has not yet
 * been created, this will be a no-op.
 *
 * @param successBlock A block to be executed if message retrieval succeeds.
 * @param failureBlock A block to be executed if message retrieval fails.
 * @return A UADisposable token which can be used to cancel callback execution.
 * This value will be nil if the associated user has not yet been created.
 */
- (UADisposable *)retrieveMessageListWithSuccessBlock:(UAInboxMessageListCallbackBlock)successBlock
                                     withFailureBlock:(UAInboxMessageListCallbackBlock)failureBlock;

/**
 * Fetch new messages from the server.  This will result in a
 * callback to the passed delegate at [UAInboxMessageListDelegate messageListLoadSucceeded] upon
 * successful completion, and [UAInboxMessageListDelegate messageListLoadFailed] on failure. If
 * The associated user has not yet been created, this will be a no-op.
 *
 * @param delegate An object implementing the `UAInboxMessageListDelegate` protocol.
 * @return A UADisposable token which can be used to cancel callback execution.
 * This value will be nil if the associated user has not yet been created.
 *
 * @deprecated As of 5.0.0. Use retrieveMessageListWithSuccessBlock:withFailureBlock: instead.
 * */
- (UADisposable *)retrieveMessageListWithDelegate:(id<UAInboxMessageListDelegate>)delegate __attribute__((deprecated("As of version 5.0.0")));


/**
 * Update the message list by marking messages as read, or deleting them.
 *
 *
 * @param command the UABatchUpdateCommand to perform.
 * @param messageIndexSet an NSIndexSet of message IDs representing the subset of the inbox to update.
 * @param successBlock A block to be executed if the batch update succeeds.
 * @param failureBlock A block to be executed if the batch update fails.
 * @return A UADisposable token which can be used to cancel callback execution.
 * If the passed batch update command cannot be interpreted, this value will be nil.
 *
 * @deprecated As of 5.0.0. Use markMessagesRead:completionHandler: or markMessagesDeleted:completionHandler:
 * instead. Marking messages read or deleted no longer requires an HTTP operation
 * to succeed, so the failure block will no longer be called.
 */
- (UADisposable *)performBatchUpdateCommand:(UABatchUpdateCommand)command
                        withMessageIndexSet:(NSIndexSet *)messageIndexSet
                           withSuccessBlock:(UAInboxMessageListCallbackBlock)successBlock
                           withFailureBlock:(UAInboxMessageListCallbackBlock)failureBlock __attribute__((deprecated("As of version 5.0.0")));

/**
 * Update the message list by marking messages as read, or deleting them.
 * This eventually will result in an asyncrhonous delegate callback to
 * [UAInboxMessageListDelegate batchMarkAsReadFinished],
 * [UAInboxMessageListDelegate batchMarkAsReadFailed],
 * [UAInboxMessageListDelegate batchDeleteFinished], or
 * [UAInboxMessageListDelegate batchDeleteFailed].
 *
 * @param command the UABatchUpdateCommand to perform.
 * @param messageIndexSet an NSIndexSet of message IDs representing the subset of the inbox to update.
 * @param delegate An object implementing the `UAInboxMessageListDelegate` protocol.
 * @return A UADisposable token which can be used to cancel callback execution.
 * If the passed batch update command cannot be interpreted, this value will be nil.
 *
 * @deprecated As of 5.0.0. Use markMessagesRead:completionHandler: or markMessagesDeleted:completionHandler:
 * instead.
 */
- (UADisposable *)performBatchUpdateCommand:(UABatchUpdateCommand)command
                        withMessageIndexSet:(NSIndexSet *)messageIndexSet
                               withDelegate:(id<UAInboxMessageListDelegate>)delegate __attribute__((deprecated("As of version 5.0.0")));


/**
 * Returns the number of messages currently in the inbox.
 * @return The message count as an integer.
 */
- (NSUInteger)messageCount;

/**
 * Returns the message associated with a particular ID.
 * @param messageID The message ID as an NSString.
 * @return The associated UAInboxMessage object.
 */
- (UAInboxMessage *)messageForID:(NSString *)messageID;

/**
 * Returns the message associated with a particular message list index.
 * @param index The message list index as an integer.
 * @return The associated UAInboxMessage object.
 *
 * @deprecated As of 5.0.0. Inbox implementations should store a local copy of the messages array
 * and perform its own message at index operations.
 */
- (UAInboxMessage*)messageAtIndex:(NSUInteger)index __attribute__((deprecated("As of version 5.0.0")));

/**
 * Returns the index of a particular message within the message list.
 * @param message The UAInboxMessage object of interest.
 * @return The index of the message as an integer.
 *
 * @deprecated As of 5.0.0. Inbox implementations should store a local copy of the messages array
 * and perform its own index of message operations.
 */
- (NSUInteger)indexOfMessage:(UAInboxMessage *)message __attribute__((deprecated("As of version 5.0.0")));


/**
 * The list of messages on disk as an NSArray.
 */
@property (atomic, readonly, strong) NSArray *messages;

/**
 * The number of messages that are currently unread or -1
 * if the message list is not loaded.
 */
@property (assign) NSInteger unreadCount;

/**
 * YES if retrieving message list is currently in progress.
 * NO otherwise.
 */
@property (readonly) BOOL isRetrieving;

/**
 * YES if message batching is currently in progress.
 * NO otherwise.
 */
@property (readonly) BOOL isBatchUpdating;

@end
