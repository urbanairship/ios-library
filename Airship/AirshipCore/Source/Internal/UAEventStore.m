/* Copyright Airship and Contributors */

#import "UAEventData+Internal.h"
#import "NSJSONSerialization+UAAdditions.h"

#import "UAEventStore+Internal.h"
#import "NSManagedObjectContext+UAAdditions.h"
#import <CoreData/CoreData.h>
#import "UARuntimeConfig.h"
#import "UAEvent.h"
#import "UAirship.h"
#import "UASQLite+Internal.h"
#import "UAJSONSerialization.h"
#import "UAirshipCoreResources.h"

NSString *const UAEventStoreFileFormat = @"Events-%@.sqlite";
NSString *const UAEventDataEntityName = @"UAEventData";

@interface UAEventStore ()
@property (nonatomic, strong) NSManagedObjectContext *managedContext;
@property (nonatomic, copy) NSString *storeName;

@end

@implementation UAEventStore

- (instancetype)initWithConfig:(UARuntimeConfig *)config {
    self = [super init];

    if (self) {
        self.storeName = [NSString stringWithFormat:UAEventStoreFileFormat, config.appKey];
        NSURL *modelURL = [[UAirshipCoreResources bundle] URLForResource:@"UAEvents" withExtension:@"momd"];
        self.managedContext = [NSManagedObjectContext managedObjectContextForModelURL:modelURL
                                                                      concurrencyType:NSPrivateQueueConcurrencyType];

        [self addPersistentStore];
    }

    return self;
}

+ (instancetype)eventStoreWithConfig:(UARuntimeConfig *)config {
    return [[UAEventStore alloc] initWithConfig:config];
}

- (void)addPersistentStore {
    UA_WEAKIFY(self);
    [self.managedContext addPersistentSqlStore:self.storeName completionHandler:^(NSPersistentStore *store, NSError *error) {
        UA_STRONGIFY(self)
        if (!store) {
            UA_LERR(@"Failed to create analytics persistent store: %@", error);
            return;
        }

        [self migrateOldDatabase];
    }];

}
- (void)protectedDataAvailable {
    if (!self.managedContext.persistentStoreCoordinator.persistentStores.count) {
        [self addPersistentStore];
    }
}

- (void)saveEvent:(UAEvent *)event sessionID:(NSString *)sessionID {
    [self.managedContext safePerformBlock:^(BOOL isSafe) {
        if (!isSafe) {
            UA_LERR(@"Unable to save event: %@. Persistent store unavailable", event);
            return;
        }

        [self storeEventWithID:event.eventID
                     eventType:event.eventType
                     eventTime:event.time
                     eventBody:event.data
                     sessionID:sessionID];

        [self.managedContext safeSave];
    }];
}

- (void)fetchEventsWithLimit:(NSUInteger)limit
           completionHandler:(void (^)(NSArray<UAEventData *> *))completionHandler {


    [self.managedContext safePerformBlock:^(BOOL isSafe) {
        if (!isSafe) {
            completionHandler(@[]);
            return;
        }

        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:UAEventDataEntityName];
        request.fetchLimit = limit;
        request.sortDescriptors = @[ [NSSortDescriptor sortDescriptorWithKey:@"storeDate" ascending:YES] ];

        NSError *error;
        NSArray *result = [self.managedContext executeFetchRequest:request error:&error];

        if (error) {
            UA_LERR(@"Error fetching events %@", error);
            completionHandler(@[]);
        } else {
            completionHandler(result);
            [self.managedContext safeSave];
        }
    }];
}

- (void)deleteEventsWithIDs:(NSArray<NSString *> *)eventIDs {
    [self.managedContext safePerformBlock:^(BOOL isSafe) {
        if (!isSafe) {
            return;
        }

        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:UAEventDataEntityName];
        request.predicate = [NSPredicate predicateWithFormat:@"identifier IN %@", eventIDs];

        NSError *error;
        NSBatchDeleteRequest *deleteRequest = [[NSBatchDeleteRequest alloc] initWithFetchRequest:request];
        [self.managedContext executeRequest:deleteRequest error:&error];

        if (error) {
            UA_LERR(@"Error deleting analytics events %@", error);
            return;
        }

        [self.managedContext safeSave];
    }];
}

- (void)deleteAllEvents {
    [self.managedContext safePerformBlock:^(BOOL isSafe) {
        if (!isSafe) {
            return;
        }

        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:UAEventDataEntityName];

        NSError *error;
        NSBatchDeleteRequest *deleteRequest = [[NSBatchDeleteRequest alloc] initWithFetchRequest:request];
        [self.managedContext executeRequest:deleteRequest error:&error];

        if (error) {
            UA_LERR(@"Error deleting analytics events %@", error);
            return;
        }

        [self.managedContext safeSave];
    }];
}

- (void)trimEventsToStoreSize:(NSUInteger)maxSize {
    [self.managedContext safePerformBlock:^(BOOL isSafe) {
        if (!isSafe) {
            return;
        }

        while ([self fetchTotalEventSize] > maxSize) {
            NSString *sessionID = [self fetchOldestSessionID];
            if (!sessionID || ![self deleteSession:sessionID]) {
                return;
            }
        }

        [self.managedContext safeSave];
    }];
}

