/*
 Copyright 2009-2011 Urban Airship Inc. All rights reserved.

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
#import "UAInboxMessage.h"

@implementation UAInboxDBManager

SINGLETON_IMPLEMENTATION(UAInboxDBManager)

- (id)init {
    if (self = [super init]) {
        [self createEditableCopyOfDatabaseIfNeeded];
        // We can always reset database before we launch it with db function
        //[self resetDB];
        [self initDBIfNeeded];
    }
    return self;
}

- (void)dealloc {
    [db close];
    RELEASE_SAFELY(db);
    [super dealloc];
}

- (void)resetDB {
    [db executeUpdate:@"DROP TABLE messages"];
    [db executeUpdate:@"CREATE TABLE messages (id VARCHAR(255) PRIMARY KEY, title VARCHAR(255), body_url VARCHAR(255), sent_time VARCHAR(255), unread INTEGER, url VARCHAR(255), app_id VARCHAR(255), user_id VARCHAR(255))"];
    UA_FMDBLogError
}

- (void)initDBIfNeeded {
    if (![db tableExists:@"messages"]) {
        [db executeUpdate:@"CREATE TABLE messages (id VARCHAR(255) PRIMARY KEY, title VARCHAR(255), body_url VARCHAR(255), sent_time VARCHAR(255), unread INTEGER, url VARCHAR(255), app_id VARCHAR(255), user_id VARCHAR(255))"];
        UA_FMDBLogError
    }
}

- (void)moveLegacyDatabase {
    
    NSArray *docPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [docPaths objectAtIndex:0];
    NSString *oldDbPath = [documentsDirectory stringByAppendingPathComponent:OLD_DB_NAME];

    NSArray *libPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *libraryDirectory = [libPaths objectAtIndex:0];
    NSString *newDbPath = [libraryDirectory stringByAppendingPathComponent:DB_NAME];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    
    if (![fileManager fileExistsAtPath:newDbPath] && [fileManager fileExistsAtPath:oldDbPath]) {
        UALOG(@"Moving legacy AirMail database.");
        [fileManager moveItemAtPath:oldDbPath toPath:newDbPath error:&error];
        
        if (error) {
            UALOG(@"Failed to move the database. %@", [error localizedDescription]);
        }
    }
    
}

- (void)createEditableCopyOfDatabaseIfNeeded {

    NSFileManager *fileManager = [NSFileManager defaultManager];

    NSArray *libraryDirectories = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *libraryDirectory = [libraryDirectories objectAtIndex:0];
    NSString *dbPath = [libraryDirectory stringByAppendingPathComponent:DB_NAME];
    
    if (![fileManager fileExistsAtPath:dbPath]) {
        //move old db
        [self moveLegacyDatabase];
    }

    db = [[UA_FMDatabase databaseWithPath:dbPath] retain];
    if (![db open]) {
        UALOG(@"Failed to open database");
    }
}

- (NSMutableArray *)getMessagesForUser:(NSString *)userId App:(NSString *)appId {
    UA_FMResultSet *rs;
    NSMutableArray *result = [NSMutableArray array];
    UAInboxMessage *msg;
    rs = [db executeQuery:@"SELECT * FROM messages WHERE app_id = ? and user_id = ? order by sent_time desc", appId, userId];
    while ([rs next]) {
        msg = [[[UAInboxMessage alloc] init] autorelease];
        msg.messageID = [rs stringForColumn:@"id"];
        msg.messageBodyURL = [NSURL URLWithString:[rs stringForColumn:@"body_url"]];
        msg.messageURL = [NSURL URLWithString:[rs stringForColumn:@"url"]];
        msg.unread = [rs intForColumn:@"unread"]==1? YES: NO;

        NSString *dateString = [rs stringForColumn:@"sent_time"]; //2010-04-16 16:32:50
        NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
		NSLocale *enUSPOSIXLocale = [[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] autorelease];
		[dateFormatter setLocale:enUSPOSIXLocale];
        [dateFormatter setTimeStyle:NSDateFormatterFullStyle];
        [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
		[dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
        msg.messageSent = [dateFormatter dateFromString:dateString];
        [dateFormatter release];

        msg.title = [rs stringForColumn:@"title"];
        [result addObject: msg];
    }
    return result;
}

- (void)addMessages:(NSArray *)messages forUser:(NSString *)userId App:(NSString *)appId {
    NSDateFormatter* dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
	NSLocale *enUSPOSIXLocale = [[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] autorelease];
	[dateFormatter setLocale:enUSPOSIXLocale];
    [dateFormatter setTimeStyle:NSDateFormatterFullStyle];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
	[dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    [db beginTransaction];
    for (UAInboxMessage *message in messages) {
        [db executeUpdate:@"INSERT INTO messages (id, title, body_url, sent_time, unread, url, app_id, user_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?)" ,
         message.messageID,
         message.title,
         message.messageBodyURL,
         [dateFormatter stringFromDate:message.messageSent],
         [NSNumber numberWithInt:(message.unread?1:0)],
         message.messageURL,
         appId,
         userId];
    }
    [db commit];
    UA_FMDBLogError
}

- (void)deleteMessages:(NSArray *)messages {
    NSArray *messageIDs = [messages valueForKeyPath:@"messageID"];
    NSString *idsString = [NSString stringWithFormat:@"'%@'", [messageIDs componentsJoinedByString:@"', '"]];
    NSString *deleteStmt = [NSString stringWithFormat:
                            @"DELETE FROM messages WHERE id IN (%@)", idsString];
    UALOG(@"batch delete statement: %@", deleteStmt);

    [db beginTransaction];
    [db executeUpdate:deleteStmt];
    [db commit];
    UA_FMDBLogError
}

- (void)updateMessageAsRead:(UAInboxMessage *)msg {
    [db executeUpdate:@"UPDATE messages SET unread = 0 WHERE id = ?", msg.messageID];
    UA_FMDBLogError
}

- (void)updateMessagesAsRead:(NSArray *)messages {
    NSArray *messageIDs = [messages valueForKeyPath:@"messageID"];
    NSString *idsString = [NSString stringWithFormat:@"'%@'", [messageIDs componentsJoinedByString:@"', '"]];
    NSString *deleteStmt = [NSString stringWithFormat:
                            @"UPDATE messages SET unread = 0 WHERE id IN (%@)", idsString];
    UALOG(@"batch mark as read statement: %@", deleteStmt);

    [db beginTransaction];
    [db executeUpdate:deleteStmt];
    [db commit];
    UA_FMDBLogError
}

@end
