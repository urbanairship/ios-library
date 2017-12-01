/* Copyright 2017 Urban Airship and Contributors */

#import "UAAutomationEngine+Internal.h"
#import "UAAnalytics+Internal.h"
#import "UAAutomationStore+Internal.h"
#import "UAScheduleTriggerData+Internal.h"
#import "UAScheduleData+Internal.h"
#import "UAScheduleDelayData+Internal.h"
#import "UASchedule+Internal.h"
#import "UAScheduleTrigger+Internal.h"
#import "UAScheduleInfo+Internal.h"
#import "UAEvent.h"
#import "UARegionEvent+Internal.h"
#import "UACustomEvent+Internal.h"
#import "NSJSONSerialization+UAAdditions.h"
#import "UAJSONPredicate.h"
#import "UAGlobal.h"

/*
 TODO:
 - Fix tests
 - JSON parsing back into UAScheduleInfo "data" vs "actions"

 Test TODO:
  - Migrate from v2 to v3
 */

@interface UAAutomationEngine()
@property (nonatomic, assign) NSUInteger scheduleLimit;
@property (nonatomic, copy) NSString *currentScreen;
@property (nonatomic, copy, nullable) NSString * currentRegion;
@property (nonatomic, assign) BOOL isForegrounded;
@property (nonatomic, strong) NSMutableArray *activeTimers;
@property (nonatomic, assign) UIBackgroundTaskIdentifier backgroundTaskIdentifier;
@property (nonatomic, assign) BOOL isStarted;
@property (nonnull, strong) NSMutableDictionary *stateConditions;
@property (atomic, assign) BOOL paused;
@end

@implementation UAAutomationEngine

- (void)dealloc {
    [self stop];
}

- (instancetype)initWithStoreName:(NSString *)storeName scheduleLimit:(NSUInteger)limit paused:(BOOL)paused {
    self = [super init];

    if (self) {
        self.automationStore = [UAAutomationStore automationStoreWithStoreName:storeName];
        self.scheduleLimit = limit;
        self.activeTimers = [NSMutableArray array];
        self.isForegrounded = NO;
        self.stateConditions = [NSMutableDictionary dictionary];
        self.paused = paused;
    }

    return self;
}

+ (instancetype)automationEngineWithStoreName:(NSString *)storeName scheduleLimit:(NSUInteger)limit paused:(BOOL)paused {
    return [[UAAutomationEngine alloc] initWithStoreName:storeName scheduleLimit:limit paused:paused];
}

#pragma mark -
#pragma mark Public API

- (void)start {
    if (self.isStarted) {
        return;
    }

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(enterBackground)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(enterForeground)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didBecomeActive)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(customEventAdded:)
                                                 name:UACustomEventAdded
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(screenTracked:)
                                                 name:UAScreenTracked
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(regionEventAdded:)
                                                 name:UARegionEventAdded
                                               object:nil];

    [self resetExecutingSchedules];
    [self createStateConditions];
    [self restoreCompoundTriggers];
    [self rescheduleTimers];
    [self updateTriggersWithType:UAScheduleTriggerAppInit argument:nil incrementAmount:1.0];
    [self scheduleConditionsChanged];
    self.isStarted = YES;
}

- (void)stop {
    if (!self.isStarted) {
        return;
    }

    [self cancelTimers];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.stateConditions removeAllObjects];
    self.isStarted = NO;
}

- (void)pause {
    if (!self.paused) {
        self.paused = YES;
    }
}

- (void)resume {
    if (self.paused) {
        self.paused = NO;
        if (!self.isStarted) {
            [self start];
        } else {
            [self scheduleConditionsChanged];
        }
    }
}
- (void)schedule:(UAScheduleInfo *)scheduleInfo completionHandler:(void (^)(UASchedule *))completionHandler {
    // Only allow valid schedules to be saved
    if (!scheduleInfo.isValid) {
        if (completionHandler) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(nil);
            });
        }

        return;
    }

    // Delete any expired schedules before trying to save a schedule to free up the limit
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"end <= %@", [NSDate date]];
    [self.automationStore deleteSchedulesWithPredicate:predicate];

    // Create a schedule to save
    UASchedule *schedule = [UASchedule scheduleWithIdentifier:[NSUUID UUID].UUIDString info:scheduleInfo];

    // Try to save the schedule
    [self.automationStore saveSchedule:schedule limit:self.scheduleLimit completionHandler:^(BOOL success) {
        // If saving the schedule was successful, process any compound triggers
        if (success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self checkCompoundTriggerState:@[schedule]];
            });
        }
        if (completionHandler) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(success ? schedule : nil);
            });
        }
    }];
}

