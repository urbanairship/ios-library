/* Copyright Airship and Contributors */

#import "UAInboxMessageList+Internal.h"

#import "UAInboxAPIClient+Internal.h"
#import "UAInboxMessage+Internal.h"
#import "UAInboxStore+Internal.h"
#import "UAUser.h"

#import "UAAirshipMessageCenterCoreImport.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif
NSString * const UAInboxMessageListWillUpdateNotification = @"com.urbanairship.notification.message_list_will_update";
NSString * const UAInboxMessageListUpdatedNotification = @"com.urbanairship.notification.message_list_updated";

static NSString * const UAInboxMessageListRetrieveTask = @"UAInboxMessageList.retrieve";
static NSString * const UAInboxMessageListSyncReadMessagesTask = @"UAInboxMessageList.sync_read_messages";
static NSString * const UAInboxMessageListSyncDeletedMessagesTask = @"UAInboxMessageList.sync_deleted_messages";

static NSString * const UAInboxMessageListExtraRetrieveCallback = @"retrieveCallback";

@interface UAInboxMessageList()
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@property (nonatomic, strong) UADispatcher *mainDispatcher;
@property (nonatomic, strong) UADispatcher *taskDispatcher;
@property (nonatomic, strong) UADate *date;
@property (nonatomic, strong) UATaskManager *taskManager;

@property (atomic, assign) NSUInteger retrieveCount;
@property (atomic, assign) NSUInteger batchUpdateCount;

@end

@implementation UAInboxMessageList

@synthesize messages = _messages;
@synthesize enabled = _enabled;

#pragma mark Create Inbox

- (instancetype)initWithUser:(UAUser *)user
                      client:(UAInboxAPIClient *)client
                      config:(UARuntimeConfig *)config
                  inboxStore:(UAInboxStore *)inboxStore
          notificationCenter:(NSNotificationCenter *)notificationCenter
                  dispatcher:(UADispatcher *)dispatcher
                        date:(UADate *)date
                 taskManager:(UATaskManager *)taskManager {

    self = [super init];

    if (self) {
        self.inboxStore = inboxStore;
        self.inboxStore.messageList = self;
        self.user = user;
        self.client = client;
        self.retrieveCount = 0;
        self.batchUpdateCount = 0;
        self.unreadCount = -1;
        self.messages = @[];
        self.notificationCenter = notificationCenter;
        self.mainDispatcher = dispatcher;
        self.date = date;
        self.taskManager = taskManager;
        self.taskDispatcher = UADispatcher.serialUtility;
        [self registerTasks];
    }

    return self;
}

+ (instancetype)messageListWithUser:(UAUser *)user
                             config:(UARuntimeConfig *)config
                          dataStore:(UAPreferenceDataStore *)dataStore {

    UAInboxAPIClient *client = [UAInboxAPIClient clientWithConfig:config
                                                          session:[[UARequestSession alloc] initWithConfig:config]
                                                             user:user
                                                        dataStore:dataStore];

    UAInboxStore *inboxStore = [UAInboxStore storeWithName:[NSString stringWithFormat:kUACoreDataStoreName, config.appKey]];

    return [UAInboxMessageList messageListWithUser:user
                                            client:client
                                            config:config
                                        inboxStore:inboxStore
                                notificationCenter:[NSNotificationCenter defaultCenter]
                                        dispatcher:UADispatcher.main
                                              date:[[UADate alloc] init]
                                       taskManager:[UATaskManager shared]];
}

+ (instancetype)messageListWithUser:(UAUser *)user
                             client:(UAInboxAPIClient *)client
                             config:(UARuntimeConfig *)config
                         inboxStore:(UAInboxStore *)inboxStore
                 notificationCenter:(NSNotificationCenter *)notificationCenter
                         dispatcher:(UADispatcher *)dispatcher
                               date:(UADate *)date
                        taskManager:(UATaskManager *)taskManager {

    return [[UAInboxMessageList alloc] initWithUser:user
                                             client:client
                                             config:config
                                         inboxStore:inboxStore
                                 notificationCenter:notificationCenter
                                         dispatcher:dispatcher
                                               date:date
                                        taskManager:taskManager];
}

