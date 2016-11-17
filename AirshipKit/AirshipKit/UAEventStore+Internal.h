/*
 Copyright 2009-2016 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

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
#import "UAEventData+Internal.h"

@class UAEvent;
@class UAConfig;

/**
 * Storage access for analytic events.
 */
@interface UAEventStore : NSObject


/**
 * Default factory method.
 *
 * @param config The airship config.
 * @return UAEventStore instance.
 */
+ (instancetype)eventStoreWithConfig:(UAConfig *)config;

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
 * @param maxBatchSize The max event batch size.
 * @param completionHandler A completion handler with the event data.
 */
- (void)fetchEventsWithMaxBatchSize:(NSUInteger)maxBatchSize
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
