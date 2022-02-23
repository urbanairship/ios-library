/* Copyright Airship and Contributors */

#import "UAInboxStore+Internal.h"
#import "UAMessageCenterResources.h"
#import "UAAirshipMessageCenterCoreImport.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif
@interface UAInboxStore()
@property (strong, nonatomic) UACoreData *coreData;
@end

@implementation UAInboxStore

- (instancetype)initWithName:(NSString *)storeName inMemory:(BOOL)inMemory {
    self = [super init];


    if (self) {
        NSURL *modelURL = [[UAMessageCenterResources bundle] URLForResource:@"UAInbox" withExtension:@"momd"];
        self.coreData = [[UACoreData alloc] initWithModelURL:modelURL inMemory:inMemory stores:@[storeName]];
    }

    return self;
}

+ (instancetype)storeWithName:(NSString *)storeName inMemory:(BOOL)inMemory {
    return [[UAInboxStore alloc] initWithName:storeName inMemory:inMemory];
}

+ (instancetype)storeWithName:(NSString *)storeName {
    return [UAInboxStore storeWithName:storeName inMemory:NO];
}


- (NSArray<UAInboxMessage *> *)fetchMessagesWithPredicate:(NSPredicate *)predicate {
    __block NSMutableArray<UAInboxMessage *> *messages = [NSMutableArray array];

    [self.coreData safePerformBlockAndWait:^(BOOL isSafe, NSManagedObjectContext *context) {
        if (!isSafe) {
            return;
        }

        NSArray<UAInboxMessageData *> *result = [self fetchMessageDataWithPredicate:predicate];

        for (UAInboxMessageData *data in result) {
            [messages addObject:[self messageFromMessageData:data]];
        }
    }];

    return messages;
}

- (void)fetchMessagesWithPredicate:(nullable NSPredicate *)predicate completionHandler:(void (^)(NSArray<UAInboxMessage *> *))completionHandler {
    [self.coreData safePerformBlock:^(BOOL isSafe, NSManagedObjectContext *context) {
        if (!isSafe) {
            completionHandler(@[]);
            return;
        }

        NSArray<UAInboxMessageData *> *result = [self fetchMessageDataWithPredicate:predicate];
        NSMutableArray *messages = [NSMutableArray array];

        for (UAInboxMessageData *data in result) {
            [messages addObject:[self messageFromMessageData:data]];
        }

        completionHandler(messages);
    }];
}


- (NSArray<UAInboxMessageData *> *)fetchMessageDataWithPredicate:(NSPredicate *)predicate {
    __block NSArray<UAInboxMessageData *> *data = @[];
    [self.coreData safePerformBlockAndWait:^(BOOL isSafe, NSManagedObjectContext *context) {
        if (!isSafe) {
            return;
        }

        NSError *error = nil;

        NSFetchRequest *request = [[NSFetchRequest alloc] init];
        request.entity = [NSEntityDescription entityForName:kUAInboxDBEntityName
                                     inManagedObjectContext:context];

        NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"messageSent" ascending:NO];
        request.sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];
        request.predicate = predicate;

        data = [context executeFetchRequest:request error:&error];

        if (error) {
            UA_LERR(@"Error executing fetch request: %@ with error: %@", request, error);
        }

        [UACoreData safeSave:context];
    }];

    return data;
}


- (void)markMessagesLocallyReadWithIDs:(NSArray<NSString *> *)messageIDs completionHandler:(void (^)(void))completionHandler {
    [self.coreData safePerformBlock:^(BOOL isSafe, NSManagedObjectContext *context) {
        if (!isSafe) {
            completionHandler();
            return;
        }

        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kUAInboxDBEntityName];
        request.predicate = [NSPredicate predicateWithFormat:@"messageID IN %@", messageIDs];

        NSError *error;
        NSArray *result = [context executeFetchRequest:request error:&error];

        if (error) {
            UA_LERR(@"Error marking messages read %@", error);
            completionHandler();
            return;
        }

        for (UAInboxMessageData *data in result) {
            data.unreadClient = NO;
        }

        [UACoreData safeSave:context];

        completionHandler();
    }];
}