#pragma mark Accessors

- (void)setMessages:(NSArray *)messages {
    _messages = [messages copy];

    NSMutableDictionary *messageIDMap = [NSMutableDictionary dictionary];
    NSMutableDictionary *messageURLMap = [NSMutableDictionary dictionary];

    for (UAInboxMessage *message in _messages) {
        if (message.messageBodyURL.absoluteString) {
            [messageURLMap setObject:message forKey:message.messageBodyURL.absoluteString];
        }
        if (message.messageID) {
            [messageIDMap setObject:message forKey:message.messageID];
        }
    }

    self.messageIDMap = [messageIDMap copy];
    self.messageURLMap = [messageURLMap copy];
}

- (NSArray *)messages {
    return _messages;
}

- (void)setEnabled:(BOOL)enabled {
    if (_enabled != enabled) {
        _enabled = enabled;
        if (!enabled) {
            [self.client cancelAllRequests];
        }
    }

    if (!_enabled) {
        UA_WEAKIFY(self)
        [self.taskDispatcher dispatchAsync:^{
            UA_STRONGIFY(self)
            if (!self.enabled) {
                [self.inboxStore deleteMessages];
                [self loadSavedMessages];
            }
        }];
    }
}

- (BOOL)enabled {
    return _enabled;
}

- (NSArray<UAInboxMessage *> *)messagesFilteredUsingPredicate:(NSPredicate *)predicate {
    @synchronized(self) {
        return [_messages filteredArrayUsingPredicate:predicate];
    }
}

#pragma mark Tasks

- (void)registerTasks {
    UA_WEAKIFY(self)
    [self.taskManager registerForTaskWithIDs:@[UAInboxMessageListRetrieveTask, UAInboxMessageListSyncReadMessagesTask, UAInboxMessageListSyncDeletedMessagesTask]
                                  dispatcher:self.taskDispatcher
                               launchHandler:^(id<UATask> task) {
        @synchronized (self) {
            if (!self.enabled) {
                UA_LDEBUG(@"Message list disabled, unable to run task %@", task);
                [task taskCompleted];
                return;
            }
        }

        UA_STRONGIFY(self)
        task.expirationHandler = ^{
            UA_STRONGIFY(self)
            [self.client cancelAllRequests];
        };

        if ([task.taskID isEqualToString:UAInboxMessageListRetrieveTask]) {
            [self handleRetrieveTask:task];
        } else if ([task.taskID isEqualToString:UAInboxMessageListSyncReadMessagesTask]) {
            [self handleSyncReadMessagesTask:task];
        } else if ([task.taskID isEqualToString:UAInboxMessageListSyncDeletedMessagesTask]) {
            [self handleSyncDeletedMessagesTask:task];
        } else {
            UA_LERR(@"Invalid task: %@", task.taskID);
            [task taskCompleted];
        }
    }];
}

- (void)handleRetrieveTask:(id<UATask>)task {
    // Fetch
    NSError *error;
    NSArray *messages = [self.client retrieveMessageList:&error];

    void(^callback)(BOOL) = task.requestOptions.extras[UAInboxMessageListExtraRetrieveCallback];

    if (error) {
        UA_LDEBUG(@"Retrieve message list failed");

        // Always refresh the listing even if it's a failure
        [self refreshInbox];

        // Invoke callbacks
        callback(NO);

        [task taskCompleted];
        return;
    }

    // Sync client state
    [self enqueueSyncReadMessagesTask];
    [self enqueueSyncDeletedMessagesTask];

    BOOL success = YES;

    // If the listing has changed, sync the response with the inbox store
    if (messages) {
        success = [self.inboxStore syncMessagesWithResponse:messages];

        // If local sync fails, clear the last modified timestamp
        if (!success) {
            [self.client clearLastModifiedTime];
        }
    }

    // Always refresh the listing even if it's a failure
    [self refreshInbox];

    // Invoke callbacks
    callback(success);

    [task taskCompleted];
}

