/* Copyright 2017 Urban Airship and Contributors */

#import <CoreData/CoreData.h>

#import "UAInboxDBManager+Internal.h"
#import "UAConfig.h"
#import "UAUtils.h"
#import "UAInboxMessage+Internal.h"
#import "UAInboxMessageData+Internal.h"


@interface UAInboxDBManager()
@property (nonatomic, copy) NSString *storeName;
@end

@implementation UAInboxDBManager {
    dispatch_once_t _mainContextOnce;
    dispatch_once_t _privateContextOnce;
    dispatch_once_t _managedObjectModelOnce;
}

@synthesize mainContext = _mainContext;
@synthesize privateContext = _privateContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;
@synthesize storeURL = _storeURL;

- (instancetype)initWithConfig:(UAConfig *)config {
    self = [super init];
    if (self) {
        self.storeName = [NSString stringWithFormat:kUACoreDataStoreName, config.appKey];
    }

    return self;
}



- (NSManagedObjectContext *)mainContext {
    dispatch_once(&_mainContextOnce, ^{
        NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
        if (coordinator) {
            _mainContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
            [_mainContext setPersistentStoreCoordinator:coordinator];

            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(mainContextDidSave:)
                                                         name:NSManagedObjectContextDidSaveNotification
                                                       object:_mainContext];
        }

    });
    return _mainContext;
}

- (NSManagedObjectContext *)privateContext {
    dispatch_once(&_privateContextOnce, ^{
        NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
        if (coordinator) {
            _privateContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
            [_privateContext setPersistentStoreCoordinator:coordinator];

            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(privateContextDidSave:)
                                                         name:NSManagedObjectContextDidSaveNotification
                                                       object:_privateContext];
        }
    });
    return _privateContext;
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
/**
 Returns the managed object model for the application.
 If the model doesn't already exist, it is created from the application's model.
 */
- (NSManagedObjectModel *)managedObjectModel {
    dispatch_once(&_managedObjectModelOnce, ^{
        _managedObjectModel = [[NSManagedObjectModel alloc] init];
        NSEntityDescription *inboxEntity = [[NSEntityDescription alloc] init];
        [inboxEntity setName:kUAInboxDBEntityName];

        // Note: the class name does not need to be the same as the entity name, but maintaining a consistent
        // entity name is necessary in order to smoothly migrate if the class name changes
        [inboxEntity setManagedObjectClassName:@"UAInboxMessageData"];
        [_managedObjectModel setEntities:@[inboxEntity]];

        NSMutableArray *inboxProperties = [NSMutableArray array];
        [inboxProperties addObject:[self createAttributeDescription:@"messageBodyURL" withType:NSTransformableAttributeType setOptional:true]];
        [inboxProperties addObject:[self createAttributeDescription:@"messageID" withType:NSStringAttributeType setOptional:true]];
        [inboxProperties addObject:[self createAttributeDescription:@"messageSent" withType:NSDateAttributeType setOptional:true]];
        [inboxProperties addObject:[self createAttributeDescription:@"title" withType:NSStringAttributeType setOptional:true]];
        [inboxProperties addObject:[self createAttributeDescription:@"unread" withType:NSBooleanAttributeType setOptional:true]];
        [inboxProperties addObject:[self createAttributeDescription:@"unreadClient" withType:NSBooleanAttributeType setOptional:true defaultValue:@YES]];
        [inboxProperties addObject:[self createAttributeDescription:@"deletedClient" withType:NSBooleanAttributeType setOptional:true]];
        [inboxProperties addObject:[self createAttributeDescription:@"messageURL" withType:NSTransformableAttributeType setOptional:true]];
        [inboxProperties addObject:[self createAttributeDescription:@"messageExpiration" withType:NSDateAttributeType setOptional:true]];


        NSAttributeDescription *extraDescription = [self createAttributeDescription:@"extra" withType:NSTransformableAttributeType setOptional:true];
        [extraDescription setValueTransformerName:@"UAJSONValueTransformer"];
        [inboxProperties addObject:extraDescription];

        NSAttributeDescription *rawMessageObjectDescription = [self createAttributeDescription:@"rawMessageObject" withType:NSTransformableAttributeType setOptional:true];
        [extraDescription setValueTransformerName:@"UAJSONValueTransformer"];
        [inboxProperties addObject:rawMessageObjectDescription];

        [inboxEntity setProperties:inboxProperties];

    });

    return _managedObjectModel;
}