- (void)cancelScheduleWithIdentifier:(NSString *)identifier {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"identifier == %@", identifier];
    [self.automationStore deleteSchedulesWithPredicate:predicate];
    [self cancelTimersWithIdentifiers:[NSSet setWithArray:@[identifier]]];
}

- (void)cancelAll {
    [self.automationStore deleteSchedulesWithPredicate:nil];
    [self cancelTimers];
}

- (void)cancelSchedulesWithGroup:(NSString *)group {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"group == %@", group];
    [self.automationStore deleteSchedulesWithPredicate:predicate];
    [self cancelTimersWithGroup:group];
}

- (void)getScheduleWithIdentifier:(NSString *)identifier completionHandler:(void (^)(UASchedule *))completionHandler {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"identifier == %@ && end >= %@", identifier, [NSDate date]];
    [self.automationStore fetchSchedulesWithPredicate:predicate limit:1 completionHandler:^(NSArray<UAScheduleData *> *schedulesData) {
        UASchedule *schedule;
        if (schedulesData.count) {
            schedule = [self scheduleFromData:schedulesData.firstObject];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(schedule);
        });
    }];
}

- (void)getSchedules:(void (^)(NSArray<UASchedule *> *))completionHandler {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"end >= %@", [NSDate date]];
    [self.automationStore fetchSchedulesWithPredicate:predicate limit:self.scheduleLimit completionHandler:^(NSArray<UAScheduleData *> *schedulesData) {
        NSMutableArray *schedules = [NSMutableArray array];
        for (UAScheduleData *scheduleData in schedulesData) {
            [schedules addObject:[self scheduleFromData:scheduleData]];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(schedules);
        });
    }];
}

- (void)getSchedulesWithGroup:(NSString *)group completionHandler:(void (^)(NSArray<UASchedule *> *))completionHandler {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"group == %@ && end >= %@", group, [NSDate date]];
    [self.automationStore fetchSchedulesWithPredicate:predicate limit:self.scheduleLimit completionHandler:^(NSArray<UAScheduleData *> *schedulesData) {
        NSMutableArray *schedules = [NSMutableArray array];
        for (UAScheduleData *scheduleData in schedulesData) {
            [schedules addObject:[self scheduleFromData:scheduleData]];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(schedules);
        });
    }];
}


#pragma mark -
#pragma mark Event listeners

- (void)didBecomeActive {
    [self enterForeground];

    // This handles the first active. enterForeground will handle future background->foreground
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidBecomeActiveNotification
                                                  object:nil];
}

- (void)enterForeground {
    self.isForegrounded = YES;

    if (!self.activeTimers) {
        [self rescheduleTimers];
    }

    // Update any dependent foreground triggers
    [self updateTriggersWithType:UAScheduleTriggerAppForeground argument:nil incrementAmount:1.0];

    // Active session triggers are also updated by foreground transitions
    [self updateTriggersWithType:UAScheduleTriggerActiveSession argument:nil incrementAmount:1.0];

    [self scheduleConditionsChanged];
}

- (void)enterBackground {
    self.isForegrounded = NO;

    [self updateTriggersWithType:UAScheduleTriggerAppBackground argument:nil incrementAmount:1.0];
    [self scheduleConditionsChanged];
}

-(void)customEventAdded:(NSNotification *)notification {
    UACustomEvent *event = notification.userInfo[UAEventKey];

    [self updateTriggersWithType:UAScheduleTriggerCustomEventCount argument:event.payload incrementAmount:1.0];

    if (event.eventValue) {
        [self updateTriggersWithType:UAScheduleTriggerCustomEventValue argument:event.payload incrementAmount:[event.eventValue doubleValue]];
    }
}