- (void)handleSyncReadMessagesTask:(id<UATask>)task {
    [self syncReadMessageState];
    [task taskCompleted];
}

- (void)handleSyncDeletedMessagesTask:(id<UATask>)task {
    [self syncDeletedMessageState];
    [task taskCompleted];
}


#pragma mark NSNotificationCenter helper methods

- (void)sendMessageListWillUpdateNotification {
    [self.mainDispatcher doSync:^{
        [self.notificationCenter postNotificationName:UAInboxMessageListWillUpdateNotification object:nil];
    }];
}

- (void)sendMessageListUpdatedNotification {
    [self.mainDispatcher doSync:^{
        [self.notificationCenter postNotificationName:UAInboxMessageListUpdatedNotification object:nil];
    }];
}

#pragma mark Update/Delete/Mark Messages

- (UADisposable *)retrieveMessageListWithSuccessBlock:(UAInboxMessageListCallbackBlock)successBlock
                                     withFailureBlock:(UAInboxMessageListCallbackBlock)failureBlock {
    if (!self.enabled) {
        if (failureBlock) {
            failureBlock();
        }
    }

    __block UAInboxMessageListCallbackBlock successBlockCopy = successBlock;
    __block UAInboxMessageListCallbackBlock failureBlockCopy = failureBlock;

    UA_WEAKIFY(self)
    id extras = @{UAInboxMessageListExtraRetrieveCallback : ^(BOOL success){
        UA_STRONGIFY(self)
        [self.mainDispatcher doSync: ^{
            self.retrieveCount--;

            if (success && successBlockCopy) {
                successBlockCopy();
            } else if (!success && failureBlockCopy) {
                failureBlockCopy();
            }

            [self sendMessageListUpdatedNotification];
        }];
    }};

    [self.mainDispatcher doSync:^{
        UA_STRONGIFY(self)
        self.retrieveCount++;
        [self sendMessageListWillUpdateNotification];
    }];


    UATaskRequestOptions *requestOptions = [[UATaskRequestOptions alloc] initWithConflictPolicy:UATaskConflictPolicyAppend
                                                                                requiresNetwork:NO
                                                                                         extras:extras];

    [self.taskManager enqueueRequestWithID:UAInboxMessageListRetrieveTask options:requestOptions];

    UADisposable *disposable = [[UADisposable alloc] init:^{
        UA_STRONGIFY(self)
        [self.mainDispatcher doSync:^{
            successBlockCopy = nil;
            failureBlockCopy = nil;
        }];
    }];

    return disposable;
}


- (UADisposable *)markMessagesRead:(NSArray *)messages completionHandler:(UAInboxMessageListCallbackBlock)completionHandler {
    __block UAInboxMessageListCallbackBlock inboxMessageListCompletionBlock = completionHandler;
    UADisposable *disposable = [[UADisposable alloc] init:^{
        inboxMessageListCompletionBlock = nil;
    }];


    if (!self.enabled || !messages.count) {
        // Invoke callback
        [self.mainDispatcher dispatchAsync:^{
            UAInboxMessageListCallbackBlock block = inboxMessageListCompletionBlock;
            if (block) {
                block();
            }
        }];
        return disposable;
    }

    NSArray *messageIDs = [messages valueForKeyPath:@"messageID"];

    UA_WEAKIFY(self)
    [self.mainDispatcher doSync:^{
        for (NSString *messageID in messageIDs) {
            UAInboxMessage *message = [self messageForID:messageID];
            message.unread = NO;
        }

        self.batchUpdateCount++;

        [self sendMessageListWillUpdateNotification];
    }];

    [self.inboxStore markMessagesLocallyReadWithIDs:messageIDs completionHandler:^{
        [self refreshInbox];

        // Invoke callback
        [self.mainDispatcher doSync:^{
            UA_STRONGIFY(self)
            if (self.batchUpdateCount >= 0) {
                self.batchUpdateCount--;
            }

            UAInboxMessageListCallbackBlock block = inboxMessageListCompletionBlock;
            if (block) {
                block();
            }

            [self sendMessageListUpdatedNotification];
        }];

        [self enqueueSyncReadMessagesTask];
    }];

    return disposable;
}

