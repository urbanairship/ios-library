/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

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

#import "UAInboxDBManager.h"
#import "UA_FMDatabase.h"

#import "UAInboxMessage.h"

#import "UA_SBJSON.h"

#import "UAUtils.h"

@implementation UAInboxDBManager

SINGLETON_IMPLEMENTATION(UAInboxDBManager)

- (id)init {
    self = [super init];
    if (self) {
        [self createEditableCopyOfDatabaseIfNeeded];
        // We can always reset database before we launch it with db function
        //[self resetDB];
        [self initDBIfNeeded];
    }
    return self;
}

- (void)dealloc {
    [self.db close];
    self.db = nil;
    [super dealloc];
}

- (void)resetDB {
    [self.db executeUpdate:@"DROP TABLE messages"];
    [self.db executeUpdate:@"CREATE TABLE messages (id VARCHAR(255) PRIMARY KEY, title VARCHAR(255), body_url VARCHAR(255), sent_time VARCHAR(255), unread INTEGER, url VARCHAR(255), app_id VARCHAR(255), user_id VARCHAR(255), extra VARCHAR(255), rawMessageObject BLOB)"];
    UA_FMDBLogError
}

- (void)initDBIfNeeded {
    if (![self.db tableExists:@"messages"]) {
        [self.db executeUpdate:@"CREATE TABLE messages (id VARCHAR(255) PRIMARY KEY, title VARCHAR(255), body_url VARCHAR(255), sent_time VARCHAR(255), unread INTEGER, url VARCHAR(255), app_id VARCHAR(255), user_id VARCHAR(255), extra VARCHAR(255), rawMessageObject BLOB)"];
        UA_FMDBLogError
    }
}

- (void)createEditableCopyOfDatabaseIfNeeded {
    NSArray *libraryDirectories = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *libraryDirectory = [libraryDirectories objectAtIndex:0];
    NSString *dbPath = [libraryDirectory stringByAppendingPathComponent:DB_NAME];

    self.db = [[[UA_FMDatabase databaseWithPath:dbPath] retain] autorelease];
    if (![self.db open]) {
        UA_LDEBUG(@"Failed to open database.");
    }
}

- (NSMutableArray *)getMessagesForUser:(NSString *)userID app:(NSString *)appKey {

    UA_FMResultSet *rs;
    NSMutableArray *result = [NSMutableArray array];
    UAInboxMessage *msg;
    rs = [self.db executeQuery:@"SELECT * FROM messages WHERE app_id = ? and user_id = ? order by sent_time desc", appKey, userID];
    while ([rs next]) {
        msg = [[[UAInboxMessage alloc] init] autorelease];
        msg.messageID = [rs stringForColumn:@"id"];
        msg.messageBodyURL = [NSURL URLWithString:[rs stringForColumn:@"body_url"]];
        msg.messageURL = [NSURL URLWithString:[rs stringForColumn:@"url"]];
        msg.unread = [rs intForColumn:@"unread"]==1? YES: NO;

        NSString *dateString = [rs stringForColumn:@"sent_time"]; //2010-04-16 16:32:50
        msg.messageSent = [[UAUtils ISODateFormatterUTC] dateFromString:dateString];

        msg.title = [rs stringForColumn:@"title"];
        
        msg.extra = [[[UA_SBJsonParser new] autorelease] objectWithString:[rs stringForColumn:@"extra"]];

        NSString *messageJSON = [[[NSString alloc] initWithData:[rs dataForColumn:@"rawMessageObject"] encoding:NSUTF8StringEncoding] autorelease];
        msg.rawMessageObject = [[[UA_SBJsonParser new] autorelease] objectWithString:messageJSON];
        
        [result addObject: msg];
    }
    return result;
}

- (void)addMessages:(NSArray *)messages forUser:(NSString *)userID app:(NSString *)appKey {

    [self.db beginTransaction];
    for (UAInboxMessage *message in messages) {
        [self.db executeUpdate:@"INSERT INTO messages (id, title, body_url, sent_time, unread, url, app_id, user_id, extra, rawMessageObject) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)" ,
         message.messageID,
         message.title,
         message.messageBodyURL,
         [[UAUtils ISODateFormatterUTC] stringFromDate:message.messageSent],
         [NSNumber numberWithInt:(message.unread?1:0)],
         message.messageURL,
         appKey,
         userID,
         [[[UA_SBJsonWriter new] autorelease] stringWithObject:message.extra],
         [[[UA_SBJsonWriter new] autorelease] stringWithObject:message.rawMessageObject]];
    }
    [self.db commit];
    UA_FMDBLogError
}

- (void)deleteMessages:(NSArray *)messages {
    NSArray *messageIDs = [messages valueForKeyPath:@"messageID"];
    NSString *idsString = [NSString stringWithFormat:@"'%@'", [messageIDs componentsJoinedByString:@"', '"]];
    NSString *deleteStmt = [NSString stringWithFormat:
                            @"DELETE FROM messages WHERE id IN (%@)", idsString];
    
    UA_LTRACE(@"Delete messages statement: %@", deleteStmt);

    [self.db beginTransaction];
    [self.db executeUpdate:deleteStmt];
    [self.db commit];
    UA_FMDBLogError
}

- (void)updateMessageAsRead:(UAInboxMessage *)msg {
    [self.db executeUpdate:@"UPDATE messages SET unread = 0 WHERE id = ?", msg.messageID];
    UA_FMDBLogError
}

- (void)updateMessagesAsRead:(NSArray *)messages {
    NSArray *messageIDs = [messages valueForKeyPath:@"messageID"];
    NSString *idsString = [NSString stringWithFormat:@"'%@'", [messageIDs componentsJoinedByString:@"', '"]];
    NSString *updateStmt = [NSString stringWithFormat:
                            @"UPDATE messages SET unread = 0 WHERE id IN (%@)", idsString];

    UA_LTRACE(@"Update messages as read statement: %@", updateStmt);

    [self.db beginTransaction];
    [self.db executeUpdate:updateStmt];
    [self.db commit];
    UA_FMDBLogError
}

@end
