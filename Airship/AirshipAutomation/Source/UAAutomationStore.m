/* Copyright Airship and Contributors */

#import "UAAutomationStore+Internal.h"
#import "UAScheduleData+Internal.h"
#import "UAScheduleTriggerData+Internal.h"
#import "UAScheduleDelayData+Internal.h"
#import "UASchedule.h"
#import "UASchedule+Internal.h"
#import "UAScheduleTrigger+Internal.h"
#import "UAScheduleDataMigrator+Internal.h"
#import "UAAirshipAutomationCoreImport.h"
#import "UAScheduleTriggerContext+Internal.h"
#import "UAScheduleAudience+Internal.h"
#import "UAAutomationResources.h"

NSString *const UAInAppAutomationStoreFileFormat = @"In-app-automation-%@.sqlite";
NSString *const UALegacyActionAutomationStoreFileFormat = @"Automation-%@.sqlite";

@interface UAAutomationStore ()
@property (nonatomic, strong) NSManagedObjectContext *managedContext;
@property (nonatomic, strong) NSPersistentStore *mainStore;
@property (nonatomic, copy) NSString *storeName;
@property (nonatomic, copy) NSString *legacyActionStoreName;

@property (nonatomic, strong) UADate *date;
@property (nonatomic, assign) NSUInteger scheduleLimit;
@property (nonatomic, assign) BOOL inMemory;
@property (nonatomic, assign) BOOL finished;
@end



@implementation UAAutomationStore

- (instancetype)initWithConfig:(UARuntimeConfig *)config
                 scheduleLimit:(NSUInteger)scheduleLimit
                      inMemory:(BOOL)inMemory date:(UADate *)date {

    self = [super init];

    if (self) {
        self.storeName = [NSString stringWithFormat:UAInAppAutomationStoreFileFormat, config.appKey];
        self.legacyActionStoreName = [NSString stringWithFormat:UALegacyActionAutomationStoreFileFormat, config.appKey];

        self.scheduleLimit = scheduleLimit;
        self.inMemory = inMemory;
        self.date = date;
        self.finished = NO;

        NSBundle *bundle = [UAAutomationResources bundle];
        NSURL *modelURL = [bundle URLForResource:@"UAAutomation" withExtension:@"momd"];

        self.managedContext = [NSManagedObjectContext managedObjectContextForModelURL:modelURL
                                                                      concurrencyType:NSPrivateQueueConcurrencyType];
        self.managedContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
        [self addStores];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(protectedDataAvailable)
                                                     name:UIApplicationProtectedDataDidBecomeAvailable
                                                   object:nil];
    }

    return self;
}

+ (instancetype)automationStoreWithConfig:(UARuntimeConfig *)config scheduleLimit:(NSUInteger)scheduleLimit inMemory:(BOOL)inMemory date:(UADate *)date {
    return [[UAAutomationStore alloc] initWithConfig:config
                                       scheduleLimit:scheduleLimit
                                            inMemory:inMemory
                                                date:date];
}

+ (instancetype)automationStoreWithConfig:(UARuntimeConfig *)config scheduleLimit:(NSUInteger)scheduleLimit {
    return [[UAAutomationStore alloc] initWithConfig:config
                                       scheduleLimit:scheduleLimit
                                            inMemory:NO
                                                date:[[UADate alloc] init]];
}

- (void)addStores {
    UA_WEAKIFY(self)
    void (^completion)(NSPersistentStore *, NSError *) = ^void(NSPersistentStore *store, NSError *error) {
        UA_STRONGIFY(self);

        if (!store) {
            UA_LERR(@"Failed to create automation persistent store: %@", error);
            return;
        }

        if (!self.mainStore) {
            self.mainStore = store;
        }

        if (!self.inMemory) {
            [self migrateData];
        }
    };

    if (self.inMemory) {
        [self.managedContext addPersistentInMemoryStore:self.storeName completionHandler:completion];
    } else {
        // Instead of trying to copy data from one store to the other, we are going to attach both stores
        // to the context, but only save new data on the primary store.
        [self.managedContext addPersistentSqlStore:self.storeName completionHandler:completion];
        [self.managedContext addPersistentSqlStore:self.legacyActionStoreName completionHandler:completion];
    }
}
- (void)protectedDataAvailable {
    if (!self.managedContext.persistentStoreCoordinator.persistentStores.count) {
        [self addStores];
    }
}

