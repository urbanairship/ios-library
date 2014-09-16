/*
 Copyright 2009-2014 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
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
#import "UAGlobal.h"

@class UAEvent;
@class UASQLite;


/**
* Primary interface for working with the analytics DB
*/
@interface UAAnalyticsDBManager : NSObject {
    dispatch_queue_t dbQueue;
}

/**
* Analytics DB
*/
@property (nonatomic, strong) UASQLite *db;

SINGLETON_INTERFACE(UAAnalyticsDBManager);

/**
 * Resets the database
 */
- (void)resetDB;

/**
 * Adds analytics event to sqlite DB
 *
 * @param event UAEvent to add
 * @param sessionId Session ID string
 */
- (void)addEvent:(UAEvent *)event withSessionId:(NSString *)sessionId;

/**
 * Gets analytics events via sqlite query
 *
 * @param max Integer representing the sqlite query limit, max < 0 returns all the data
 * @return An array of analytics events from the DB
 */
- (NSArray *)getEvents:(NSUInteger)max;

/**
 * Gets analytics events via sqlite query using event ID
 *
 * @param eventId Analytics event ID string
 * @return An array of analytics events from the DB
 */
- (NSArray *)getEventByEventId:(NSString *)eventId;

/**
 * Deletes individual analytics events from sqlite DB using event ID
 *
 * @param eventId Analytics event ID string
 */
- (void)deleteEvent:(NSNumber *)eventId;

/**
 * Deletes an array of analytics events from sqlite DB
 *
 * @param events Array of analytics events to delete
 */
- (void)deleteEvents:(NSArray *)events;

/**
 * Deletes analytics events from sqlite DB using session ID
 *
 * @param sessionId Session ID string of the events to be deleted
 */
- (void)deleteBySessionId:(NSString *)sessionId;

/**
 * Deletes analytics events from sqlite DB using oldest session ID
 */
- (void)deleteOldestSession;


/**
 * Gets count of analytics events stored in sqlite DB
 *
 * @return Integer count of total stored analytics events
 */
- (NSUInteger)eventCount;

/**
 * Gets the total size in bytes of the sqlite DB
 *
 * @return Integer representing the total size in bytes of sqlite DB
 */
- (NSUInteger)sizeInBytes;

@end
