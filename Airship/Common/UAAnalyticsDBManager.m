/*
 Copyright 2009-2011 Urban Airship Inc. All rights reserved.

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

#define DB_NAME @"UAAnalyticsDB"
#define CREATE_TABLE_CMD @"CREATE TABLE analytics (_id INTEGER PRIMARY KEY AUTOINCREMENT, type VARCHAR(255), event_id VARCHAR(255), time VARCHAR(255), data BLOB, session_id VARCHAR(255), event_size VARCHAR(255))"

@implementation UAAnalyticsDBManager

SINGLETON_IMPLEMENTATION(UAAnalyticsDBManager)


- (void)createDatabaseIfNeeded {
    NSString *libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
    NSString *writableDBPath = [libraryPath stringByAppendingPathComponent:DB_NAME];

    db = [[UASQLite alloc] initWithDBPath:writableDBPath];
    if (![db tableExists:@"analytics"]) {
        [db executeUpdate:CREATE_TABLE_CMD];
    }
}

- (id)init {
    if (self = [super init]) {
        [self createDatabaseIfNeeded];
    }

    return self;
}

- (void)dealloc {
    [db close];
    RELEASE_SAFELY(db);

    [super dealloc];
}

// Used for development
- (void)resetDB {
    [db executeUpdate:@"DROP TABLE analytics"];
    [db executeUpdate:CREATE_TABLE_CMD];
}

- (void)addEvent:(UAEvent *)event withSession:(NSDictionary *)session {
    int estimateSize = [event getEstimatedSize];
    
    // Serialize the event data dictionary
    NSError *err = nil;
    NSData *serializedData = [NSPropertyListSerialization dataWithPropertyList:event.data 
                                                                        format:NSPropertyListBinaryFormat_v1_0 
                                                                       options:0 /* unused, Apple says set to 0 */ 
                                                                         error:&err];
    if (err) {
        UALOG(@"Dictionary Serialization Error: %@", [[err userInfo] description]);
    }
    
    [db executeUpdate:@"INSERT INTO analytics (type, event_id, time, data, session_id, event_size) VALUES (?, ?, ?, ?, ?, ?)",
     [event getType],
     event.event_id,
     event.time,
     serializedData,
     [session objectForKey:@"session_id"],
     [NSString stringWithFormat:@"%d", estimateSize]];
    
    
    UALOG(@"DB Count %d", [self eventCount]);
    UALOG(@"DB Size %d", [self sizeInBytes]);
}

//If max<0, it will get all data.
- (NSArray *)getEvents:(int)max {
    NSArray *result = [db executeQuery:@"SELECT * FROM analytics ORDER BY _id LIMIT ?",
                       [NSNumber numberWithInt:max]];
    return result;
}

- (NSArray *)getEventByEventId:(NSString *)event_id {
    NSArray *result = [db executeQuery:@"SELECT * FROM analytics WHERE event_id = ?", event_id];
    return result;
}

- (void)deleteEvent:(NSNumber *)eventId {
    [db executeUpdate:@"DELETE FROM analytics WHERE event_id = ?", eventId];
}

- (void)deleteEvents:(NSArray *)events {
    NSDictionary *event;

    [db beginTransaction];
    for (event in events) {
        [db executeUpdate:@"DELETE FROM analytics WHERE event_id = ?", [event objectForKey:@"event_id"]];
    }
    [db commit];
}

- (void)deleteBySessionId:(NSString *)sessionId {
    
    UALOG(@"Deleting session ID: %@", sessionId);
    
    if (sessionId == nil) {
        UALOG(@"Warn: sessionId is nil.");
        return;
    }

    [db executeUpdate:@"DELETE FROM analytics WHERE session_id = ?", sessionId];
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
    
    NSArray *results = [db executeQuery:@"SELECT COUNT(_id) count FROM analytics"];

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
    NSArray *results = [db executeQuery:@"SELECT SUM(event_size) size FROM analytics"];
    
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
