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

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif
static NSString *const UAInAppAutomationStoreFileFormat = @"In-app-automation-%@.sqlite";
static NSString *const UALegacyActionAutomationStoreFileFormat = @"Automation-%@.sqlite";

@interface UAAutomationStore () <UACoreDataDelegate>
@property (nonatomic, strong) UACoreData *coreData;
@property (nonatomic, strong) NSPersistentStore *mainStore;
@property (nonatomic, strong) UADate *date;
@property (nonatomic, assign) NSUInteger scheduleLimit;
@end

@implementation UAAutomationStore

- (instancetype)initWithConfig:(UARuntimeConfig *)config
                 scheduleLimit:(NSUInteger)scheduleLimit
                      inMemory:(BOOL)inMemory
                          date:(UADate *)date {

    self = [super init];

    if (self) {
        self.scheduleLimit = scheduleLimit;
        self.date = date;

        NSBundle *bundle = [UAAutomationResources bundle];
        NSURL *modelURL = [bundle URLForResource:@"UAAutomation" withExtension:@"momd"];
        NSString *storeName = [NSString stringWithFormat:UAInAppAutomationStoreFileFormat, config.appKey];
        NSString *legacyActionStoreName = [NSString stringWithFormat:UALegacyActionAutomationStoreFileFormat, config.appKey];

        self.coreData = [[UACoreData alloc] initWithModelURL:modelURL
                                                    inMemory:inMemory
                                                      stores:@[storeName, legacyActionStoreName]
                                                 mergePolicy:NSMergeByPropertyObjectTrumpMergePolicy];
        self.coreData.delegate = self;
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

- (void)persistentStoreCreated:(NSPersistentStore *)store
                          name:(NSString *)name
                       context:(NSManagedObjectContext *)context {
    if (!self.mainStore) {
        self.mainStore = store;
    }

    UA_LTRACE(@"Created automation persistent store: %@", store.URL);

    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"UAScheduleData"];
    request.predicate = [NSPredicate predicateWithFormat:@"dataVersion < %d", UAScheduleDataVersion];
    NSError *error;
    NSArray *result = [context executeFetchRequest:request error:&error];

    if (error) {
        UA_LERR(@"Error fetching schedules %@", error);
        return;
    }

    [UAScheduleDataMigrator migrateSchedules:result];
    [UACoreData safeSave:context];
}

#pragma mark -
#pragma mark Data Access

- (void)saveSchedule:(UASchedule *)schedule completionHandler:(void (^)(BOOL))completionHandler {
    [self.coreData safePerformBlock:^(BOOL isSafe, NSManagedObjectContext *context) {
        if (!isSafe) {
            completionHandler(NO);
            return;
        }

        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"UAScheduleData"];
        NSUInteger count = [context countForFetchRequest:request error:nil];
        if (count >= self.scheduleLimit) {
            UA_LERR(@"Max schedule limit reached. Unable to save new schedule.");
            completionHandler(NO);
            return;
        }

        [self addScheduleDataFromSchedule:schedule context:context];

        completionHandler([UACoreData safeSave:context]);
    }];
}

- (void)saveSchedules:(NSArray<UASchedule *> *)schedules completionHandler:(void (^)(BOOL))completionHandler {
    [self.coreData safePerformBlock:^(BOOL isSafe, NSManagedObjectContext *context) {
        if (!isSafe) {
            completionHandler(NO);
            return;
        }

        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"UAScheduleData"];
        NSUInteger count = [context countForFetchRequest:request error:nil];
        if (count + schedules.count > self.scheduleLimit) {
            UA_LERR(@"Max schedule limit reached. Unable to save new schedules.");
            completionHandler(NO);
            return;
        }

        // create managed object for each schedule
        for (UASchedule *schedule in schedules) {
            [self addScheduleDataFromSchedule:schedule context:context];
        }

        completionHandler([UACoreData safeSave:context]);
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
    [self.coreData safePerformBlock:^(BOOL isSafe, NSManagedObjectContext *context) {
        if (!isSafe) {
            completionHandler(nil);
            return;
        }
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"UAScheduleData"];
        NSUInteger count = [context countForFetchRequest:request error:nil];
        completionHandler(@(count));
    }];
}

- (void)fetchSchedulesWithPredicate:(NSPredicate *)predicate
                              limit:(NSUInteger)limit
                  completionHandler:(void (^)(NSArray<UAScheduleData *> *))completionHandler {
    [self.coreData safePerformBlock:^(BOOL isSafe, NSManagedObjectContext *context) {
        if (!isSafe) {
            completionHandler(@[]);
            return;
        }

        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"UAScheduleData"];
        request.predicate = predicate;
        request.fetchLimit = limit;

        NSError *error;
        NSArray *result = [context executeFetchRequest:request error:&error];

        if (error) {
            UA_LERR(@"Error fetching schedules %@", error);
            completionHandler(@[]);
        } else {
            completionHandler(result);
            [UACoreData safeSave:context];
        }
    }];
}