-(void)regionEventAdded:(NSNotification *)notification {
    UARegionEvent *event = notification.userInfo[UAEventKey];

    UAScheduleTriggerType triggerType;

    if (event.boundaryEvent == UABoundaryEventEnter) {
        triggerType = UAScheduleTriggerRegionEnter;
        self.currentRegion = event.regionID;
    } else {
        triggerType = UAScheduleTriggerRegionExit;
        self.currentRegion = nil;
    }

    [self updateTriggersWithType:triggerType argument:event.payload incrementAmount:1.0];

    [self scheduleConditionsChanged];
}

-(void)screenTracked:(NSNotification *)notification {
    NSString *screenName = notification.userInfo[UAScreenKey];

    if (screenName) {
        [self updateTriggersWithType:UAScheduleTriggerScreen argument:screenName incrementAmount:1.0];
    }

    self.currentScreen = screenName;
    [self scheduleConditionsChanged];
}

#pragma mark -
#pragma mark Event processing

- (NSArray<UAScheduleData *> *)sortedScheduleDataByPriority:(NSArray<UAScheduleData *> *)scheduleData {
    NSSortDescriptor *ascending = [[NSSortDescriptor alloc] initWithKey:@"priority" ascending:YES];
    return [scheduleData sortedArrayUsingDescriptors:@[ascending]];
}

- (NSArray<UASchedule *> *)sortedSchedulesByPriority:(NSArray<UASchedule *> *)schedules {
    NSSortDescriptor *ascending = [[NSSortDescriptor alloc] initWithKey:@"info.priority" ascending:YES];
    return [schedules sortedArrayUsingDescriptors:@[ascending]];
}

- (void)updateTriggersWithScheduleID:(NSString *)scheduleID type:(UAScheduleTriggerType)triggerType argument:(id)argument incrementAmount:(double)amount {
    if (self.paused) {
        return;
    }
    
    UA_LDEBUG(@"Updating triggers with type: %ld", (long)triggerType);

    NSDate *start = [NSDate date];

    // Only update schedule triggers and active cancellation triggers
    NSString *format = @"(schedule.identifier LIKE %@ AND type = %ld AND start <= %@) AND (delay == nil || delay.schedule.executionState == %d)";
    NSPredicate *predicate = [NSPredicate predicateWithFormat:format, scheduleID, triggerType, start, UAScheduleStatePendingExecution];

    [self.automationStore fetchTriggersWithPredicate:predicate completionHandler:^(NSArray<UAScheduleTriggerData *> *triggers) {

        // Capture what schedules need to be cancelled and executed in sets so we do not double process any schedules
        NSMutableSet *schedulesToCancel = [NSMutableSet set];
        NSMutableSet *schedulesToExecute = [NSMutableSet set];

        // Process triggers
        for (UAScheduleTriggerData *trigger in triggers) {
            UAJSONPredicate *predicate = [UAAutomationEngine predicateFromData:trigger.predicateData];
            if (predicate && argument) {
                if (![predicate evaluateObject:argument]) {
                    continue;
                }
            }

            trigger.goalProgress = @([trigger.goalProgress doubleValue] + amount);
            if ([trigger.goalProgress compare:trigger.goal] != NSOrderedAscending) {
                trigger.goalProgress = 0;

                // A delay associated with a trigger indicates its a cancellation trigger
                if (trigger.delay) {
                    [schedulesToCancel addObject:trigger.delay.schedule];
                    continue;
                }

                // Normal execution trigger. Only reexecute schedules that are not currently pending
                if (trigger.schedule && [trigger.schedule.executionState integerValue] == UAScheduleStateIdle) {
                    [schedulesToExecute addObject:trigger.schedule];
                }
            }
        }

        // Process all the schedules to execute
        [self processTriggeredSchedules:[schedulesToExecute allObjects]];

        // Process all the schedules to cancel
        for (UAScheduleData *scheduleData in schedulesToCancel) {
            UA_LTRACE(@"Pending automation schedule %@ execution canceled", scheduleData.identifier);
            scheduleData.executionState = @(UAScheduleStateIdle);
            scheduleData.delayedExecutionDate = nil;
        }

        // Cancel timers
        if (schedulesToCancel.count) {
            NSSet *timersToCancel = [schedulesToCancel valueForKeyPath:@"identifier"];

            // Handle timers on the main queue
            dispatch_async(dispatch_get_main_queue(), ^{
                [self cancelTimersWithIdentifiers:timersToCancel];
            });
        }

        NSTimeInterval executionTime = -[start timeIntervalSinceNow];
        UA_LTRACE(@"Automation execution time: %f seconds, triggers: %ld, triggered schedules: %ld", executionTime, (unsigned long)triggers.count, (unsigned long)schedulesToExecute.count);
    }];
}

