/* Copyright 2017 Urban Airship and Contributors */

#import "UAEventData+Internal.h"
#import "NSJSONSerialization+UAAdditions.h"

#import "UAEventStore+Internal.h"
#import "NSManagedObjectContext+UAAdditions.h"
#import <CoreData/CoreData.h>
#import "UAConfig.h"
#import "UAEvent.h"
#import "UAirship.h"
#import "UASQLite+Internal.h"

NSString *const UAEventStoreFileFormat = @"Events-%@.sqlite";
NSString *const UAEventDataEntityName = @"UAEventData";

@interface UAEventStore ()
@property (nonatomic, strong) NSManagedObjectContext *managedContext;
@end

@implementation UAEventStore

- (instancetype)initWithConfig:(UAConfig *)config {
    self = [super init];

    if (self) {
        NSString *storeName = [NSString stringWithFormat:UAEventStoreFileFormat, config.appKey];
        NSURL *modelURL = [[UAirship resources] URLForResource:@"UAEvents" withExtension:@"momd"];
        self.managedContext = [NSManagedObjectContext managedObjectContextForModelURL:modelURL
                                                                     concurrencyType:NSPrivateQueueConcurrencyType
                                                                            storeName:storeName];
        [self migrateOldDatabase];
    }

    return self;
}

+ (instancetype)eventStoreWithConfig:(UAConfig *)config {
    return [[UAEventStore alloc] initWithConfig:config];
}

- (BOOL)saveContext {
    NSError *error;
    [self.managedContext save:&error];
    [self.managedContext reset];
    if (error) {
        UA_LERR(@"Error saving context %@", error);
        return NO;
    }
    return YES;
}

- (void)saveEvent:(UAEvent *)event sessionID:(NSString *)sessionID {
    [self.managedContext performBlock:^{
        [self storeEventWithID:event.eventID
                     eventType:event.eventType
                     eventTime:event.time
                     eventBody:event.data
                     sessionID:sessionID];

        [self saveContext];
    }];
}

- (void)fetchEventsWithMaxBatchSize:(NSUInteger)maxBatchSize
                  completionHandler:(void (^)(NSArray<UAEventData *> *))completionHandler {


    [self.managedContext performBlock:^{

        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:UAEventDataEntityName];
        request.sortDescriptors = @[ [NSSortDescriptor sortDescriptorWithKey:@"storeDate" ascending:NO] ];

        NSError *error;
        NSArray *result = [self.managedContext executeFetchRequest:request error:&error];

        if (error) {
            UA_LERR(@"Error fetching events %@", error);
            completionHandler(@[]);
        } else {
            completionHandler(result);
            [self saveContext];
        }
    }];
}

- (void)deleteEventsWithIDs:(NSArray<NSString *> *)eventIDs {
    [self.managedContext performBlock:^{
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:UAEventDataEntityName];
        request.predicate = [NSPredicate predicateWithFormat:@"identifier IN %@", eventIDs];

        NSError *error;

        if ([[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){9, 0, 0}]) {
            NSBatchDeleteRequest *deleteRequest = [[NSBatchDeleteRequest alloc] initWithFetchRequest:request];
            [self.managedContext executeRequest:deleteRequest error:&error];
        } else {
            request.includesPropertyValues = NO;
            NSArray *events = [self.managedContext executeFetchRequest:request error:&error];
            for (NSManagedObject *event in events) {
                [self.managedContext deleteObject:event];
            }
        }

        if (error) {
            UA_LERR(@"Error deleting analytics events %@", error);
            return;
        }

        [self saveContext];
    }];
}

- (void)deleteAllEvents {
    [self.managedContext performBlock:^{
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:UAEventDataEntityName];

        NSError *error;

        if ([[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){9, 0, 0}]) {
            NSBatchDeleteRequest *deleteRequest = [[NSBatchDeleteRequest alloc] initWithFetchRequest:request];
            [self.managedContext executeRequest:deleteRequest error:&error];
        } else {
            request.includesPropertyValues = NO;
            NSArray *events = [self.managedContext executeFetchRequest:request error:&error];
            for (NSManagedObject *event in events) {
                [self.managedContext deleteObject:event];
            }
        }

        if (error) {
            UA_LERR(@"Error deleting analytics events %@", error);
            return;
        }

        [self saveContext];
    }];
}

- (void)trimEventsToStoreSize:(NSUInteger)maxSize {
    [self.managedContext performBlock:^{

        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:UAEventDataEntityName];
        request.sortDescriptors = @[ [NSSortDescriptor sortDescriptorWithKey:@"storeDate" ascending:NO] ];
        request.predicate = [NSPredicate predicateWithFormat:@"@sum.bytes >= %ld", (unsigned long)maxSize];

        NSBatchDeleteRequest *deleteRequest = [[NSBatchDeleteRequest alloc] initWithFetchRequest:request];

        NSError *error;
        [self.managedContext executeRequest:deleteRequest error:&error];
        if (error) {
            UA_LERR(@"Error trimming analytic event store %@", error);
            return;
        }

        [self saveContext];
    }];
}

- (void)migrateOldDatabase {

    [self.managedContext performBlock:^{

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

        UA_LDEBUG(@"Migrating old analytic store.");

        NSArray *events = nil;
        do {
            // (type, event_id, time, data, session_id, event_size)
            events = [db executeQuery:@"SELECT * FROM analytics ORDER BY _id LIMIT ?", [NSNumber numberWithUnsignedInteger:200]];
            if (!events.count) {
                break;
            }

            // delete begin
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

            // delete commit
            [db commit];

            
        } while (events.count);

        [db close];
        [[NSFileManager defaultManager] removeItemAtPath:writableDBPath error:nil];

        [self saveContext];
    }];
}

- (void)storeEventWithID:(NSString *)eventID eventType:(NSString *)eventType eventTime:(NSString *)eventTime eventBody:(id)eventBody sessionID:(NSString *)sessionID {
    NSError *error;
    id json = [NSJSONSerialization dataWithJSONObject:eventBody options:0 error:&error];
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