- (void)migrateData {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"UAScheduleData"];
    request.predicate = [NSPredicate predicateWithFormat:@"dataVersion < %d", UAScheduleDataVersion];
    NSError *error;
    NSArray *result = [self.managedContext executeFetchRequest:request error:&error];

    if (error) {
        UA_LERR(@"Error fetching schedules %@", error);
        return;
    }
    [UAScheduleDataMigrator migrateSchedules:result];
    [self.managedContext safeSave];
}

- (void)safePerformBlock:(void (^)(BOOL))block {
    @synchronized(self) {
        if (!self.finished) {
            [self.managedContext safePerformBlock:block];
        }
    }
}

#pragma mark -
#pragma mark Data Access

- (void)saveSchedule:(UASchedule *)schedule completionHandler:(void (^)(BOOL))completionHandler {
    [self safePerformBlock:^(BOOL isSafe) {
        if (!isSafe) {
            completionHandler(NO);
            return;
        }

        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"UAScheduleData"];
        NSUInteger count = [self.managedContext countForFetchRequest:request error:nil];
        if (count >= self.scheduleLimit) {
            UA_LERR(@"Max schedule limit reached. Unable to save new schedule.");
            completionHandler(NO);
            return;
        }

        [self addScheduleDataFromSchedule:schedule];

        completionHandler([self.managedContext safeSave]);
    }];
}

- (void)saveSchedules:(NSArray<UASchedule *> *)schedules completionHandler:(void (^)(BOOL))completionHandler {
    [self safePerformBlock:^(BOOL isSafe) {
        if (!isSafe) {
            completionHandler(NO);
            return;
        }

        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"UAScheduleData"];
        NSUInteger count = [self.managedContext countForFetchRequest:request error:nil];
        if (count + schedules.count > self.scheduleLimit) {
            UA_LERR(@"Max schedule limit reached. Unable to save new schedules.");
            completionHandler(NO);
            return;
        }
        
        // create managed object for each schedule
        for (UASchedule *schedule in schedules) {
            [self addScheduleDataFromSchedule:schedule];
        }
        
        completionHandler([self.managedContext safeSave]);
    }];
}

- (void)getSchedules:(NSString *)groupID completionHandler:(void (^)(NSArray<UAScheduleData *> *))completionHandler {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"group == %@", groupID];
    [self fetchSchedulesWithPredicate:predicate limit:self.scheduleLimit completionHandler:completionHandler];
}

- (void)getSchedules:(NSString *)groupID
                type:(UAScheduleType)scheduleType
   completionHandler:(void (^)(NSArray<UAScheduleData *> *))completionHandler {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"group == %@ && type == %@", groupID, @(scheduleType)];
    [self fetchSchedulesWithPredicate:predicate limit:self.scheduleLimit completionHandler:completionHandler];
}

- (void)getSchedules:(void (^)(NSArray<UAScheduleData *> *))completionHandler {
    [self fetchSchedulesWithPredicate:nil limit:self.scheduleLimit completionHandler:completionHandler];
}

- (void)getSchedulesWithStates:(NSArray *)state
             completionHandler:(void (^)(NSArray<UAScheduleData *> * _Nonnull))completionHandler {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"executionState IN %@", state];
    [self fetchSchedulesWithPredicate:predicate limit:self.scheduleLimit completionHandler:completionHandler];
}

- (void)getSchedulesWithType:(UAScheduleType)scheduleType
           completionHandler:(void (^)(NSArray<UAScheduleData *> *))completionHandler {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"type == %@", @(scheduleType)];
    [self fetchSchedulesWithPredicate:predicate limit:self.scheduleLimit completionHandler:completionHandler];
}

