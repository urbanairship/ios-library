/* Copyright Airship and Contributors */

#import "UAInboxMessageList.h"
#import "UAInboxAPIClient+Internal.h"
#import "UAInboxStore+Internal.h"

#import "UAAirshipMessageCenterCoreImport.h"

@class UADispatcher;
@class UATaskManager;

NS_ASSUME_NONNULL_BEGIN

/*
 * SDK-private extensions to UAInboxMessageList
 */
@interface UAInboxMessageList ()

///---------------------------------------------------------------------------------------
/// @name Message List Internal Properties
///---------------------------------------------------------------------------------------

/**
 * The Inbox API client instance.
 */
@property (nonatomic, strong) UAInboxAPIClient *client;

/**
 * The User instance.
 */
@property (nonatomic, strong) UAUser *user;

/**
 * The inbox store.
 */
@property (nonatomic, strong) UAInboxStore *inboxStore;

/**
 * An array of messages in the inbox.
 */
@property (nonatomic, copy) NSArray<UAInboxMessage *> *messages;

/**
 * A dictionary of messages mapped to their IDs
 */
@property (nonatomic, copy) NSDictionary *messageIDMap;

/**
 * A dictionary of messages mapped to their URLs
 */
@property (nonatomic, copy) NSDictionary *messageURLMap;

/**
 * Flag indicating whether the mesage list is enabled. Clear to disable. Set to enable.
 */
@property (atomic, assign) BOOL enabled;

///---------------------------------------------------------------------------------------
/// @name Message List Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Loads the inbox with the current saved messages.
 */
- (void)loadSavedMessages;

/**
 * Factory method for creating an Inbox Message List
 *
 * @param user The user.
 * @param config The config.
 * @param dataStore The data store.
 * @return An allocated UAInboxMessageList instance.
 */
+ (instancetype)messageListWithUser:(UAUser *)user
                             config:(UARuntimeConfig *)config
                          dataStore:(UAPreferenceDataStore *)dataStore;

/**
 * Factory method for creating an Inbox Message List. Used for testing.
 *
 * @param user The user.
 * @param client The internal inbox API client.
 * @param config The config.
 * @param inboxStore The inbox message store.
 * @param notificationCenter The notification center.
 * @param dispatcher The dispatcher.
 * @param date The UADate instance.
 * @param taskManager The shared task manager.
 * @return An allocated UAInboxMessageList instance.
 */
+ (instancetype)messageListWithUser:(UAUser *)user
                             client:(UAInboxAPIClient *)client
                             config:(UARuntimeConfig *)config
                         inboxStore:(UAInboxStore *)inboxStore
                 notificationCenter:(NSNotificationCenter *)notificationCenter
                         dispatcher:(UADispatcher *)dispatcher
                               date:(UADate *)date
                        taskManager:(UATaskManager *)taskManager;


@end

NS_ASSUME_NONNULL_END