- (void)updateTriggersWithType:(UAScheduleTriggerType)triggerType argument:(id)argument incrementAmount:(double)amount {
    [self updateTriggersWithScheduleID:@"*" type:triggerType argument:argument incrementAmount:amount];
}

/**
 * Starts a timer for the schedule.
 *
 * @param scheduleData The schedule's data.
 */
- (void)startTimerForSchedule:(UAScheduleData *)scheduleData {
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    [userInfo setValue:scheduleData.identifier forKey:@"identifier"];
    [userInfo setValue:scheduleData.group forKey:@"group"];
    [userInfo setValue:scheduleData.delayedExecutionDate forKey:@"delayedExecutionDate"];


    NSTimeInterval delay = [scheduleData.delay.seconds doubleValue];
    if (scheduleData.delayedExecutionDate) {
        delay = [scheduleData.delayedExecutionDate timeIntervalSinceNow];
    }

    if (delay <= 0) {
        delay = .1;
    }

    NSTimer *timer = [NSTimer timerWithTimeInterval:delay
                                             target:self
                                           selector:@selector(scheduleTimerFired:)
                                           userInfo:userInfo
                                            repeats:NO];

    // Schedule the timer on the main queue
    dispatch_async(dispatch_get_main_queue(), ^{

        // Make sure we have a background task identifier before starting the timer
        if (self.backgroundTaskIdentifier == UIBackgroundTaskInvalid) {
            self.backgroundTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
                UA_LTRACE(@"Automation background task expired. Cancelling delayed scheduled actions.");
                [self cancelTimers];
            }];

            // No background time. The timer will be rescheduled the next time the app is active
            if (self.backgroundTaskIdentifier == UIBackgroundTaskInvalid) {
                UA_LTRACE(@"Unable to request background task for automation timer.");
                return;
            }
        }

        UA_LTRACE(@"Starting automation timer for %f seconds with user info %@", delay, timer.userInfo);
        [self.activeTimers addObject:timer];
        [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
    });
}

/**
 * Delay timer fired for a schedule. Method is called on the main queue.
 *
 * @param timer The timer.
 */
- (void)scheduleTimerFired:(NSTimer *)timer {
    // Called on the main queue

    [self.activeTimers removeObject:timer];

    UA_LTRACE(@"Automation timer fired: %@", timer.userInfo);
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"identifier == %@ AND executionState == %d AND delayedExecutionDate == %@",
                              timer.userInfo[@"identifier"], UAScheduleStatePendingExecution, timer.userInfo[@"delayedExecutionDate"]];

    [self.automationStore fetchSchedulesWithPredicate:predicate limit:1 completionHandler:^(NSArray<UAScheduleData *> *schedules) {
        if (schedules.count != 1) {
            return;
        }

        UAScheduleData *scheduleData = schedules[0];

        // If the delayedExecutionDate is still in the future then the system time must have changed.
        // Update the delayedExcutionDate to now.
        if ([scheduleData.delayedExecutionDate compare:[NSDate date]] != NSOrderedAscending) {
            scheduleData.delayedExecutionDate = [NSDate date];
        }

        [self processTriggeredSchedules:schedules];

        // Check if we need to end the background task on the main queue
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!self.activeTimers.count) {
                [self endBackgroundTask];
            }
        });
    }];
}

/**
 * Cancel timers by schedule identifiers.
 *
 * @param identifiers A set of identifiers to cancel.
 */