- (void)getSchedule:(NSString *)scheduleID
  completionHandler:(void (^)(UAScheduleData * _Nullable))completionHandler {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"identifier == %@", scheduleID];
    [self fetchSchedulesWithPredicate:predicate limit:1 completionHandler:^(NSArray<UAScheduleData *> *result) {
        completionHandler(result.firstObject);
    }];
}

- (void)getSchedule:(NSString *)scheduleID
               type:(UAScheduleType)scheduleType
  completionHandler:(void (^)(UAScheduleData * _Nullable))completionHandler {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"identifier == %@ && type == %@", scheduleID, @(scheduleType)];
    [self fetchSchedulesWithPredicate:predicate limit:1 completionHandler:^(NSArray<UAScheduleData *> *result) {
        completionHandler(result.firstObject);
    }];
}

- (void)getActiveExpiredSchedules:(void (^)(NSArray<UAScheduleData *> *))completionHandler {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"end <= %@ && executionState != %d", self.date.now, UAScheduleStateFinished];
    [self fetchSchedulesWithPredicate:predicate limit:self.scheduleLimit completionHandler:completionHandler];
}

- (void)getActiveTriggers:(NSString *)scheduleID
                     type:(UAScheduleTriggerType)triggerType
        completionHandler:(void (^)(NSArray<UAScheduleTriggerData *> *triggers))completionHandler {

    scheduleID = scheduleID ? : @"*";

    NSString *format = @"(schedule.identifier LIKE %@ AND type = %ld AND start <= %@) AND ((delay != nil AND schedule.executionState in %@) OR (delay == nil AND schedule.executionState == %d))";

    NSArray *cancelTriggerState = @[@(UAScheduleStateTimeDelayed), @(UAScheduleStateWaitingScheduleConditions), @(UAScheduleStatePreparingSchedule)];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:format, scheduleID, triggerType, self.date.now, cancelTriggerState, UAScheduleStateIdle];

    [self fetchTriggersWithPredicate:predicate completionHandler:completionHandler];
}

- (void)getScheduleCount:(void (^)(NSNumber *))completionHandler {
    [self safePerformBlock:^(BOOL isSafe) {
        if (!isSafe) {
            completionHandler(nil);
            return;
        }
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"UAScheduleData"];
        NSUInteger count = [self.managedContext countForFetchRequest:request error:nil];
        completionHandler(@(count));
    }];
}

- (void)fetchSchedulesWithPredicate:(NSPredicate *)predicate
                              limit:(NSUInteger)limit
                  completionHandler:(void (^)(NSArray<UAScheduleData *> *))completionHandler {
    [self safePerformBlock:^(BOOL isSafe) {
        if (!isSafe) {
            completionHandler(@[]);
            return;
        }

        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"UAScheduleData"];
        request.predicate = predicate;
        request.fetchLimit = limit;

        NSError *error;
        NSArray *result = [self.managedContext executeFetchRequest:request error:&error];

        if (error) {
            UA_LERR(@"Error fetching schedules %@", error);
            completionHandler(@[]);
        } else {
            completionHandler(result);
            [self.managedContext safeSave];
        }
    }];
}

- (void)fetchTriggersWithPredicate:(NSPredicate *)predicate completionHandler:(void (^)(NSArray<UAScheduleTriggerData *> *))completionHandler {
    [self safePerformBlock:^(BOOL isSafe) {
        if (!isSafe) {
            completionHandler(@[]);
            return;
        }

        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"UAScheduleTriggerData"];
        request.predicate = predicate;

        NSError *error;
        NSArray *result = [self.managedContext executeFetchRequest:request error:&error];
        if (error) {
            UA_LERR(@"Error fetching triggers %@", error);
            completionHandler(@[]);
        } else {
            completionHandler(result);
            [self.managedContext safeSave];
        }
    }];
}

