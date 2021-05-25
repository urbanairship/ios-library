/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInboxMessageData+Internal.h"
#import "UAInboxMessage+Internal.h"

#import "UAAirshipMessageCenterCoreImport.h"

#define kUACoreDataStoreName @"Inbox-%@.sqlite"
#define kUACoreDataDirectory @"UAInbox"
#define kUAInboxDBEntityName @"UAInboxMessage"

@class UARuntimeConfig;
@class UAInboxMessageList;

NS_ASSUME_NONNULL_BEGIN

/**
 * Manager class for the Rich Push CoreData store. Use this class
 * to add, delete, fetch and update messages in the database.
 */
@interface UAInboxStore : NSObject

@property(nonatomic, weak) UAInboxMessageList *messageList;


///---------------------------------------------------------------------------------------
/// @name Inbox Database Manager Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Factory method for automation store.
 *
 * @param storeName The store name.
 * @param inMemory Whether to use an in-memory database. If `NO` the store will default to SQLite.

 * @return Automation store.
 */
+ (instancetype)storeWithName:(NSString *)storeName inMemory:(BOOL)inMemory;

/**
 * Factory method for automation store.
 *
 * @param storeName The store name.
 * @return Automation store.
 */
+ (instancetype)storeWithName:(NSString *)storeName;

/**
 * Fetches messages matching the provided predicate.
 *
 * @param predicate The predicate.
 * @return The matching messages.
 */
- (NSArray<UAInboxMessage *> *)fetchMessagesWithPredicate:(nullable NSPredicate *)predicate;

/**
 * Fetches messages matching the provided predicate.
 *
 * @param predicate The predicate.
 * @param completionHandler The completion handler with matching messages.
 */
- (void)fetchMessagesWithPredicate:(nullable NSPredicate *)predicate completionHandler:(void (^)(NSArray<UAInboxMessage *> *))completionHandler;

/**
 * Marks messages locally read by ID.
 *
 * @param messageIDs The message IDs.
 * @param completionHandler The completion handler.
 */
- (void)markMessagesLocallyReadWithIDs:(NSArray<NSString *> *)messageIDs completionHandler:(void (^)(void))completionHandler;

/**
 * Marks messages locally deleted by ID.
 *
 * @param messageIDs The message IDs.
 * @param completionHandler The completion handler.
 */
- (void)markMessagesLocallyDeletedWithIDs:(NSArray<NSString *> *)messageIDs completionHandler:(void (^)(void))completionHandler;

/**
 * Marks messages globally read by ID.
 *
 * @param messageIDs The message IDs.
 */
- (void)markMessagesGloballyReadWithIDs:(NSArray<NSString *> *)messageIDs;

/**
 * Deletes a list of message IDs.
 *
 * @param messageIDs The list of message IDs to delete.
 */
- (void)deleteMessagesWithIDs:(NSArray<NSString *> *)messageIDs;

/**
 * Updates the inbox store with the array of messages.
 *
 * @param messages An array of messages.
 * @return The success status.
 */
- (BOOL)syncMessagesWithResponse:(NSArray *)messages;

/**
 * Deletes all messages.
 */
- (void)deleteMessages;

/**
 * Fetches locally read message reporting data.
 * @return A dictionary of message IDs to message reporting dictionaries
 */
- (NSDictionary<NSString *, NSDictionary *> *)locallyReadMessageReporting;

/**
 * Fetches locally deleted message reporting data.
 * @return A dictionary of message IDs to message reporting dictionaries
 */
- (NSDictionary<NSString *, NSDictionary *> *)locallyDeletedMessageReporting;

/**
 * Shuts down the store and prevents any subsequent interaction with the managed context. Used by Unit Tests.
 */
- (void)shutDown;

@end

NS_ASSUME_NONNULL_END
