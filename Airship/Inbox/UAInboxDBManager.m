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
#import "UAInboxMessage.h"
#import "UAUtils.h"
#import "NSJSONSerialization+UAAdditions.h"
#import <CoreData/CoreData.h>

@interface UAInboxDBManager()
@property(nonatomic, strong)NSURL *storeURL;
@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, strong) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, strong) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@end

@implementation UAInboxDBManager

SINGLETON_IMPLEMENTATION(UAInboxDBManager)

- (id)init {
    self = [super init];
    if (self) {
        NSURL *libraryDirectoryURL = [[[NSFileManager defaultManager] URLsForDirectory:NSLibraryDirectory
                                                                            inDomains:NSUserDomainMask] lastObject]; 

        self.storeURL = [libraryDirectoryURL URLByAppendingPathComponent:CORE_DATA_STORE_NAME];
    }
    return self;
}

- (NSMutableArray *)getMessagesForUser:(NSString *)userID app:(NSString *)appKey {
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"UAInboxMessage" inManagedObjectContext:self.managedObjectContext];
    [request setEntity:entity];


    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"appKey == %@ AND userID == %@", appKey, userID];
    [request setPredicate:predicate];

    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"messageSent" ascending:NO];
    NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];
    [request setSortDescriptors:sortDescriptors];

    NSError *error = nil;
    NSMutableArray *mutableFetchResults = [[self.managedObjectContext executeFetchRequest:request error:&error] mutableCopy];
    if (mutableFetchResults == nil) {
        // Handle the error.
        UALOG(@"No results!");
    }

    return mutableFetchResults ?: [NSMutableArray array];
}

- (UAInboxMessage *)addMessageFromDict:(NSDictionary *)dict forUser:(NSString *)userID app:(NSString *)appKey {
    UAInboxMessage *message = (UAInboxMessage *)[NSEntityDescription insertNewObjectForEntityForName:@"UAInboxMessage" inManagedObjectContext:self.managedObjectContext];


    dict = [dict dictionaryWithValuesForKeys:[[dict keysOfEntriesPassingTest:^BOOL(id key, id obj, BOOL *stop) {
        return ![obj isEqual:[NSNull null]];
    }] allObjects]];

    [self updateUAInboxMessage:message withDictionary:dict];
    message.appKey = appKey;
    message.userID = userID;

    [self saveContext];
    
    return message;
}

-(BOOL)updateMessageFromDict:(NSDictionary *)dict forUser:(NSString *)userID app:(NSString *)appKey{
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"UAInboxMessage" inManagedObjectContext:self.managedObjectContext];
    [request setEntity:entity];


    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"appKey == %@ AND userID == %@ AND messageID == %@", appKey, userID, [dict objectForKey: @"message_id"]];
    [request setPredicate:predicate];

    NSError *error = nil;
    NSMutableArray *mutableFetchResults = [[self.managedObjectContext executeFetchRequest:request error:&error] mutableCopy];
    if (!mutableFetchResults || !mutableFetchResults.count) {
        return NO;
    }

    UAInboxMessage *message = (UAInboxMessage *)[mutableFetchResults lastObject];
    [self updateUAInboxMessage:message withDictionary:dict];
    return YES;
}

- (void)deleteMessages:(NSArray *)messages {
    for (UAInboxMessage *persistedMessageToDelete in messages) {
        UALOG(@"Deleting: %@",persistedMessageToDelete.messageID);
        [self.managedObjectContext deleteObject:persistedMessageToDelete];
    }

    [self saveContext];
}

- (void)saveContext {
    NSError *error = nil;
    NSManagedObjectContext *context = self.managedObjectContext;
    if (context) {
        UALOG(@"Saving inbox changes");

        if ([context hasChanges] && ![context save:&error]) {
            UA_LERR(@"Unresolved error %@, %@", error, [error userInfo]);
        }
    }
}


/**
 Returns the managed object context for the application.
 If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
 */