- (id)insertNewEntityForName:(NSString *)name {
    id object = [NSEntityDescription insertNewObjectForEntityForName:name inManagedObjectContext:self.managedContext];

    if (self.mainStore) {
        [self.managedContext assignObject:object toPersistentStore:self.mainStore];
    }

    return object;
}

#pragma mark -
#pragma mark Converters

- (void)addScheduleDataFromSchedule:(UASchedule *)schedule {
    UAScheduleData *scheduleData = [self insertNewEntityForName:@"UAScheduleData"];

    scheduleData.identifier = schedule.identifier;
    scheduleData.limit = @(schedule.limit);
    scheduleData.data = schedule.dataJSONString;
    scheduleData.type = @(schedule.type);
    scheduleData.priority = [NSNumber numberWithInteger:schedule.priority];
    scheduleData.group = schedule.group;
    scheduleData.triggers = [self createTriggerDataFromTriggers:schedule.triggers scheduleStart:schedule.start schedule:scheduleData];
    scheduleData.start = schedule.start;
    scheduleData.end = schedule.end;
    scheduleData.interval = @(schedule.interval);
    scheduleData.editGracePeriod = @(schedule.editGracePeriod);
    scheduleData.dataVersion = @(UAScheduleDataVersion);
    scheduleData.metadata = [NSJSONSerialization stringWithObject:schedule.metadata];
    if (schedule.audience) {
        scheduleData.audience = [NSJSONSerialization stringWithObject:[schedule.audience toJSON]];
    }

    if (schedule.delay) {
        scheduleData.delay = [self createDelayDataFromDelay:schedule.delay scheduleStart:schedule.start schedule:scheduleData];
    }
}

- (UAScheduleDelayData *)createDelayDataFromDelay:(UAScheduleDelay *)delay scheduleStart:(NSDate *)scheduleStart schedule:(UAScheduleData *)schedule {
    UAScheduleDelayData *delayData = [self insertNewEntityForName:@"UAScheduleDelayData"];
    delayData.seconds = @(delay.seconds);
    delayData.appState = @(delay.appState);
    delayData.regionID = delay.regionID;
    if (delay.screens != nil) {
        NSData *screensData = [UAJSONSerialization dataWithJSONObject:delay.screens options:0 error:nil];
        if (screensData != nil) {
            delayData.screens = [[NSString alloc] initWithData:screensData encoding:NSUTF8StringEncoding];
        }
    }
    delayData.cancellationTriggers = [self createTriggerDataFromTriggers:delay.cancellationTriggers scheduleStart:scheduleStart schedule:schedule];

    return delayData;
}

- (NSSet<UAScheduleTriggerData *> *)createTriggerDataFromTriggers:(NSArray <UAScheduleTrigger *> *)triggers
                                                    scheduleStart:(NSDate *)scheduleStart
                                                         schedule:(UAScheduleData *)schedule {
    NSMutableSet *data = [NSMutableSet set];

    for (UAScheduleTrigger *trigger in triggers) {
        UAScheduleTriggerData *triggerData = [self createTriggerDataFromTrigger:trigger scheduleStart:scheduleStart schedule:schedule];
        [data addObject:triggerData];
    }

    return data;
}

- (UAScheduleTriggerData *)createTriggerDataFromTrigger:(UAScheduleTrigger *)trigger
                                          scheduleStart:(NSDate *)scheduleStart
                                               schedule:(UAScheduleData *)schedule {

    UAScheduleTriggerData *triggerData = [self insertNewEntityForName:@"UAScheduleTriggerData"];
    triggerData.type = @(trigger.type);
    triggerData.goal = trigger.goal;
    triggerData.start = scheduleStart;

    if (trigger.predicate) {
        triggerData.predicateData = [UAJSONSerialization dataWithJSONObject:trigger.predicate.payload options:0 error:nil];
    }

    triggerData.schedule = schedule;
    triggerData.delay = schedule.delay;

    return triggerData;
}

- (void)waitForIdle {
    [self.managedContext performBlockAndWait:^{}];
}

- (void)shutDown {
    @synchronized(self) {
        self.finished = YES;
    }
}


@end
