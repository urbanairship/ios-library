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

#import "UAGlobal.h"
#import <Foundation/Foundation.h>
#import "UA_FMDatabase.h"
#import "UA_FMDatabaseAdditions.h"

#define FMDBLogError if ([db hadError]) { UALOG(@"Err %d: %@", [db lastErrorCode], [db lastErrorMessage]);}
#define DB_NAME @"AirMail.db"


@class UAInboxMessage;
@interface UAInboxDBManager : NSObject {
    UA_FMDatabase *db;
}

SINGLETON_INTERFACE(UAInboxDBManager);

- (void)createEditableCopyOfDatabaseIfNeeded;
- (void)initDBIfNeeded;
- (NSMutableArray *)getMessagesForUser:(NSString *)userId App:(NSString *)appId;
- (void)addMessages:(NSArray *)messages forUser:(NSString *)userId App:(NSString *)appId;
- (void)deleteMessages:(NSArray *)messages;
- (void)updateMessageAsRead:(UAInboxMessage *)msg;
- (void)updateMessagesAsRead:(NSArray *)messages;

// Helper for development
- (void)resetDB;

@end