- (BOOL)deleteSession:(NSString *)sessionID {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:UAEventDataEntityName];
    request.predicate = [NSPredicate predicateWithFormat:@"sessionID == %@", sessionID];

    NSError *error;
    NSBatchDeleteRequest *deleteRequest = [[NSBatchDeleteRequest alloc] initWithFetchRequest:request];
    [self.managedContext executeRequest:deleteRequest error:&error];

    if (error) {
        UA_LERR(@"Error deleting session %@", sessionID);
        return NO;
    }

    return YES;
}

- (NSString *)fetchOldestSessionID {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:UAEventDataEntityName];
    request.fetchLimit = 1;
    request.sortDescriptors = @[ [NSSortDescriptor sortDescriptorWithKey:@"storeDate" ascending:YES] ];
    request.propertiesToFetch = @[@"sessionID"];

    NSError *error;
    NSArray *result = [self.managedContext executeFetchRequest:request error:&error];

    if (error || !result.count) {
        UA_LERR(@"Error fetching oldest sessionID %@", error);
        return nil;
    }

    return [result[0] sessionID];
}

- (NSUInteger)fetchTotalEventSize {
    NSExpressionDescription *sumDescription = [[NSExpressionDescription alloc] init];
    sumDescription.name = @"sum";
    sumDescription.expression = [NSExpression expressionForFunction:@"sum:"
                                                          arguments:@[[NSExpression expressionForKeyPath:@"bytes"]]];
    sumDescription.expressionResultType = NSDoubleAttributeType;

    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:UAEventDataEntityName];
    request.resultType = NSDictionaryResultType;
    request.propertiesToFetch = @[sumDescription];

    NSError *error = nil;
    NSArray *result = [self.managedContext executeFetchRequest:request error:&error];
    if (error || !result.count) {
        UA_LERR(@"Error trimming analytic event store %@", error);
        return 0;
    }

    NSNumber *value = result[0][@"sum"];
    return value.unsignedIntegerValue;
}

- (void)migrateOldDatabase {
    NSString *libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
    NSString *writableDBPath = [libraryPath stringByAppendingPathComponent:@"UAAnalyticsDB"];

    if (![[NSFileManager defaultManager] fileExistsAtPath:writableDBPath]) {
        return;
    }

    UASQLite *db = [[UASQLite alloc] initWithDBPath:writableDBPath];
    if (![db tableExists:@"analytics"]) {
        [db close];
        [[NSFileManager defaultManager] removeItemAtPath:writableDBPath error:nil];
        return;
    }

    UA_LTRACE(@"Migrating old analytic store.");

    NSArray *events = nil;
    do {
        // (type, event_id, time, data, session_id, event_size)
        events = [db executeQuery:@"SELECT * FROM analytics ORDER BY _id LIMIT ?", [NSNumber numberWithUnsignedInteger:200]];
        if (!events.count) {
            break;
        }

        // begin delete
        [db beginTransaction];

        for (id event in events) {
            NSError *error = nil;
            id data = [NSPropertyListSerialization
                       propertyListWithData:event[@"data"]
                       options:NSPropertyListMutableContainersAndLeaves
                       format:NULL
                       error:&error];

            if (error) {
                UA_LERR(@"Unable to migrate event. %@", error);
                continue;
            }

            [self storeEventWithID:event[@"event_id"]
                         eventType:event[@"type"]
                         eventTime:event[@"time"]
                         eventBody:data
                         sessionID:event[@"session_id"]];

            // delete
            [db executeUpdate:@"DELETE FROM analytics WHERE event_id = ?", [event objectForKey:@"event_id"]];
        }

        // commit delete
        [db commit];


    } while (events.count);

    [db close];
    [[NSFileManager defaultManager] removeItemAtPath:writableDBPath error:nil];

    [self.managedContext safeSave];
}

- (void)storeEventWithID:(NSString *)eventID eventType:(NSString *)eventType eventTime:(NSString *)eventTime eventBody:(id)eventBody sessionID:(NSString *)sessionID {
    NSError *error;
    id json = [UAJSONSerialization dataWithJSONObject:eventBody options:0 error:&error];
    if (error) {
        UA_LERR(@"Unable to save event. %@", error);
        return;
    }

    UAEventData *eventData = [NSEntityDescription insertNewObjectForEntityForName:UAEventDataEntityName
                                                           inManagedObjectContext:self.managedContext];

    eventData.sessionID = sessionID;
    eventData.type = eventType;
    eventData.time = eventTime;
    eventData.identifier = eventID;
    eventData.data = json;
    eventData.storeDate = [NSDate date];

    // Approximate size
    eventData.bytes = @(eventData.sessionID.length + eventData.type.length + eventData.time.length + eventData.identifier.length + eventData.data.length);

    UA_LTRACE(@"Event saved: %@", eventID);
}

@end