- (void)markMessagesLocallyDeletedWithIDs:(NSArray<NSString *> *)messageIDs completionHandler:(void (^)(void))completionHandler {
    [self.coreData safePerformBlock:^(BOOL isSafe, NSManagedObjectContext *context) {
        if (!isSafe) {
            return;
        }

        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kUAInboxDBEntityName];
        request.predicate = [NSPredicate predicateWithFormat:@"messageID IN %@", messageIDs];

        NSError *error;
        NSArray *result = [context executeFetchRequest:request error:&error];

        if (error) {
            UA_LERR(@"Error marking messages deleted %@", error);
            return;
        }

        for (UAInboxMessageData *data in result) {
            data.deletedClient = YES;
        }

        [UACoreData safeSave:context];

        completionHandler();
    }];
}

- (void)markMessagesGloballyReadWithIDs:(NSArray<NSString *> *)messageIDs {
    [self.coreData safePerformBlockAndWait:^(BOOL isSafe, NSManagedObjectContext *context) {
        if (!isSafe) {
            return;
        }

        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kUAInboxDBEntityName];
        request.predicate = [NSPredicate predicateWithFormat:@"messageID IN %@", messageIDs];

        NSError *error;
        NSArray *result = [context executeFetchRequest:request error:&error];

        if (error) {
            UA_LERR(@"Error marking messages read %@", error);
            return;
        }

        for (UAInboxMessageData *data in result) {
            data.unread = NO;
        }

        [UACoreData safeSave:context];
    }];
}

- (void)deleteMessagesWithIDs:(NSArray<NSString *> *)messageIDs {
    [self.coreData safePerformBlockAndWait:^(BOOL isSafe, NSManagedObjectContext *context) {
        if (!isSafe) {
            return;
        }

        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kUAInboxDBEntityName];
        request.predicate = [NSPredicate predicateWithFormat:@"messageID IN %@", messageIDs];

        NSError *error;
        NSBatchDeleteRequest *deleteRequest = [[NSBatchDeleteRequest alloc] initWithFetchRequest:request];
        [context executeRequest:deleteRequest error:&error];

        if (error) {
            UA_LERR(@"Error deleting messages %@", error);
            return;
        }

        [UACoreData safeSave:context];
    }];
}

- (BOOL)syncMessagesWithResponse:(NSArray *)messages {
    __block BOOL result;

    [self.coreData safePerformBlockAndWait:^(BOOL isSafe, NSManagedObjectContext *context) {
        if (!isSafe) {
            result = NO;
            return;
        }

        // Track the response messageIDs so we can remove any messages that are
        // no longer in the response.
        NSMutableSet *newMessageIDs = [NSMutableSet set];

        for (NSDictionary *messagePayload in messages) {
            NSString *messageID = messagePayload[@"message_id"];

            if (!messageID) {
                UA_LDEBUG(@"Missing message ID: %@", messagePayload);
                continue;
            }

            if (![self updateMessageWithDictionary:messagePayload context:context]) {
                [self addMessageFromDictionary:messagePayload context:context];
            }

            [newMessageIDs addObject:messageID];
        }

        // Delete any messages that are no longer in the array
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kUAInboxDBEntityName];
        request.predicate = [NSPredicate predicateWithFormat:@"NOT (messageID IN %@)", newMessageIDs];

        NSError *error;
        if (self.coreData.inMemory) {
            request.includesPropertyValues = NO;
            NSArray *events = [context executeFetchRequest:request error:&error];
            for (NSManagedObject *event in events) {
                [context deleteObject:event];
            }
        } else {
            NSBatchDeleteRequest *deleteRequest = [[NSBatchDeleteRequest alloc] initWithFetchRequest:request];
            [context executeRequest:deleteRequest error:&error];
        }

        result = [UACoreData safeSave:context];
    }];

    return result;
}

- (NSDictionary<NSString *, NSDictionary *> *)locallyReadMessageReporting {
    __block NSMutableDictionary<NSString *, NSDictionary *> *result = [NSMutableDictionary dictionary];

    [self.coreData safePerformBlockAndWait:^(BOOL isSafe, NSManagedObjectContext *context) {
        if (!isSafe) {
            return;
        }

        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"unreadClient == NO && unread == YES"];
        NSArray<UAInboxMessageData *> *messages = [self fetchMessageDataWithPredicate:predicate];

        for (UAInboxMessageData *data in messages) {
            if (data.messageReporting) {
                result[data.messageID] = data.messageReporting;
            }
        }
    }];

    return result;
}