- (NSManagedObjectContext *)managedObjectContext {
    if (_managedObjectContext) {
        return _managedObjectContext;
    }

    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        _managedObjectContext = [[NSManagedObjectContext alloc] init];
        [_managedObjectContext setPersistentStoreCoordinator:coordinator];
    }
    return _managedObjectContext;
}

/**
 Returns the managed object model for the application.
 If the model doesn't already exist, it is created from the application's model.
 */
- (NSManagedObjectModel *)managedObjectModel {
    if (_managedObjectModel) {
        return _managedObjectModel;
    }

    _managedObjectModel = [[NSManagedObjectModel alloc] init];
    NSEntityDescription *inboxEntity = [[NSEntityDescription alloc] init];
    [inboxEntity setName:@"UAInboxMessage"];
    [inboxEntity setManagedObjectClassName:@"UAInboxMessage"];
    [_managedObjectModel setEntities:@[inboxEntity]];

    NSMutableArray *inboxProperties = [NSMutableArray array];
    [inboxProperties addObject:[self createAttributeDescription:@"appKey" withType:NSStringAttributeType setOptional:true]];
    [inboxProperties addObject:[self createAttributeDescription:@"messageBodyURL" withType:NSTransformableAttributeType setOptional:true]];
    [inboxProperties addObject:[self createAttributeDescription:@"messageID" withType:NSStringAttributeType setOptional:true]];
    [inboxProperties addObject:[self createAttributeDescription:@"messageSent" withType:NSDateAttributeType setOptional:true]];
    [inboxProperties addObject:[self createAttributeDescription:@"title" withType:NSStringAttributeType setOptional:true]];
    [inboxProperties addObject:[self createAttributeDescription:@"unread" withType:NSBooleanAttributeType setOptional:true]];
    [inboxProperties addObject:[self createAttributeDescription:@"messageURL" withType:NSTransformableAttributeType setOptional:true]];
    [inboxProperties addObject:[self createAttributeDescription:@"userID" withType:NSStringAttributeType setOptional:true]];

    NSAttributeDescription *extraDescription = [self createAttributeDescription:@"extra" withType:NSTransformableAttributeType setOptional:true];
    [extraDescription setValueTransformerName:@"UAJSONValueTransformer"];
    [inboxProperties addObject:extraDescription];

    [inboxEntity setProperties:inboxProperties];

    return _managedObjectModel;
}

- (NSAttributeDescription *) createAttributeDescription:(NSString *)name
                                               withType:(NSAttributeType)attributeType
                                            setOptional:(BOOL)isOptional {

    NSAttributeDescription *attribute= [[NSAttributeDescription alloc] init];
    [attribute setName:name];
    [attribute setAttributeType:attributeType];
    [attribute setOptional:isOptional];

    return attribute;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    if (_persistentStoreCoordinator) {
        return _persistentStoreCoordinator;
    }
    
    NSError *error = nil;
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:self.managedObjectModel];
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:self.storeURL options:nil error:&error]) {

        UA_LERR(@"Error adding persistent store: %@, %@", error, [error userInfo]);
        
        [[NSFileManager defaultManager] removeItemAtURL:self.storeURL error:nil];
        [_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:self.storeURL options:nil error:&error];
    }

    return _persistentStoreCoordinator;
}

- (void)updateUAInboxMessage:(UAInboxMessage *)message withDictionary:(NSDictionary *)dict {
    message.messageID = [dict objectForKey: @"message_id"];
    message.contentType = [dict objectForKey:@"content_type"];
    message.title = [dict objectForKey: @"title"];
    message.extra = [dict objectForKey: @"extra"];
    message.messageBodyURL = [NSURL URLWithString: [dict objectForKey: @"message_body_url"]];
    message.messageURL = [NSURL URLWithString: [dict objectForKey: @"message_url"]];
    message.unread = [[dict objectForKey: @"unread"] boolValue];
    message.messageSent = [[UAUtils ISODateFormatterUTC] dateFromString:[dict objectForKey: @"message_sent"]];
}

@end