- (UADisposable *)markMessagesDeleted:(NSArray *)messages completionHandler:(UAInboxMessageListCallbackBlock)completionHandler {
    __block UAInboxMessageListCallbackBlock inboxMessageListCompletionBlock = completionHandler;
    UADisposable *disposable = [[UADisposable alloc] init:^{
        inboxMessageListCompletionBlock = nil;
    }];


    if (!self.enabled || !messages.count) {
        // Invoke callback
        [self.mainDispatcher dispatchAsync:^{
            UAInboxMessageListCallbackBlock block = inboxMessageListCompletionBlock;
            if (block) {
                block();
            }
        }];
        return disposable;
    }

    NSArray *messageIDs = [messages valueForKeyPath:@"messageID"];

    UA_WEAKIFY(self)
    [self.mainDispatcher doSync:^{
        for (NSString *messageID in messageIDs) {
            UAInboxMessage *message = [self messageForID:messageID];
            message.unread = NO;
        }

        self.batchUpdateCount++;

        [self sendMessageListWillUpdateNotification];
    }];

    [self.inboxStore markMessagesLocallyDeletedWithIDs:messageIDs completionHandler:^{
        [self refreshInbox];

        // Invoke callback
        [self.mainDispatcher doSync:^{
            UA_STRONGIFY(self)
            if (self.batchUpdateCount >= 0) {
                self.batchUpdateCount--;
            }

            UAInboxMessageListCallbackBlock block = inboxMessageListCompletionBlock;
            if (block) {
                block();
            }

            [self sendMessageListUpdatedNotification];
        }];

        [self enqueueSyncDeletedMessagesTask];
    }];

    return disposable;
}

- (void)loadSavedMessages {
    // First load
    [self sendMessageListWillUpdateNotification];

    UA_WEAKIFY(self)
    [self refreshInbox:^{
        UA_STRONGIFY(self)
        [self sendMessageListUpdatedNotification];
    }];
}

#pragma mark -
#pragma mark Internal/Helper Methods

/**
 * Refreshes the publicly exposed inbox messages.
 */
- (void)refreshInbox:(void (^)(void))completionHandler {
    if (self.enabled) {
        NSString *predicateFormat = @"(messageExpiration == nil || messageExpiration >= %@) && (deletedClient == NO || deletedClient == nil)";
        NSPredicate *predicate = [NSPredicate predicateWithFormat:predicateFormat, [self.date now]];

        [self.inboxStore fetchMessagesWithPredicate:predicate completionHandler:^(NSArray<UAInboxMessage *> *messages) {
            [self updateMessages:messages];
            completionHandler();
        }];
    } else {
        [self updateMessages:@[]];
        completionHandler();
    }
}

- (void)refreshInbox {
    if (self.enabled) {
        NSString *predicateFormat = @"(messageExpiration == nil || messageExpiration >= %@) && (deletedClient == NO || deletedClient == nil)";
        NSPredicate *predicate = [NSPredicate predicateWithFormat:predicateFormat, [self.date now]];
        NSArray<UAInboxMessage *> *messages = [self.inboxStore fetchMessagesWithPredicate:predicate];
        [self updateMessages:messages];
    } else {
        [self updateMessages:@[]];
    }
}

- (void)updateMessages:(NSArray<UAInboxMessage *> *)messages {
    NSInteger unreadCount = 0;

    for (UAInboxMessage *message in messages) {
        if (message.unread) {
            unreadCount ++;
        }
    }

    [self.mainDispatcher doSync:^{
        UA_LDEBUG(@"Inbox messages updated.");
        UA_LTRACE(@"Loaded saved messages: %@.", messages);
        self.unreadCount = unreadCount;
        self.messages = messages;
    }];
}