- (void)fetchTriggersWithPredicate:(NSPredicate *)predicate completionHandler:(void (^)(NSArray<UAScheduleTriggerData *> *))completionHandler {
    [self.coreData safePerformBlock:^(BOOL isSafe, NSManagedObjectContext *context) {
        if (!isSafe) {
            completionHandler(@[]);
            return;
        }

        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"UAScheduleTriggerData"];
        request.predicate = predicate;

        NSError *error;
        NSArray *result = [context executeFetchRequest:request error:&error];
        if (error) {
            UA_LERR(@"Error fetching triggers %@", error);
            completionHandler(@[]);
        } else {
            completionHandler(result);
            [UACoreData safeSave:context];
        }
    }];
}

- (id)insertNewEntityForName:(NSString *)name context:(NSManagedObjectContext *)context {
    id object = [NSEntityDescription insertNewObjectForEntityForName:name inManagedObjectContext:context];

    if (self.mainStore) {
        [context assignObject:object toPersistentStore:self.mainStore];
    }

    return object;
}

#pragma mark -
#pragma mark Converters

- (void)addScheduleDataFromSchedule:(UASchedule *)schedule context:(NSManagedObjectContext *)context {
    UAScheduleData *scheduleData = [self insertNewEntityForName:@"UAScheduleData" context:context];

    scheduleData.identifier = schedule.identifier;
    scheduleData.limit = @(schedule.limit);
    scheduleData.data = schedule.dataJSONString;
    scheduleData.type = @(schedule.type);
    scheduleData.priority = [NSNumber numberWithInteger:schedule.priority];
    scheduleData.group = schedule.group;
    scheduleData.triggers = [self createTriggerDataFromTriggers:schedule.triggers scheduleStart:schedule.start schedule:scheduleData context:context];
    scheduleData.start = schedule.start;
    scheduleData.end = schedule.end;
    scheduleData.interval = @(schedule.interval);
    scheduleData.editGracePeriod = @(schedule.editGracePeriod);
    scheduleData.dataVersion = @(UAScheduleDataVersion);
    scheduleData.metadata = [UAJSONUtils stringWithObject:schedule.metadata];
    scheduleData.campaigns = schedule.campaigns;
    scheduleData.reportingContext = schedule.reportingContext;
    scheduleData.frequencyConstraintIDs = schedule.frequencyConstraintIDs;

    if (schedule.audience) {
        scheduleData.audience = [UAJSONUtils stringWithObject:[schedule.audience toJSON]];
    }

    if (schedule.delay) {
        scheduleData.delay = [self createDelayDataFromDelay:schedule.delay scheduleStart:schedule.start schedule:scheduleData context:context];
    }
}

- (UAScheduleDelayData *)createDelayDataFromDelay:(UAScheduleDelay *)delay
                                    scheduleStart:(NSDate *)scheduleStart
                                         schedule:(UAScheduleData *)schedule
                                          context:(NSManagedObjectContext *)context {

    UAScheduleDelayData *delayData = [self insertNewEntityForName:@"UAScheduleDelayData" context:context];
    delayData.seconds = @(delay.seconds);
    delayData.appState = @(delay.appState);
    delayData.regionID = delay.regionID;
    if (delay.screens != nil) {
        NSData *screensData = [UAJSONUtils dataWithObject:delay.screens options:0 error:nil];
        if (screensData != nil) {
            delayData.screens = [[NSString alloc] initWithData:screensData encoding:NSUTF8StringEncoding];
        }
    }
    delayData.cancellationTriggers = [self createTriggerDataFromTriggers:delay.cancellationTriggers scheduleStart:scheduleStart schedule:schedule context:context];

    return delayData;
}

- (NSSet<UAScheduleTriggerData *> *)createTriggerDataFromTriggers:(NSArray <UAScheduleTrigger *> *)triggers
                                                    scheduleStart:(NSDate *)scheduleStart
                                                         schedule:(UAScheduleData *)schedule
                                                          context:(NSManagedObjectContext *)context {
    NSMutableSet *data = [NSMutableSet set];

    for (UAScheduleTrigger *trigger in triggers) {
        UAScheduleTriggerData *triggerData = [self createTriggerDataFromTrigger:trigger scheduleStart:scheduleStart schedule:schedule context:context];
        [data addObject:triggerData];
    }

    return data;
}

- (UAScheduleTriggerData *)createTriggerDataFromTrigger:(UAScheduleTrigger *)trigger
                                          scheduleStart:(NSDate *)scheduleStart
                                               schedule:(UAScheduleData *)schedule
                                                context:(NSManagedObjectContext *)context {

    UAScheduleTriggerData *triggerData = [self insertNewEntityForName:@"UAScheduleTriggerData" context:context];
    triggerData.type = @(trigger.type);
    triggerData.goal = trigger.goal;
    triggerData.start = scheduleStart;

    if (trigger.predicate) {
        triggerData.predicateData = [UAJSONUtils dataWithObject:trigger.predicate.payload options:0 error:nil];
    }

    triggerData.schedule = schedule;
    triggerData.delay = schedule.delay;

    return triggerData;
}

- (void)waitForIdle {
    [self.coreData waitForIdle];
}

- (void)shutDown {
    [self.coreData shutDown];
}

@end