- (void)cancelTimersWithIdentifiers:(NSSet<NSString *> *)identifiers {
    for (NSTimer *timer in [self.activeTimers copy]) {
        if ([identifiers containsObject:timer.userInfo[@"identifier"]]) {
            if (timer.isValid) {
                [timer invalidate];
            }
            [self.activeTimers removeObject:timer];
        }
    }

    if (!self.activeTimers.count) {
        [self endBackgroundTask];
    }
}

/**
 * Cancel timers by schedule group.
 *
 * @param group A schedule group.
 */
- (void)cancelTimersWithGroup:(NSString *)group {
    for (NSTimer *timer in [self.activeTimers copy]) {
        if ([group isEqualToString:timer.userInfo[@"group"]]) {
            if (timer.isValid) {
                [timer invalidate];
            }
            [self.activeTimers removeObject:timer];
        }
    }

    if (!self.activeTimers.count) {
        [self endBackgroundTask];
    }
}

/**
 * Cancels all timers.
 */
- (void)cancelTimers {
    for (NSTimer *timer in self.activeTimers) {
        if (timer.isValid) {
            [timer invalidate];
        }
    }

    [self.activeTimers removeAllObjects];
    [self endBackgroundTask];
}

/**
 * Reschedules timers for any schedule that is pending execution and has a future delayed execution date.
 */
- (void)rescheduleTimers {
    [self cancelTimers];

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"executionState == %d AND delayedExecutionDate > %@",
                              UAScheduleStatePendingExecution, [NSDate date]];
    [self.automationStore fetchSchedulesWithPredicate:predicate limit:self.scheduleLimit completionHandler:^(NSArray<UAScheduleData *> *schedules) {
        for (UAScheduleData *scheduleData in schedules) {

            // If the delayedExecutionDate is greater than the original delay it probably means a clock adjustment. Reset the delay.
            if ([scheduleData.delayedExecutionDate timeIntervalSinceNow] > [scheduleData.delay.seconds doubleValue]) {
                scheduleData.delayedExecutionDate = [NSDate dateWithTimeIntervalSinceNow:[scheduleData.delay.seconds doubleValue]];
            }

            [self startTimerForSchedule:scheduleData];
        }
    }];
}

/**
 * Resets executing schedules back to pendingExecution.
 */
- (void)resetExecutingSchedules {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"executionState == %d", UAScheduleStateExecuting];
    [self.automationStore fetchSchedulesWithPredicate:predicate limit:self.scheduleLimit completionHandler:^(NSArray<UAScheduleData *> *schedules) {
        for (UAScheduleData *scheduleData in schedules) {
            scheduleData.executionState = @(UAScheduleStateIdle);
        }
    }];
}

/**
 * Sets up state conditions for use with compound triggers.
 */
- (void)createStateConditions {
    BOOL (^activeSessionCondition)(void) = ^BOOL{
        return [UIApplication sharedApplication].applicationState == UIApplicationStateActive;
    };

    [self.stateConditions setObject:activeSessionCondition forKey:@(UAScheduleTriggerActiveSession)];
}

/**
 * Checks compound trigger state for currently active schedules, to be
 * called at start.
 */
- (void)restoreCompoundTriggers {
    UA_WEAKIFY(self)
    [self getSchedules:^(NSArray<UASchedule *> *schedules) {
        UA_STRONGIFY(self)
        [self checkCompoundTriggerState:schedules];
    }];
}

/**
 * Sorts provided schedules in ascending prioirty order and checks whether any compound triggers
 * assigned to those schedules have currently valid state conditions, updating them if necessary.
 *
 * @param schedules The schedules.
 */
- (void)checkCompoundTriggerState:(NSArray<UASchedule *> *)schedules {
    // Sort schedules by priority in ascending order
    schedules = [self sortedSchedulesByPriority:schedules];

    for (UASchedule *schedule in schedules) {
        for (UAScheduleTrigger *trigger in schedule.info.triggers) {
            UAScheduleTriggerType type = trigger.type;
            BOOL (^condition)(void) = self.stateConditions[@(type)];

            // If there is a matching condition and the condition holds, update all of the schedule's triggers of that type
            if (condition && condition()) {
                [self updateTriggersWithScheduleID:schedule.identifier type:type argument:nil incrementAmount:1.0];
            }
        }
    }
}