- (NSAttributeDescription *)createAttributeDescription:(NSString *)name
                                              withType:(NSAttributeType)attributeType
                                           setOptional:(BOOL)isOptional {

    return [self createAttributeDescription:name withType:attributeType setOptional:isOptional defaultValue:nil];
}

- (NSAttributeDescription *)createAttributeDescription:(NSString *)name
                                              withType:(NSAttributeType)attributeType
                                           setOptional:(BOOL)isOptional
                                          defaultValue:(id)defaultValue {

    NSAttributeDescription *attribute= [[NSAttributeDescription alloc] init];
    [attribute setName:name];
    [attribute setAttributeType:attributeType];
    [attribute setOptional:isOptional];
    [attribute setDefaultValue:defaultValue];

    return attribute;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    if (!_persistentStoreCoordinator) {
        NSError *error = nil;
        _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:self.managedObjectModel];
        if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:self.storeURL options:nil error:&error]) {

            UA_LERR(@"Error adding persistent store: %@, %@", error, [error userInfo]);

            [[NSFileManager defaultManager] removeItemAtURL:self.storeURL error:nil];
            [_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:self.storeURL options:nil error:nil];
        }
    }

    return _persistentStoreCoordinator;
}

- (NSURL *)storeURL {
    if (!_storeURL) {
        NSFileManager *fm = [NSFileManager defaultManager];
        NSURL *libraryDirectoryURL = [[fm URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask] lastObject];
        NSURL *directoryURL = [libraryDirectoryURL URLByAppendingPathComponent:self.storeName];

        NSURL *legacyURL = [libraryDirectoryURL URLByAppendingPathComponent:kUACoreDataStoreName];

        // Move the legacy directory to current directory if it exists
        if ([fm fileExistsAtPath:[legacyURL path]]) {
            NSError *error = nil;
            if (![fm moveItemAtURL:legacyURL toURL:directoryURL error:&error]) {
                UA_LERR(@"Error moving legacy inbox directory %@ to current directory %@: %@", [legacyURL lastPathComponent], [directoryURL lastPathComponent], error);
            }
        }

        // Create the store directory if it doesnt exist
        if (![fm fileExistsAtPath:[directoryURL path]]) {
            NSError *error = nil;
            if (![fm createDirectoryAtURL:directoryURL withIntermediateDirectories:YES attributes:nil error:&error]) {
                UA_LERR(@"Error creating inbox directory %@: %@", [directoryURL lastPathComponent], error);
            } else {
                [UAUtils addSkipBackupAttributeToItemAtURL:directoryURL];
            }
        }

        _storeURL = [directoryURL URLByAppendingPathComponent:self.storeName];
    }

    return _storeURL;
}

- (void)fetchMessagesWithPredicate:(NSPredicate *)predicate
                           context:(NSManagedObjectContext *)context
                 completionHandler:(void(^)(NSArray *messages))completionHandler {

    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    request.entity = [NSEntityDescription entityForName:kUAInboxDBEntityName
                                 inManagedObjectContext:context];

    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"messageSent" ascending:NO];
    request.sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];
    request.predicate = predicate;

    [context performBlock:^{
        NSArray *resultData = [context executeFetchRequest:request error:nil];

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

    if (!messageID) {
        UA_LDEBUG(@"Missing message ID: %@", dictionary);
        return NO;
    }

    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    request.entity = [NSEntityDescription entityForName:kUAInboxDBEntityName
                                 inManagedObjectContext:context];
    request.predicate = [NSPredicate predicateWithFormat:@"messageID == %@", messageID];
    request.fetchLimit = 1;

    NSArray *resultData = [context executeFetchRequest:request error:nil];

    UAInboxMessageData *data;
    if (resultData.count) {
        data = [resultData lastObject];
        [self updateMessageData:data withDictionary:dictionary];
        return YES;
    }

    return NO;
}

- (UAInboxMessage *)addMessageFromDictionary:(NSDictionary *)dictionary context:(NSManagedObjectContext *)context {
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
