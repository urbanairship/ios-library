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

#import <CoreData/CoreData.h>

#import "UAInboxDBManager+Internal.h"
#import "UAConfig.h"
#import "UAUtils.h"
#import "UAInboxMessage+Internal.h"
#import "UAInboxMessageData+Internal.h"


@interface UAInboxDBManager()
@property (nonatomic, copy) NSString *storeName;
@end

@implementation UAInboxDBManager

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
    @synchronized(self) {
        if (!_mainContext) {
            NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
            if (coordinator) {
                _mainContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
                [_mainContext setPersistentStoreCoordinator:coordinator];

                [[NSNotificationCenter defaultCenter] addObserver:self
                                                         selector:@selector(mainContextDidSave:)
                                                             name:NSManagedObjectContextDidSaveNotification
                                                           object:_mainContext];
            }
        }
        return _mainContext;
    }
}

- (NSManagedObjectContext *)privateContext {
    @synchronized(self) {
        if (!_privateContext) {
            NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
            if (coordinator) {
                _privateContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
                [_privateContext setPersistentStoreCoordinator:coordinator];

                [[NSNotificationCenter defaultCenter] addObserver:self
                                                         selector:@selector(privateContextDidSave:)
                                                             name:NSManagedObjectContextDidSaveNotification
                                                           object:_privateContext];
            }
        }
        return _privateContext;
    }
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
    @synchronized(self)  {
        if (_managedObjectModel) {
            return _managedObjectModel;
        }

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

        return _managedObjectModel;
    }
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
        NSURL *directoryURL = [libraryDirectoryURL URLByAppendingPathComponent:kUACoreDataStoreName];

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
        data.messageSent = [[UAUtils ISODateFormatterUTC] dateFromString:dict[@"message_sent"]];
        data.rawMessageObject = dict;

        NSString *messageExpiration = dict[@"message_expiry"];
        if (messageExpiration) {
            data.messageExpiration = [[UAUtils ISODateFormatterUTC] dateFromString:messageExpiration];
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