/**
 * Called when one of the schedule conditions changes.
 */
- (void)scheduleConditionsChanged {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"executionState == %d AND (delayedExecutionDate == nil OR delayedExecutionDate =< %@)", UAScheduleStatePendingExecution, [NSDate date]];
    [self.automationStore fetchSchedulesWithPredicate:predicate limit:self.scheduleLimit completionHandler:^(NSArray<UAScheduleData *> *schedules) {
        [self processTriggeredSchedules:schedules];
    }];
}

/**
 * Checks if a schedule that is pending execution is able to be executed.
 *
 * @param scheduleDelay The UAScheduleDelay to check.
 * @param delayedExecutionDate The delayed execution date.
 * @return YES if conditions are satisfied, otherwise NO.
 */
- (BOOL)isScheduleDelaySatisfied:(UAScheduleDelay *)scheduleDelay
            delayedExecutionDate:(NSDate *)delayedExecutionDate {

    if (delayedExecutionDate && [delayedExecutionDate compare:[NSDate date]] != NSOrderedAscending) {
        return NO;
    }

    if (!scheduleDelay) {
        return YES;
    }

    if (scheduleDelay.screens && ![scheduleDelay.screens containsObject:self.currentScreen]) {
        return NO;
    }

    if (scheduleDelay.regionID && ![scheduleDelay.regionID isEqualToString:self.currentRegion]) {
        return NO;
    }

    if (scheduleDelay.appState == UAScheduleDelayAppStateForeground && !self.isForegrounded) {
        return NO;
    }

    if (scheduleDelay.appState == UAScheduleDelayAppStateBackground && self.isForegrounded) {
        return NO;
    }

    return YES;
}

/**
 * Processes triggered schedules.
 *
 * @param schedules An array of triggered schedule data.
 */
- (void)processTriggeredSchedules:(NSArray<UAScheduleData *> *)schedules {
    if (self.paused) {
        return;
    }

    // Sort schedules by priority in ascending order
    schedules = [self sortedScheduleDataByPriority:schedules];

    for (UAScheduleData *scheduleData in schedules) {
        // If the schedule has expired, delete it
        if ([scheduleData.end compare:[NSDate date]] == NSOrderedAscending) {
            [scheduleData.managedObjectContext deleteObject:scheduleData];
            UA_LTRACE(@"Schedule expired, deleting schedule: %@", scheduleData.identifier);
            continue;
        }

        // Seconds delay
        if ([scheduleData.executionState intValue] == UAScheduleStateIdle && [scheduleData.delay.seconds doubleValue] > 0) {
            scheduleData.executionState = @(UAScheduleStatePendingExecution);
            scheduleData.delayedExecutionDate = [NSDate dateWithTimeIntervalSinceNow:[scheduleData.delay.seconds doubleValue]];

            // Reset the cancellation triggers
            for (UAScheduleTriggerData *cancellationTrigger in scheduleData.delay.cancellationTriggers) {
                cancellationTrigger.goalProgress = 0;
            }

            // Start a timer
            [self startTimerForSchedule:scheduleData];
            continue;
        }

        UASchedule *schedule = [self scheduleFromData:scheduleData];
        NSDate *delayedExecutionDate = scheduleData.delayedExecutionDate;

        // Set to pending if its currently idle
        if ([scheduleData.executionState intValue] == UAScheduleStateIdle) {
            // Reset the cancellation triggers
            for (UAScheduleTriggerData *cancellationTrigger in scheduleData.delay.cancellationTriggers) {
                cancellationTrigger.goalProgress = 0;
            }

            scheduleData.executionState = @(UAScheduleStatePendingExecution);
        }

        __block BOOL scheduleExecuting = NO;

        // Conditions and action executions must be run on the main queue.
        UA_WEAKIFY(self)
        dispatch_sync(dispatch_get_main_queue(), ^{
            if (self.paused) {
                return;
            }

            UA_STRONGIFY(self)
            if (!schedule) {
                return;
            }

            if (![self isScheduleDelaySatisfied:schedule.info.delay delayedExecutionDate:delayedExecutionDate]) {
                return;
            }

            if (![self.delegate isScheduleReadyToExecute:schedule]) {
                return;
            }

            [self.delegate executeSchedule:schedule completionHandler:^{
                UA_STRONGIFY(self)
                [self scheduleFinishedExecuting:schedule.identifier];
            }];

            scheduleExecuting = YES;
        });

        if (scheduleExecuting) {
            scheduleData.executionState = @(UAScheduleStateExecuting); // executing
        }
    }
}

