/* Copyright Airship and Contributors */

#import "UAEventData+Internal.h"
#import "NSJSONSerialization+UAAdditions.h"
#import "UAEventStore+Internal.h"
#import "UACoreData.h"
#import "UARuntimeConfig.h"
#import "UAEvent.h"
#import "UAirship.h"
#import "UAJSONSerialization.h"
#import "UAirshipCoreResources.h"

NSString *const UAEventStoreFileFormat = @"Events-%@.sqlite";
NSString *const UAEventDataEntityName = @"UAEventData";

@interface UAEventStore ()
@property (nonatomic, strong) UACoreData *coreData;
@property (nonatomic, copy) NSString *storeName;

@end

@implementation UAEventStore

- (instancetype)initWithConfig:(UARuntimeConfig *)config {
    self = [super init];

    if (self) {
        NSString *storeName = [NSString stringWithFormat:UAEventStoreFileFormat, config.appKey];
        NSURL *modelURL = [[UAirshipCoreResources bundle] URLForResource:@"UAEvents" withExtension:@"momd"];
        self.coreData = [UACoreData coreDataWithModelURL:modelURL inMemory:NO stores:@[storeName]];
    }

    return self;
}

+ (instancetype)eventStoreWithConfig:(UARuntimeConfig *)config {
    return [[UAEventStore alloc] initWithConfig:config];
}

- (void)saveEvent:(UAEvent *)event sessionID:(NSString *)sessionID {
    [self.coreData safePerformBlock:^(BOOL isSafe, NSManagedObjectContext *context) {
        if (!isSafe) {
            UA_LERR(@"Unable to save event: %@. Persistent store unavailable", event);
            return;
        }

        [self storeEventWithID:event.eventID
                     eventType:event.eventType
                     eventTime:event.time
                     eventBody:event.data
                     sessionID:sessionID
                       context:context];

        [UACoreData safeSave:context];
    }];
}

- (void)fetchEventsWithLimit:(NSUInteger)limit
           completionHandler:(void (^)(NSArray<UAEventData *> *))completionHandler {


    [self.coreData safePerformBlock:^(BOOL isSafe, NSManagedObjectContext *context) {
        if (!isSafe) {
            completionHandler(@[]);
            return;
        }

        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:UAEventDataEntityName];
        request.fetchLimit = limit;
        request.sortDescriptors = @[ [NSSortDescriptor sortDescriptorWithKey:@"storeDate" ascending:YES] ];

        NSError *error;
        NSArray *result = [context executeFetchRequest:request error:&error];

        if (error) {
            UA_LERR(@"Error fetching events %@", error);
            completionHandler(@[]);
        } else {
            completionHandler(result);
            [UACoreData safeSave:context];
        }
    }];
}

- (void)deleteEventsWithIDs:(NSArray<NSString *> *)eventIDs {
    [self.coreData safePerformBlock:^(BOOL isSafe, NSManagedObjectContext *context) {
        if (!isSafe) {
            return;
        }

        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:UAEventDataEntityName];
        request.predicate = [NSPredicate predicateWithFormat:@"identifier IN %@", eventIDs];

        NSError *error;
        NSBatchDeleteRequest *deleteRequest = [[NSBatchDeleteRequest alloc] initWithFetchRequest:request];
        [context executeRequest:deleteRequest error:&error];

        if (error) {
            UA_LERR(@"Error deleting analytics events %@", error);
            return;
        }

        [UACoreData safeSave:context];
    }];
}

- (void)deleteAllEvents {
    [self.coreData performBlockIfStoresExist:^(BOOL isSafe, NSManagedObjectContext *context) {
        if (!isSafe) {
            return;
        }

        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:UAEventDataEntityName];

        NSError *error;
        NSBatchDeleteRequest *deleteRequest = [[NSBatchDeleteRequest alloc] initWithFetchRequest:request];
        [context executeRequest:deleteRequest error:&error];

        if (error) {
            UA_LERR(@"Error deleting analytics events %@", error);
            return;
        }

        [UACoreData safeSave:context];
    }];
}

- (void)trimEventsToStoreSize:(NSUInteger)maxSize {
    [self.coreData safePerformBlock:^(BOOL isSafe, NSManagedObjectContext *context) {
        if (!isSafe) {
            return;
        }

        while ([self fetchTotalEventSizeWithContext:context] > maxSize) {
            NSString *sessionID = [self fetchOldestSessionIDWithContext:context];
            if (!sessionID || ![self deleteSession:sessionID context:context]) {
                return;
            }
        }

        [UACoreData safeSave:context];
    }];
}

- (BOOL)deleteSession:(NSString *)sessionID context:(NSManagedObjectContext *)context {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:UAEventDataEntityName];
    request.predicate = [NSPredicate predicateWithFormat:@"sessionID == %@", sessionID];

    NSError *error;
    NSBatchDeleteRequest *deleteRequest = [[NSBatchDeleteRequest alloc] initWithFetchRequest:request];
    [context executeRequest:deleteRequest error:&error];

    if (error) {
        UA_LERR(@"Error deleting session %@", sessionID);
        return NO;
    }

    return YES;
}

- (NSString *)fetchOldestSessionIDWithContext:(NSManagedObjectContext *)context {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:UAEventDataEntityName];
    request.fetchLimit = 1;
    request.sortDescriptors = @[ [NSSortDescriptor sortDescriptorWithKey:@"storeDate" ascending:YES] ];
    request.propertiesToFetch = @[@"sessionID"];

    NSError *error;
    NSArray *result = [context executeFetchRequest:request error:&error];

    if (error || !result.count) {
        UA_LERR(@"Error fetching oldest sessionID %@", error);
        return nil;
    }

    return [result[0] sessionID];
}

- (NSUInteger)fetchTotalEventSizeWithContext:(NSManagedObjectContext *)context {
    NSExpressionDescription *sumDescription = [[NSExpressionDescription alloc] init];
    sumDescription.name = @"sum";
    sumDescription.expression = [NSExpression expressionForFunction:@"sum:"
                                                          arguments:@[[NSExpression expressionForKeyPath:@"bytes"]]];
    sumDescription.expressionResultType = NSDoubleAttributeType;

    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:UAEventDataEntityName];
    request.resultType = NSDictionaryResultType;
    request.propertiesToFetch = @[sumDescription];

    NSError *error = nil;
    NSArray *result = [context executeFetchRequest:request error:&error];
    if (error || !result.count) {
        UA_LERR(@"Error trimming analytic event store %@", error);
        return 0;
    }

    NSNumber *value = result[0][@"sum"];
    return value.unsignedIntegerValue;
}

- (void)storeEventWithID:(NSString *)eventID eventType:(NSString *)eventType eventTime:(NSString *)eventTime eventBody:(id)eventBody sessionID:(NSString *)sessionID context:(NSManagedObjectContext *)context {
    NSError *error;
    id json = [UAJSONSerialization dataWithJSONObject:eventBody options:0 error:&error];
    if (error) {
        UA_LERR(@"Unable to save event. %@", error);
        return;
    }

    UAEventData *eventData = [NSEntityDescription insertNewObjectForEntityForName:UAEventDataEntityName
                                                           inManagedObjectContext:context];

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