- (NSDictionary<NSString *, NSDictionary *> *)locallyDeletedMessageReporting {
    __block NSMutableDictionary<NSString *, NSDictionary *> *result = [NSMutableDictionary dictionary];

    [self.coreData safePerformBlockAndWait:^(BOOL isSafe, NSManagedObjectContext *context) {
        if (!isSafe) {
            return;
        }

        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"deletedClient == YES"];
        NSArray<UAInboxMessageData *> *messages = [self fetchMessageDataWithPredicate:predicate];

        for (UAInboxMessageData *data in messages) {
            if (data.messageReporting) {
                result[data.messageID] = data.messageReporting;
            }
        }
    }];

    return result;
}

- (void)updateMessageData:(UAInboxMessageData *)data withDictionary:(NSDictionary *)dict {

    dict = [dict dictionaryWithValuesForKeys:[[dict keysOfEntriesPassingTest:^BOOL(id key, id obj, BOOL *stop) {
        return ![obj isEqual:[NSNull null]];
    }] allObjects]];

    if (!data.isGone) {
        data.messageID = dict[@"message_id"];
        data.contentType = dict[@"content_type"];
        data.title = dict[@"title"];
        data.extra = dict[@"extra"];
        data.messageBodyURL = [NSURL URLWithString:dict[@"message_body_url"]];
        data.messageURL = [NSURL URLWithString:dict[@"message_url"]];
        data.unread = [dict[@"unread"] boolValue];
        data.messageSent = [UAUtils parseISO8601DateFromString:dict[@"message_sent"]];
        data.rawMessageObject = dict;
        data.messageReporting = dict[@"message_reporting"];

        NSString *messageExpiration = dict[@"message_expiry"];
        if (messageExpiration) {
            data.messageExpiration = [UAUtils parseISO8601DateFromString:messageExpiration];
        } else {
            data.messageExpiration = nil;
        }
    }
}

- (void)deleteMessages {
    [self.coreData performBlockIfStoresExist:^(BOOL isSafe, NSManagedObjectContext *context) {
        if (!isSafe) {
            return;
        }

        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kUAInboxDBEntityName];
        NSError *error;

        if (self.coreData.inMemory) {
            request.includesPropertyValues = NO;
            NSArray *messages = [context executeFetchRequest:request error:&error];
            for (NSManagedObject *message in messages) {
                [context deleteObject:message];
            }
        } else {
            NSBatchDeleteRequest *deleteRequest = [[NSBatchDeleteRequest alloc] initWithFetchRequest:request];
            [context executeRequest:deleteRequest error:&error];
        }

        if (error) {
            UA_LERR(@"Error deleting messages %@", error);
            return;
        }

        [UACoreData safeSave:context];
    }];
}

- (void)addMessageFromDictionary:(NSDictionary *)dictionary context:(NSManagedObjectContext *)context {
    UAInboxMessageData *data = (UAInboxMessageData *)[NSEntityDescription insertNewObjectForEntityForName:kUAInboxDBEntityName
                                                                                   inManagedObjectContext:context];
    [self updateMessageData:data withDictionary:dictionary];
}

- (BOOL)updateMessageWithDictionary:(NSDictionary *)dictionary context:(NSManagedObjectContext *)context {
    NSString *messageID = dictionary[@"message_id"];
    NSError *error = nil;

    if (!messageID) {
        UA_LDEBUG(@"Missing message ID: %@", dictionary);
        return NO;
    }

    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    request.entity = [NSEntityDescription entityForName:kUAInboxDBEntityName
                                 inManagedObjectContext:context];
    request.predicate = [NSPredicate predicateWithFormat:@"messageID == %@", messageID];
    request.fetchLimit = 1;

    NSArray *resultData = [context executeFetchRequest:request error:&error];

    if (error) {
        UA_LERR(@"Fetch request %@ failed with with error: %@", request, error);
    }

    UAInboxMessageData *data;
    if (resultData.count) {
        data = [resultData lastObject];
        [self updateMessageData:data withDictionary:dictionary];
        return YES;
    }
    
    return NO;
}

- (UAInboxMessage *)messageFromMessageData:(UAInboxMessageData *)data {
    return [UAInboxMessage messageWithBuilderBlock:^(UAInboxMessageBuilder *builder) {
        builder.messageURL = data.messageURL;
        builder.messageID = data.messageID;
        builder.messageSent = data.messageSent;
        builder.messageBodyURL = data.messageBodyURL;
        builder.messageExpiration = data.messageExpiration;
        builder.unread = data.unreadClient & data.unread;
        builder.rawMessageObject = data.rawMessageObject;
        builder.extra = data.extra;
        builder.title = data.title;
        builder.contentType = data.contentType;
        builder.messageList = self.messageList;
    }];
}

- (void)shutDown {
    [self.coreData shutDown];
}

@end
