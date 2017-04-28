/* Copyright 2017 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAGlobal.h"


#define kUACoreDataStoreName @"Inbox-%@.sqlite"
#define kUACoreDataDirectory @"UAInbox"
#define kUAInboxDBEntityName @"UAInboxMessage"

@class UAConfig;
@class UAInboxMessage;
@class UAInboxMessageData;

NS_ASSUME_NONNULL_BEGIN

/**
 * Manager class for the Rich Push CoreData store. Use this class
 * to add, delete, fetch and update messages in the database.
 */
@interface UAInboxDBManager : NSObject

///---------------------------------------------------------------------------------------
/// @name Inbox Database Manager Internal Properties
///---------------------------------------------------------------------------------------

/**
 * The URL for the core data store.
 */
@property (readonly) NSURL *storeURL;

/**
 * Manged object context on the main queue. Any publically visible inbox messages must be fetched
 * from this context, and any user-initiated mutations to the messages must be performed on this context to
 * to avoid concurrency violations. Messages fetched from this context can only be safely read or modified
 * from the main queue.
 */
@property (readonly) NSManagedObjectContext *mainContext;

/**
 * Managed object context on a private queue. Should only be used
 * to perform background operations and prefetching, where messages are loaded on the
 * private context so that they can be cached and quickly read on the main context. Messages
 * fetched from this context can only be safely read or modified from its associated worker queue.
 */
@property (readonly) NSManagedObjectContext *privateContext;

/**
 * The managed object model for inbox messages.
 */
@property (readonly) NSManagedObjectModel *managedObjectModel;

/**
 * The core data persistent store coordinator.
 */
@property (readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;

///---------------------------------------------------------------------------------------
/// @name Inbox Database Manager Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Initializes the inbox db manager with the given config.
 * @param config The Urban Airship config.
 */
- (instancetype)initWithConfig:(UAConfig *)config;

/**
 * Fetches messages with a specified predicate, on a given context.
 *
 * @param predicate An NSPredicate querying a subset of messages.
 * @param context The context on which to perform the fetch.
 * @param completionHandler An optional completion handler called when the fetch is complete.
 */
- (void)fetchMessagesWithPredicate:(NSPredicate *)predicate
                           context:(NSManagedObjectContext *)context
                 completionHandler:(void(^)(NSArray *messages))completionHandler;

/**
 * Updates an existing message in the inbox.
 *
 * @param dictionary A dictionary with keys and values conforming to the
 * Urban Airship JSON API for retrieving inbox messages.
 * @param context The context on which to perform the update.
 *
 * @return YES if the message was updated, NO otherwise.
 */
- (BOOL)updateMessageWithDictionary:(NSDictionary *)dictionary context:(NSManagedObjectContext *)context;

/**
 * Adds a message to the inbox.
 * @param dictionary A dictionary with keys and values conforming to the
 * Urban Airship JSON API for retrieving inbox messages.
 * @param context The context on which to perform the operation.
 * @return A message, populated with data from the message dictionary.
 */
- (UAInboxMessage *)addMessageFromDictionary:(NSDictionary *)dictionary context:(NSManagedObjectContext *)context;

/**
 * Deletes a list of messages from the database.
 * @param messages NSArray of UAInboxMessages to be deleted.
 * @param context The context on which to perform the operation.
 */
- (void)deleteMessages:(NSArray *)messages context:(NSManagedObjectContext *)context;

@end

NS_ASSUME_NONNULL_END