- (void)enqueueSyncReadMessagesTask {
    UATaskRequestOptions *requestOptions = [[UATaskRequestOptions alloc] initWithConflictPolicy:UATaskConflictPolicyKeep
                                                                                requiresNetwork:NO
                                                                                         extras:nil];

    [self.taskManager enqueueRequestWithID:UAInboxMessageListSyncReadMessagesTask options:requestOptions];
}

- (void)enqueueSyncDeletedMessagesTask {
    UATaskRequestOptions *requestOptions = [[UATaskRequestOptions alloc] initWithConflictPolicy:UATaskConflictPolicyKeep
                                                                                requiresNetwork:NO
                                                                                         extras:nil];

    [self.taskManager enqueueRequestWithID:UAInboxMessageListSyncDeletedMessagesTask options:requestOptions];
}

/**
 * Synchronizes localy read message state with the server.
 */
- (void)syncReadMessageState {
    NSDictionary<NSString *, NSDictionary *> *locallyReadMessages = [self.inboxStore locallyReadMessageReporting];
    NSArray<NSString *> *messageIDs = locallyReadMessages.allKeys;
    NSArray<NSDictionary *> *messageReporting = locallyReadMessages.allValues;

    UA_LTRACE(@"Synchronizing locally read messages %@ on server.", messageIDs);
    BOOL success = [self.client performBatchMarkAsReadForMessageReporting:messageReporting];

    if (success) {
        [self.inboxStore markMessagesGloballyReadWithIDs:messageIDs];
        UA_LTRACE(@"Successfully synchronized locally read messages on server.");
    } else {
        UA_LTRACE(@"Failed to synchronize locally read messages on server.");
    }
}

/**
 * Synchronizes locally deleted message state with the server.
 */
- (void)syncDeletedMessageState {
    NSDictionary<NSString *, NSDictionary *> *locallyDeletedMessages = [self.inboxStore locallyDeletedMessageReporting];
    NSArray<NSString *> *messageIDs = locallyDeletedMessages.allKeys;
    NSArray<NSDictionary *> *messageReporting = locallyDeletedMessages.allValues;

    UA_LTRACE(@"Synchronizing locally deleted messages %@ on server.", messageIDs);
    BOOL success = [self.client performBatchDeleteForMessageReporting:messageReporting];

    if (success) {
        [self.inboxStore deleteMessagesWithIDs:messageIDs];
        UA_LTRACE(@"Successfully synchronized locally deleted messages on server.");
    } else {
        UA_LTRACE(@"Failed to synchronize locally deleted messages on server.");
    }
}

- (BOOL)isBatchUpdating {
    return self.batchUpdateCount > 0;
}

- (NSUInteger)messageCount {
    return [self.messages count];
}

- (UAInboxMessage *)messageForBodyURL:(NSURL *)url {
    return [self.messageURLMap objectForKey:url.absoluteString];
}

- (UAInboxMessage *)messageForID:(NSString *)messageID {
    return [self.messageIDMap objectForKey:messageID];
}

- (id)debugQuickLookObject {
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:@""];

    NSUInteger index = 0;
    NSUInteger characterIndex = 0;
    for (UAInboxMessage *message in self.messages) {
        NSString *line = index < self.messages.count-1 ? [NSString stringWithFormat:@"%@\n", message.title] : message.title;
        [attributedString.mutableString appendString:line];
        // Display unread messages in bold text
        NSString *fontName = message.unread ? @"Helvetica Bold" : @"Helvetica";
        [attributedString addAttribute:NSFontAttributeName value:[UIFont fontWithName:fontName size:15]
                                 range:NSMakeRange(characterIndex, line.length)];
        index++;
        characterIndex += line.length;
    }

    return attributedString;
}

@end


