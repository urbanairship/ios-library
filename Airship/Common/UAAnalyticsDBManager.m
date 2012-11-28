/*
 Copyright 2009-2012 Urban Airship Inc. All rights reserved.

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

#import "UAAnalyticsDBManager.h"

#import "UAirship.h"
#import "UAEvent.h"

#define DB_NAME @"UAAnalyticsDB"
#define CREATE_TABLE_CMD @"CREATE TABLE analytics (_id INTEGER PRIMARY KEY AUTOINCREMENT, type VARCHAR(255), event_id VARCHAR(255), time VARCHAR(255), data BLOB, session_id VARCHAR(255), event_size VARCHAR(255))"

@implementation UAAnalyticsDBManager

SINGLETON_IMPLEMENTATION(UAAnalyticsDBManager)


- (void)createDatabaseIfNeeded {
    dispatch_sync(dbQueue, ^{
        NSString *libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
        NSString *writableDBPath = [libraryPath stringByAppendingPathComponent:DB_NAME];
        
        db = [[UASQLite alloc] initWithDBPath:writableDBPath];
        if (![db tableExists:@"analytics"]) {
            [db executeUpdate:CREATE_TABLE_CMD];
        }
    });
}

- (id)init {
    if (self = [super init]) {
        // Make sure and dispatch all of the database activity to the dbQueue. Failure to do so will result
        // in database corruption. 
        // dispatch_queue_create returns a queue with
        // a retain count of one, it only needs to be released.
        dbQueue =  dispatch_queue_create("com.urbanairship.analyticsdb", DISPATCH_QUEUE_SERIAL);
        [self createDatabaseIfNeeded];
    }

    return self;
}

- (void)dealloc {
    dispatch_sync(dbQueue, ^{
        [db close];
    });
    RELEASE_SAFELY(db);
    dispatch_release(dbQueue);
    [super dealloc];
}

// Used for development
- (void)resetDB {
    dispatch_sync(dbQueue, ^{
        [db executeUpdate:@"DROP TABLE analytics"];
        [db executeUpdate:CREATE_TABLE_CMD];
    });
}

- (void)addEvent:(UAEvent *)event withSession:(NSDictionary *)session {
    int estimateSize = [event getEstimatedSize];
    
    // Serialize the event data dictionary
    NSString *errString = nil;
    NSData *serializedData = [NSPropertyListSerialization dataFromPropertyList:event.data
                                                                        format:NSPropertyListBinaryFormat_v1_0
                                                              errorDescription:&errString];

    if (errString) {
        UALOG(@"Dictionary Serialization Error: %@", errString);
        [errString release];//must be relased by caller per docs
    }
    
    //insert an empty string if there isn't any event data
    if (!serializedData) {
        serializedData = [@"" dataUsingEncoding:NSUTF8StringEncoding];
    }
    
    // potential race condition with passed session
    NSDictionary* sessionCopy = [[session copy] autorelease];
    
    dispatch_async(dbQueue, ^{
        [db executeUpdate:@"INSERT INTO analytics (type, event_id, time, data, session_id, event_size) VALUES (?, ?, ?, ?, ?, ?)",
         [event getType],
         event.event_id,
         event.time,
         serializedData,
         [sessionCopy objectForKey:@"session_id"],
         [NSString stringWithFormat:@"%d", estimateSize]];
    });
    //UALOG(@"DB Count %d", [self eventCount]);
    //UALOG(@"DB Size %d", [self sizeInBytes]);
}

//If max<0, it will get all data.
- (NSArray *)getEvents:(int)max {
    __block NSArray *result = nil;
    dispatch_sync(dbQueue, ^{
        result = [db executeQuery:@"SELECT * FROM analytics ORDER BY _id LIMIT ?", [NSNumber numberWithInt:max]];
    });
    return result;
}

- (NSArray *)getEventByEventId:(NSString *)event_id {
    __block NSArray *result;
    dispatch_sync(dbQueue, ^{
        result = [db executeQuery:@"SELECT * FROM analytics WHERE event_id = ?", event_id];
    });
    return result;
}

- (void)deleteEvent:(NSNumber *)eventId {
    dispatch_async(dbQueue, ^{
        [db executeUpdate:@"DELETE FROM analytics WHERE event_id = ?", eventId];
    });
}

- (void)deleteEvents:(NSArray *)events {
    dispatch_async(dbQueue, ^{
        NSDictionary *event = nil;
        [db beginTransaction];
        for (event in events) {
            [db executeUpdate:@"DELETE FROM analytics WHERE event_id = ?", [event objectForKey:@"event_id"]];
        }
        [db commit];
    });

}

- (void)deleteBySessionId:(NSString *)sessionId {
    
    UALOG(@"Deleting session ID: %@", sessionId);
    
    if (sessionId == nil) {
        UALOG(@"Warn: sessionId is nil.");
        return;
    }
    dispatch_async(dbQueue, ^{
        [db executeUpdate:@"DELETE FROM analytics WHERE session_id = ?", sessionId];
    });
}

- (void)deleteOldestSession {
    NSArray *events = [self getEvents:1];
    if ([events count] <= 0) {
        UALOG(@"Warn: there are no events.");
        return;
    }

    NSDictionary *event = [events objectAtIndex:0];
    NSString *sessionId = [event objectForKey:@"session_id"];
    NSAssert(sessionId != nil, @"analytics session id is nil");

    [self deleteBySessionId:sessionId];
}

- (NSInteger)eventCount {
    
    __block NSArray *results = nil;
    dispatch_sync(dbQueue, ^{
        results = [db executeQuery:@"SELECT COUNT(_id) count FROM analytics"];
    });

    if ([results count] <= 0) {
        return 0;
    } else {
        NSNumber *count = (NSNumber *)[[results objectAtIndex:0] objectForKey:@"count"];
        if ([count isKindOfClass:[NSNull class]]) {
            return 0;
        }
        return [count intValue];
    }
}

- (NSInteger)sizeInBytes {
    __block NSArray *results = nil;
    dispatch_sync(dbQueue, ^{
       results = [db executeQuery:@"SELECT SUM(event_size) size FROM analytics"];
    });
    if ([results count] <= 0) {
        return 0;
    } else {
        NSNumber *count = (NSNumber *)[[results objectAtIndex:0] objectForKey:@"size"];
        if ([count isKindOfClass:[NSNull class]]) {
            return 0;
        }
        return [count intValue];
    }
}

@end
