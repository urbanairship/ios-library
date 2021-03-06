/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAEventData+Internal.h"

@class UAEvent;
@class UARuntimeConfig;

/**
 * Storage access for analytic events.
 */
@interface UAEventStore : NSObject

///---------------------------------------------------------------------------------------
/// @name Event Store Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Default factory method.
 *
 * @param config The airship config.
 * @return UAEventStore instance.
 */
+ (instancetype)eventStoreWithConfig:(UARuntimeConfig *)config;

/**
 * Saves an event.
 *
 * @param event The event to store.
 * @param sessionID The event's session ID.
 */
- (void)saveEvent:(UAEvent *)event sessionID:(NSString *)sessionID;

/**
 * Fetches a batch of events.
 *
 * @param limit The max number of events to fetch.
 * @param completionHandler A completion handler with the event data.
 */
- (void)fetchEventsWithLimit:(NSUInteger)limit
           completionHandler:(void (^)(NSArray<UAEventData *> *))completionHandler;

/**
 * Deletes a set of events.
 *
 * @param eventIds The event IDs to delete.
 */
- (void)deleteEventsWithIDs:(NSArray<NSString *> *)eventIds;

/**
 * Deletes event session until the underlying store is below a given size.
 * @param bytes The desired size in bytes for the store size.
 */
- (void)trimEventsToStoreSize:(NSUInteger)bytes;

/**
 * Deletes all events in the event store.
 */
- (void)deleteAllEvents;

@end
