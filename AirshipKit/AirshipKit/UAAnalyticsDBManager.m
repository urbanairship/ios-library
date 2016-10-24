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

#import "UAAnalyticsDBManager+Internal.h"

#import "UAirship.h"
#import "UAEvent+Internal.h"
#import "UASQLite+Internal.h"

#define DB_NAME @"UAAnalyticsDB"
#define CREATE_TABLE_CMD @"CREATE TABLE analytics (_id INTEGER PRIMARY KEY AUTOINCREMENT, type VARCHAR(255), event_id VARCHAR(255), time VARCHAR(255), data BLOB, session_id VARCHAR(255), event_size VARCHAR(255))"

@implementation UAAnalyticsDBManager

- (void)createDatabaseIfNeeded {
    dispatch_sync(dbQueue, ^{
        NSString *libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
        NSString *writableDBPath = [libraryPath stringByAppendingPathComponent:DB_NAME];
        
        self.db = [[UASQLite alloc] initWithDBPath:writableDBPath];
        if (![self.db tableExists:@"analytics"]) {
            [self.db executeUpdate:CREATE_TABLE_CMD];
        }
    });
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // Make sure and dispatch all of the database activity to the dbQueue. Failure to do so will result
        // in database corruption. 
        // dispatch_queue_create returns a queue with
        // a retain count of one, it only needs to be released.
        dbQueue =  dispatch_queue_create("com.urbanairship.analyticsdb", DISPATCH_QUEUE_SERIAL);
        [self createDatabaseIfNeeded];
    }

    return self;
}

// Used for development
- (void)resetDB {
    dispatch_sync(dbQueue, ^{
        [self.db executeUpdate:@"DROP TABLE analytics"];
        [self.db executeUpdate:CREATE_TABLE_CMD];
    });
}

- (void)addEvent:(UAEvent *)event withSessionID:(NSString *)sessionID {
    // Serialize the event data dictionary
    NSError *error = nil;
    NSData *serializedData = [NSPropertyListSerialization dataWithPropertyList:event.data
                                                                        format:NSPropertyListBinaryFormat_v1_0
                                                                       options:0
                                                                         error:&error];
    if (error) {
        UALOG(@"Dictionary Serialization Error: %@", error);
    }
    
    //insert an empty string if there isn't any event data
    if (!serializedData) {
        serializedData = [@"" dataUsingEncoding:NSUTF8StringEncoding];
    }

    dispatch_async(dbQueue, ^{
        [self.db executeUpdate:@"INSERT INTO analytics (type, event_id, time, data, session_id, event_size) VALUES (?, ?, ?, ?, ?, ?)",
         event.eventType,
         event.eventID,
         event.time,
         serializedData,
         sessionID,
         [NSString stringWithFormat:@"%lu", (unsigned long)event.jsonEventSize]];
    });
}

- (NSArray *)getEvents:(NSUInteger)max {
    if (max > INT32_MAX) {
        max = INT32_MAX;
    }

    __block NSArray *result = nil;

    dispatch_sync(dbQueue, ^{
        result = [self.db executeQuery:@"SELECT * FROM analytics ORDER BY _id LIMIT ?", [NSNumber numberWithUnsignedInteger:max]];
    });
    return result ?: @[];
}

- (NSArray *)getEventByEventID:(NSString *)eventID {
    __block NSArray *result;
    dispatch_sync(dbQueue, ^{
        result = [self.db executeQuery:@"SELECT * FROM analytics WHERE event_id = ?", eventID];
    });
    return result ?: @[];
}

- (void)deleteEvent:(NSNumber *)eventID {
    dispatch_async(dbQueue, ^{
        [self.db executeUpdate:@"DELETE FROM analytics WHERE event_id = ?", eventID];
    });
}

- (void)deleteEvents:(NSArray *)events {
    dispatch_async(dbQueue, ^{
        NSDictionary *event = nil;
        [self.db beginTransaction];
        for (event in events) {
            [self.db executeUpdate:@"DELETE FROM analytics WHERE event_id = ?", [event objectForKey:@"event_id"]];
        }
        [self.db commit];
    });

}

- (void)deleteBySessionID:(NSString *)sessionID {
    
    UALOG(@"Deleting session ID: %@", sessionID);
    
    if (sessionID == nil) {
        UALOG(@"Warn: sessionID is nil.");
        return;
    }
    dispatch_async(dbQueue, ^{
        [self.db executeUpdate:@"DELETE FROM analytics WHERE session_id = ?", sessionID];
    });
}

- (void)deleteOldestSession {
    NSArray *events = [self getEvents:1];
    if ([events count] <= 0) {
        UALOG(@"Warn: there are no events.");
        return;
    }

    NSDictionary *event = [events objectAtIndex:0];
    NSString *sessionID = [event objectForKey:@"session_id"];
    NSAssert(sessionID != nil, @"analytics session ID is nil");

    [self deleteBySessionID:sessionID];
}

- (NSUInteger)eventCount {
    
    __block NSArray *results = nil;
    dispatch_sync(dbQueue, ^{
        results = [self.db executeQuery:@"SELECT COUNT(_id) count FROM analytics"];
    });

    if ([results count] <= 0) {
        return 0;
    } else {
        NSNumber *count = (NSNumber *)[[results objectAtIndex:0] objectForKey:@"count"];
        if ([count isKindOfClass:[NSNull class]]) {
            return 0;
        }
        return [count unsignedIntegerValue];
    }
}

- (NSUInteger)sizeInBytes {
    __block NSArray *results = nil;
    dispatch_sync(dbQueue, ^{
       results = [self.db executeQuery:@"SELECT SUM(event_size) size FROM analytics"];
    });
    if ([results count] <= 0) {
        return 0;
    } else {
        NSNumber *count = (NSNumber *)[[results objectAtIndex:0] objectForKey:@"size"];
        if ([count isKindOfClass:[NSNull class]]) {
            return 0;
        }
        return [count unsignedIntegerValue];
    }
}

@end
