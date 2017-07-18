/* Copyright 2017 Urban Airship and Contributors */

#import <CoreData/CoreData.h>

#import "UAInboxDBManager+Internal.h"
#import "UAConfig.h"
#import "UAUtils.h"
#import "UAInboxMessage+Internal.h"
#import "UAInboxMessageData+Internal.h"
#import "UAirship+Internal.h"

@interface UAInboxDBManager()
@property (nonatomic, copy) NSString *storeName;
@end

@implementation UAInboxDBManager


- (instancetype)initWithConfig:(UAConfig *)config {
    self = [super init];
    if (self) {
        self.storeName = [NSString stringWithFormat:kUACoreDataStoreName, config.appKey];

        NSPersistentStoreCoordinator *psc = [UAInboxDBManager createPersistantStoreWithStoreName:self.storeName];

        self.mainContext = [UAInboxDBManager createContextWithPersistantStoreCoordinator:psc
                                                                         concurrencyType:NSMainQueueConcurrencyType];

        self.privateContext = [UAInboxDBManager createContextWithPersistantStoreCoordinator:psc
                                                                            concurrencyType:NSPrivateQueueConcurrencyType];

        if (self.mainContext) {
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(mainContextDidSave:)
                                                         name:NSManagedObjectContextDidSaveNotification
                                                       object:self.mainContext];
        }

        if (self.privateContext) {
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(privateContextDidSave:)
                                                         name:NSManagedObjectContextDidSaveNotification
                                                       object:self.privateContext];
        }
    }

    return self;
}

- (void)mainContextDidSave:(NSNotification *)notification {
    [self.privateContext performBlock:^{
        [self.privateContext mergeChangesFromContextDidSaveNotification:notification];
    }];
}

- (void)privateContextDidSave:(NSNotification *)notification {
    [self.mainContext performBlock:^{
        [self.mainContext mergeChangesFromContextDidSaveNotification:notification];
    }];
}


+ (NSManagedObjectContext *)createContextWithPersistantStoreCoordinator:(NSPersistentStoreCoordinator *)psc
                                                        concurrencyType:(NSManagedObjectContextConcurrencyType)concurrencyType {

    if (!psc) {
        return nil;
    }
    NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType:concurrencyType];
    [context setPersistentStoreCoordinator:psc];
    return context;
}

+ (NSPersistentStoreCoordinator *)createPersistantStoreWithStoreName:(NSString *)storeName {

    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *libraryDirectoryURL = [[fm URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *directoryURL = [libraryDirectoryURL URLByAppendingPathComponent:storeName];
    NSURL *storeURL = [directoryURL URLByAppendingPathComponent:storeName];

    // Create the store directory if it doesnt exist
    if (![fm fileExistsAtPath:[directoryURL path]]) {
        NSError *error = nil;
        if (![fm createDirectoryAtURL:directoryURL withIntermediateDirectories:YES attributes:nil error:&error]) {
            UA_LERR(@"Error creating inbox directory %@: %@", [directoryURL lastPathComponent], error);
        } else {
            [UAUtils addSkipBackupAttributeToItemAtURL:directoryURL];
        }
    }

    // Move the legacy store name if it exists
    NSURL *legacyURL = [libraryDirectoryURL URLByAppendingPathComponent:kUACoreDataStoreName];
    if ([fm fileExistsAtPath:[legacyURL path]]) {
        NSError *error = nil;
        if (![fm moveItemAtURL:legacyURL toURL:directoryURL error:&error]) {
            UA_LERR(@"Error moving legacy inbox directory %@ to current directory %@: %@", [legacyURL lastPathComponent], [directoryURL lastPathComponent], error);
        }
    }

    NSError *error = nil;

    NSURL *modelURL = [[UAirship resources] URLForResource:@"UAInbox" withExtension:@"momd"];
    NSManagedObjectModel *mom = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    NSPersistentStoreCoordinator *psc = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];

    NSDictionary *options = @{ NSMigratePersistentStoresAutomaticallyOption : @YES,
                               NSInferMappingModelAutomaticallyOption : @YES };

    if (![psc addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:options error:&error]) {
        UA_LERR(@"Error adding persistent store: %@, %@", error, [error userInfo]);

        if ([[NSFileManager defaultManager] removeItemAtURL:storeURL error:&error]) {
            UA_LERR(@"Error removing persistent store at URL: %@ with error: %@, %@", storeURL, error, [error userInfo]);
            return nil;
        }

        if (![psc addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:options error:&error]) {
            UA_LERR(@"Failed to create persistant store: %@, %@", error, [error userInfo]);
            return nil;
        }
    }

    return psc;
}


- (void)fetchMessagesWithPredicate:(NSPredicate *)predicate
                           context:(NSManagedObjectContext *)context
                 completionHandler:(void(^)(NSArray *messages))completionHandler {

    if (!context) {
        if (completionHandler) {
            completionHandler(nil);
        }
    }

    [context performBlock:^{
        NSError *error = nil;

        NSFetchRequest *request = [[NSFetchRequest alloc] init];
        request.entity = [NSEntityDescription entityForName:kUAInboxDBEntityName
                                     inManagedObjectContext:context];

        NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"messageSent" ascending:NO];
        request.sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];
        request.predicate = predicate;

        NSArray *resultData = [context executeFetchRequest:request error:&error];

        if (error) {
            UA_LERR(@"Error executing fetch request: %@ with error: %@", request, error);
        }

        NSMutableArray *resultMessages = [NSMutableArray array];
        for (UAInboxMessageData *data in resultData) {
            [resultMessages addObject:[UAInboxMessage messageWithData:data]];
        }

        if (completionHandler) {
            completionHandler(resultMessages);
        }
    }];
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

        NSString *messageExpiration = dict[@"message_expiry"];
        if (messageExpiration) {
            data.messageExpiration = [UAUtils parseISO8601DateFromString:messageExpiration];
        } else {
            data.messageExpiration = nil;
        }
    }
}

- (BOOL)updateMessageWithDictionary:(NSDictionary *)dictionary context:(NSManagedObjectContext *)context {
    NSString *messageID = dictionary[@"message_id"];
    NSError *error = nil;

    if (!context || !messageID) {
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

- (UAInboxMessage *)addMessageFromDictionary:(NSDictionary *)dictionary context:(NSManagedObjectContext *)context {
    if (!context) {
        return nil;
    }

    UAInboxMessageData *data = (UAInboxMessageData *)[NSEntityDescription insertNewObjectForEntityForName:kUAInboxDBEntityName
                                                                                   inManagedObjectContext:context];

    dictionary = [dictionary dictionaryWithValuesForKeys:[[dictionary keysOfEntriesPassingTest:^BOOL(id key, id obj, BOOL *stop) {
        return ![obj isEqual:[NSNull null]];
    }] allObjects]];

    UAInboxMessage *message = [UAInboxMessage messageWithData:data];

    [self updateMessageData:message.data withDictionary:dictionary];

    [context save:nil];

    return message;
}

- (void)deleteMessages:(NSArray *)messages context:(NSManagedObjectContext *)context {
    if (!context) {
        return;
    }

    for (UAInboxMessage *message in messages) {
        if ([message isKindOfClass:[UAInboxMessage class]]) {
            UALOG(@"Deleting: %@", message.messageID);
            [context deleteObject:message.data];
        }
    }

    [context save:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