- (void)scheduleFinishedExecuting:(NSString *)scheduleID {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"identifier == %@ && executionState == %d", scheduleID, UAScheduleStateExecuting];

    [self.automationStore fetchSchedulesWithPredicate:predicate limit:1 completionHandler:^(NSArray<UAScheduleData *> *result) {
        if (result.count > 0) {
            UAScheduleData *scheduleData = result.firstObject;

            scheduleData.executionState = @(UAScheduleStateIdle);
            scheduleData.delayedExecutionDate = nil;

            if ([scheduleData.limit integerValue] > 0) {
                scheduleData.triggeredCount = @([scheduleData.triggeredCount integerValue] + 1);
                if (scheduleData.triggeredCount >= scheduleData.limit) {
                    UA_LINFO(@"Limit reached for schedule %@", scheduleData.identifier);
                    [scheduleData.managedObjectContext deleteObject:scheduleData];
                }
            }
        }
    }];
}

/**
 * Helper method to end the background task if its not invalid.
 */
- (void)endBackgroundTask {
    if (self.backgroundTaskIdentifier != UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskIdentifier];
        self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
    }

}

#pragma mark -
#pragma mark Converters

- (UASchedule *)scheduleFromData:(UAScheduleData *)scheduleData {
    UAScheduleInfoBuilder *builder = [[UAScheduleInfoBuilder alloc] init];
    builder.triggers = [UAAutomationEngine triggersFromData:scheduleData.triggers];
    builder.delay = [UAAutomationEngine delayFromData:scheduleData.delay];
    builder.group = scheduleData.group;
    builder.data = scheduleData.data;
    builder.start = scheduleData.start;
    builder.end = scheduleData.end;
    builder.priority = [scheduleData.priority integerValue];
    builder.limit = [scheduleData.limit unsignedIntegerValue];

    UAScheduleInfo *info = [self.delegate createScheduleInfoWithBuilder:builder];

    if (!info) {
        return nil;
    }

    return [UASchedule scheduleWithIdentifier:scheduleData.identifier info:info];
}

+ (NSArray<UAScheduleTrigger *> *)triggersFromData:(NSSet<UAScheduleTriggerData *> *)data {
    NSMutableArray *triggers = [NSMutableArray array];

    for (UAScheduleTriggerData *triggerData in data) {
        UAScheduleTrigger *trigger = [UAScheduleTrigger triggerWithType:(UAScheduleTriggerType)[triggerData.type integerValue]
                                                                   goal:triggerData.goal
                                                              predicate:[UAAutomationEngine predicateFromData:triggerData.predicateData]];

        [triggers addObject:trigger];
    }

    return triggers;
}


+ (UAScheduleDelay *)delayFromData:(UAScheduleDelayData *)data {
    if (!data) {
        return nil;
    }

    return [UAScheduleDelay delayWithBuilderBlock:^(UAScheduleDelayBuilder *builder) {
        builder.seconds = [data.seconds doubleValue];
        NSData *screenData = [data.screens dataUsingEncoding:NSUTF8StringEncoding];
        if (screenData != nil) {
            builder.screens = [NSJSONSerialization JSONObjectWithData:screenData options:NSJSONReadingMutableContainers error:nil];
        }
        builder.regionID = data.regionID;
        builder.cancellationTriggers = [UAAutomationEngine triggersFromData:data.cancellationTriggers];
        builder.appState = [data.appState integerValue];
    }];
}

+ (UAJSONPredicate *)predicateFromData:(NSData *)data {
    if (!data) {
        return nil;
    }

    id json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
    return [UAJSONPredicate predicateWithJSON:json error:nil];
}

@end


