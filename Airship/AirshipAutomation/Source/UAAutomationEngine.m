/* Copyright Airship and Contributors */

#import "UAAutomationEngine+Internal.h"
#import "UAAutomationStore+Internal.h"
#import "UAScheduleTriggerData+Internal.h"
#import "UAScheduleData+Internal.h"
#import "UAScheduleDelayData+Internal.h"
#import "UASchedule+Internal.h"
#import "UAScheduleTrigger+Internal.h"
#import "UAScheduleTriggerContext+Internal.h"
#import "UAScheduleEdits+Internal.h"
#import "UAAirshipAutomationCoreImport.h"
#import "UAInAppMessage+Internal.h"
#import "UAScheduleAudience+Internal.h"
#import "UAInAppMessageSchedule.h"
#import "UAActionSchedule.h"
#import "UADeferredSchedule+Internal.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif

static NSString * const UAAutomationEngineDelayTaskID = @"UAAutomationEngine.delay";
static NSString * const UAAutomationEngineIntervalTaskID = @"UAAutomationEngine.interval";
static NSString * const UAAutomationEngineTaskExtrasIdentifier = @"identifier";

@interface UAAutomationStateCondition : NSObject

@property (nonatomic, copy, nonnull) BOOL (^predicate)(void);
@property (nonatomic, copy, nonnull) id (^argumentGenerator)(void);
@property (nonatomic, strong, nonnull) NSDate *stateChangeDate;

- (instancetype)initWithPredicate:(BOOL (^_Nonnull)(void))predicate argumentGenerator:(id (^)(void))argumentGenerator stateChangeDate:(NSDate *)date;

@end

@implementation UAAutomationStateCondition

- (instancetype)initWithPredicate:(BOOL (^_Nonnull)(void))predicate argumentGenerator:(id (^)(void))argumentGenerator stateChangeDate:(NSDate *)date {
    self = [super init];
    if (self) {
        self.predicate = predicate;
        self.argumentGenerator = argumentGenerator;
        self.stateChangeDate = date;
    }
    return self;
}

@end

@interface UAAutomationEngine()
@property (nonatomic, strong) UAAppStateTracker *appStateTracker;
@property (nonnull, strong) UADispatcher *dispatcher;
@property (nonnull, strong) UIApplication *application;
@property (nonnull, strong) NSNotificationCenter *notificationCenter;
@property (nonnull, nonatomic, strong) UADate *date;

@property (nonatomic, copy) NSString *currentScreen;
@property (nonatomic, copy, nullable) NSString * currentRegion;

@property (nonatomic, strong) UATaskManager *taskManager;

@property (nonatomic, strong) UANetworkMonitor *networkMonitor;

@property (nonatomic, assign) BOOL isStarted;
@property (nonnull, strong) NSMutableDictionary *stateConditions;
@property (atomic, assign) BOOL paused;
@property (nonatomic, readonly) BOOL isForegrounded;
@property (atomic, assign) BOOL isAppSessionPending;

@end

@implementation UAAutomationEngine

- (void)dealloc {
    [self stop];
    [self.automationStore shutDown];
}

- (instancetype)initWithAutomationStore:(UAAutomationStore *)automationStore
                        appStateTracker:(UAAppStateTracker *)appStateTracker
                            taskManager:(UATaskManager *)taskManager
                         networkMonitor:(UANetworkMonitor *)networkMonitor
                     notificationCenter:(NSNotificationCenter *)notificationCenter
                             dispatcher:(UADispatcher *)dispatcher
                            application:(UIApplication *)application
                                   date:(UADate *)date {
    self = [super init];

    if (self) {
        self.automationStore = automationStore;
        self.appStateTracker = appStateTracker;
        self.taskManager = taskManager;
        self.notificationCenter = notificationCenter;
        self.dispatcher = dispatcher;
        self.application = application;
        self.date = date;
        self.stateConditions = [NSMutableDictionary dictionary];
        self.networkMonitor = networkMonitor;
        self.paused = NO;
        self.isAppSessionPending = NO;

        UA_WEAKIFY(self)
        [self.taskManager registerForTaskWithIDs:@[UAAutomationEngineDelayTaskID, UAAutomationEngineIntervalTaskID]
                                      dispatcher:UADispatcher.serialUtility
                                   launchHandler:^(id<UATask> task) {
            UA_STRONGIFY(self)
            if ([task.taskID isEqualToString:UAAutomationEngineDelayTaskID]) {
                [self handleDelayTask:task];
            } else if ([task.taskID isEqualToString:UAAutomationEngineIntervalTaskID]) {
                [self handleIntervalTask:task];
            } else {
                UA_LERR(@"Invalid task: %@", task.taskID);
                [task taskCompleted];
            }
        }];

        if (@available(ios 12.0, tvOS 12.0, *)) {
            __block BOOL started = NO;
            self.networkMonitor.connectionUpdates = ^(BOOL connected) {
                UA_STRONGIFY(self)
                if (connected && started) {
                    [self scheduleConditionsChanged];
                }
                started = YES;
            };
        }
    }

    return self;
}

+ (instancetype)automationEngineWithAutomationStore:(UAAutomationStore *)automationStore
                                    appStateTracker:(UAAppStateTracker *)appStateTracker
                                        taskManager:(UATaskManager *)taskManager
                                     networkMonitor:(UANetworkMonitor *)networkMonitor
                                 notificationCenter:(NSNotificationCenter *)notificationCenter
                                         dispatcher:(UADispatcher *)dispatcher
                                        application:(UIApplication *)application
                                               date:(UADate *)date {

    return [[UAAutomationEngine alloc] initWithAutomationStore:automationStore
                                               appStateTracker:appStateTracker
                                                   taskManager:taskManager
                                                networkMonitor:networkMonitor
                                            notificationCenter:notificationCenter
                                                    dispatcher:dispatcher
                                                   application:application
                                                          date:date];
}

+ (instancetype)automationEngineWithAutomationStore:(UAAutomationStore *)automationStore NS_EXTENSION_UNAVAILABLE("Method not available in app extensions") {
    return [[UAAutomationEngine alloc] initWithAutomationStore:automationStore
                                               appStateTracker:[UAAppStateTracker shared]
                                                   taskManager:[UATaskManager shared]
                                                networkMonitor:[[UANetworkMonitor alloc] init]
                                            notificationCenter:[NSNotificationCenter defaultCenter]
                                                    dispatcher:UADispatcher.main
                                                   application:[UIApplication sharedApplication]
                                                          date:[[UADate alloc] init]];
}

#pragma mark -
#pragma mark Public API

- (void)start {
    if (self.isStarted) {
        return;
    }

    [self.notificationCenter addObserver:self
                                selector:@selector(customEventAdded:)
                                    name:UAAnalytics.customEventAdded
                                  object:nil];

    [self.notificationCenter addObserver:self
                                selector:@selector(screenTracked:)
                                    name:UAAnalytics.screenTracked
                                  object:nil];

    [self.notificationCenter addObserver:self
                                selector:@selector(regionEventAdded:)
                                    name:UAAnalytics.regionEventAdded
                                  object:nil];

    [self.notificationCenter addObserver:self
                                selector:@selector(applicationDidTransitionToBackground)
                                    name:UAAppStateTracker.didTransitionToBackground
                                  object:nil];

    [self.notificationCenter addObserver:self
                                selector:@selector(applicationDidTransitionToForeground)
                                    name:UAAppStateTracker.didTransitionToForeground
                                  object:nil];

    [self finishExecutionSchedules];
    [self cleanSchedules];
    [self resetPendingSchedules];
    [self rescheduleTasks];
    [self createStateConditions];
    [self restoreCompoundTriggers];
    [self updateTriggersWithType:UAScheduleTriggerAppInit argument:nil incrementAmount:1.0];
    [self scheduleConditionsChanged];

    UA_WEAKIFY(self)
    [self.automationStore getSchedulesWithStates:@[@(UAScheduleStatePreparingSchedule)]
                               completionHandler:^(NSArray<UAScheduleData *> *schedules) {
        UA_STRONGIFY(self)
        [self prepareSchedules:[self sortedScheduleDataByPriority:schedules]];
    }];

    self.isStarted = YES;
}

- (void)stop {
    if (!self.isStarted) {
        return;
    }

    [self.notificationCenter removeObserver:self];
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
        if (self.isAppSessionPending) {
            [self updateTriggersWithType:UAScheduleTriggerActiveSession argument:nil incrementAmount:1.0];
            self.isAppSessionPending = NO;
        }
        [self scheduleConditionsChanged];
    }
}

- (void)schedule:(UASchedule *)schedule completionHandler:(nullable void (^)(BOOL result))completionHandler {
    // Only allow valid schedules to be saved
    if (!schedule.isValid) {
        if (completionHandler) {
            [self.dispatcher dispatchAsync:^{
                completionHandler(NO);
            }];
        }

        return;
    }

    [self cleanSchedules];

    // Try to save the schedule
    UA_WEAKIFY(self);
    [self.automationStore saveSchedule:schedule completionHandler:^(BOOL success) {
        UA_STRONGIFY(self);

        // If saving the schedule was successful, process any compound triggers
        if (success) {
            [self.dispatcher dispatchAsync:^{
                UA_STRONGIFY(self);
                [self checkCompoundTriggerState:@[schedule]];
            }];
        }

        if (completionHandler) {
            [self.dispatcher dispatchAsync:^{
                completionHandler(success);
            }];
        }
    }];
}

- (void)scheduleMultiple:(NSArray<UASchedule *> *)schedules
       completionHandler:(void (^)(BOOL))completionHandler {
    [self cleanSchedules];

    for (UASchedule *schedule in schedules) {
        if (!schedule.isValid) {
            UA_LTRACE(@"Invalid schedule: %@", schedule);
            if (completionHandler) {
                completionHandler(NO);
                return;
            }
        }
    }

    UA_LTRACE(@"Scheduling: %@", schedules);

    // Try to save the schedules
    UA_WEAKIFY(self);
    [self.automationStore saveSchedules:schedules completionHandler:^(BOOL success) {
        UA_STRONGIFY(self);

        if (success) {
            [self.dispatcher dispatchAsync:^{
                UA_STRONGIFY(self);
                [self checkCompoundTriggerState:schedules];
            }];
        }

        if (completionHandler) {
            [self.dispatcher dispatchAsync:^{
                completionHandler(success);
            }];
        }
    }];
}

- (void)cancelScheduleWithID:(NSString *)identifier completionHandler:(nullable void (^)(BOOL))completionHandler {
    UA_LTRACE(@"Cancelling schedule with ID: %@", identifier);

    UA_WEAKIFY(self)
    [self.automationStore getSchedule:identifier completionHandler:^(UAScheduleData * _Nullable scheduleData) {
        UA_STRONGIFY(self)
        [self handleCancelledSchedules:scheduleData ? @[scheduleData] : @[]
                     completionHandler:completionHandler];
    }];
}

- (void)cancelSchedulesWithGroup:(NSString *)group
                            type:(UAScheduleType)scheduleType
               completionHandler:(void (^)(BOOL))completionHandler {
    UA_LTRACE(@"Cancelling schedules with type %ld and group: %@", (long) scheduleType, group);

    UA_WEAKIFY(self)
    [self.automationStore getSchedules:group type:scheduleType completionHandler:^(NSArray<UAScheduleData *> * _Nonnull scheduleDatas) {
        UA_STRONGIFY(self)
        [self handleCancelledSchedules:scheduleDatas completionHandler:completionHandler];
    }];
}

- (void)cancelSchedulesWithGroup:(NSString *)group
               completionHandler:(nullable void (^)(BOOL))completionHandler {
    UA_LTRACE(@"Cancelling schedules with group: %@", group);

    UA_WEAKIFY(self)
    [self.automationStore getSchedules:group completionHandler:^(NSArray<UAScheduleData *> * _Nonnull scheduleDatas) {
        UA_STRONGIFY(self)
        [self handleCancelledSchedules:scheduleDatas completionHandler:completionHandler];
    }];
}

- (void)cancelSchedulesWithType:(UAScheduleType)scheduleType
              completionHandler:(nullable void (^)(BOOL))completionHandler {
    UA_LTRACE(@"Cancelling schedules with type %ld", (long) scheduleType);

    UA_WEAKIFY(self)
    [self.automationStore getSchedulesWithType:scheduleType
                             completionHandler:^(NSArray<UAScheduleData *> *scheduleDatas) {
        UA_STRONGIFY(self)
        [self handleCancelledSchedules:scheduleDatas completionHandler:completionHandler];
    }];
}

- (void)getSchedulesWithType:(UAScheduleType)scheduleType
           completionHandler:(void (^)(NSArray<UASchedule *> *))completionHandler {
    [self cleanSchedules];

    UA_WEAKIFY(self)
    [self.automationStore getSchedulesWithType:scheduleType
                             completionHandler:^(NSArray<UAScheduleData *> *schedulesData) {
        UA_STRONGIFY(self)
        NSArray *schedules = [self schedulesFromData:schedulesData];
        [self.dispatcher dispatchAsync:^{
            completionHandler(schedules);
        }];
    }];
}

- (void)getScheduleWithID:(NSString *)identifier
                     type:(UAScheduleType)scheduleType
        completionHandler:(void (^)(UASchedule * _Nullable))completionHandler {
    [self cleanSchedules];

    UA_WEAKIFY(self)
    [self.automationStore getSchedule:identifier
                                 type:scheduleType
                    completionHandler:^(UAScheduleData *scheduleData) {
        UA_STRONGIFY(self)
        UASchedule *schedule = nil;
        if (scheduleData) {
            schedule = [self scheduleFromData:scheduleData];
        }

        [self.dispatcher dispatchAsync:^{
            completionHandler(schedule);
        }];
    }];
}

- (void)getScheduleWithID:(NSString *)identifier
        completionHandler:(void (^)(UASchedule *))completionHandler {
    [self cleanSchedules];

    UA_WEAKIFY(self)
    [self.automationStore getSchedule:identifier completionHandler:^(UAScheduleData *scheduleData) {
        UA_STRONGIFY(self)

        UASchedule *schedule = nil;
        if (scheduleData) {
            schedule = [self scheduleFromData:scheduleData];
        }

        [self.dispatcher dispatchAsync:^{
            completionHandler(schedule);
        }];
    }];
}

- (void)getSchedules:(void (^)(NSArray<UASchedule *> *))completionHandler {
    [self cleanSchedules];

    UA_WEAKIFY(self)
    [self.automationStore getSchedules:^(NSArray<UAScheduleData *> *schedulesData) {
        UA_STRONGIFY(self)
        NSArray *schedules = [self schedulesFromData:schedulesData];
        [self.dispatcher dispatchAsync:^{
            completionHandler(schedules);
        }];
    }];
}

- (void)getSchedulesWithGroup:(NSString *)group
                         type:(UAScheduleType)scheduleType
            completionHandler:(void (^)(NSArray<UASchedule *> *))completionHandler {
    [self cleanSchedules];

    UA_WEAKIFY(self)
    [self.automationStore getSchedules:group
                                  type:scheduleType
                     completionHandler:^(NSArray<UAScheduleData *> *schedulesData) {
        UA_STRONGIFY(self)
        NSArray *schedules = [self schedulesFromData:schedulesData];
        [self.dispatcher dispatchAsync:^{
            completionHandler(schedules);
        }];
    }];
}

- (void)getSchedulesWithGroup:(NSString *)group
            completionHandler:(void (^)(NSArray<UASchedule *> *))completionHandler {
    UA_WEAKIFY(self)
    [self.automationStore getSchedules:group completionHandler:^(NSArray<UAScheduleData *> *schedulesData) {
        UA_STRONGIFY(self)
        NSArray *schedules = [self schedulesFromData:schedulesData];
        [self.dispatcher dispatchAsync:^{
            completionHandler(schedules);
        }];
    }];
}

- (void)editScheduleWithID:(NSString *)identifier
                     edits:(UAScheduleEdits *)edits
         completionHandler:(void (^)(BOOL))completionHandler {
    UA_LTRACE(@"Editing schedule %@ with edits %@", identifier, edits);
    UA_WEAKIFY(self)
    [self.automationStore getSchedule:identifier completionHandler:^(UAScheduleData * _Nullable scheduleData) {
        UA_STRONGIFY(self)

        UASchedule *schedule = nil;
        if (scheduleData) {
            [UAAutomationEngine applyEdits:edits toData:scheduleData];
            schedule = [self scheduleFromData:scheduleData];

            BOOL overLimit = [scheduleData isOverLimit];
            BOOL isExpired = [scheduleData isExpired];

            // Check if the schedule needs to be rehabilitated or finished due to the edits
            if ([scheduleData checkState:UAScheduleStateFinished] && !overLimit && !isExpired) {
                UA_LTRACE(@"Schedule %@ rehabilitated", identifier);
                NSDate *finishDate = scheduleData.executionStateChangeDate;
                [scheduleData updateState:UAScheduleStateIdle];

                // Handle any state changes that might have been missed while the schedule was finished
                if (schedule) {
                    UA_WEAKIFY(self);
                    [self.dispatcher dispatchAsync:^{
                        UA_STRONGIFY(self);
                        [self checkCompoundTriggerState:@[schedule] forStateNewerThanDate:finishDate];
                    }];
                }
            } else if (![scheduleData checkState:UAScheduleStateFinished] && (overLimit || isExpired)) {
                if (overLimit) {
                    UA_LTRACE(@"After editing schedule %@, schedule is over the limit", identifier);
                    [self notifyDelegateOnScheduleLimitReached:schedule];
                }
                if (isExpired) {
                    UA_LTRACE(@"After editing schedule %@, schedule is expired", identifier);
                    [self notifyDelegateOnScheduleExpired:schedule];
                }
                [self finishSchedule:scheduleData];
            }
        } else {
            UA_LTRACE(@"Schedule %@ not found. Unable to edit", identifier);
        }

        if (completionHandler) {
            [self.dispatcher dispatchAsync:^{
                completionHandler(schedule != nil);
            }];
        }
    }];
}

#pragma mark -
#pragma mark Private

- (void)handleCancelledSchedules:(NSArray<UAScheduleData *> *)scheduleDatas
               completionHandler:(nullable void (^)(BOOL))completionHandler {

    NSMutableSet *identifiers = [NSMutableSet set];
    for (UAScheduleData *scheduleData in scheduleDatas) {
        UASchedule *schedule = [self scheduleFromData:scheduleData];
        if (schedule) {
            [self notifyDelegateOnScheduleCancelled:schedule];
            [identifiers addObject:scheduleData.identifier];
            [scheduleData.managedObjectContext deleteObject:scheduleData];
        }
    }

    if (completionHandler) {
        [self.dispatcher dispatchAsync:^{
            completionHandler([identifiers count] > 0);
        }];
    }
}

- (BOOL)isForegrounded {
    return self.appStateTracker.state == UAApplicationStateActive;
}

- (void)cleanSchedules {
    UA_WEAKIFY(self)
    // Expired schedules
    [self.automationStore getActiveExpiredSchedules:^(NSArray<UAScheduleData *> *schedulesData) {
        UA_STRONGIFY(self)
        for (UAScheduleData *scheduleData in schedulesData) {
            [self handleExpiredScheduleData:scheduleData];
        }
    }];

    // Finished schedules
    [self.automationStore getSchedulesWithStates:@[@(UAScheduleStateFinished)] completionHandler:^(NSArray<UAScheduleData *> *schedulesData) {
        for (UAScheduleData *scheduleData in schedulesData) {
            NSDate *finishDate;

            // If grace period is unset - use the executionStateChangeDate as finishDate to avoid unnecessarily keeping schedules around until distant future.
            if (scheduleData.editGracePeriod == 0) {
                finishDate = scheduleData.executionStateChangeDate;
            } else {
                // If the grace period is set - follow the end date behavior outlined in the specification.
                finishDate = [scheduleData.end dateByAddingTimeInterval:[scheduleData.editGracePeriod doubleValue]];
            }

            if ([finishDate compare:self.date.now] == NSOrderedAscending) {
                UA_LTRACE(@"Deleting schedule %@", scheduleData.identifier);
                [scheduleData.managedObjectContext deleteObject:scheduleData];
            }
        }
    }];
}

#pragma mark -
#pragma mark Event listeners

- (void)applicationDidTransitionToForeground {
    // Update any dependent foreground triggers
    [self updateTriggersWithType:UAScheduleTriggerAppForeground argument:nil incrementAmount:1.0];

    if (self.paused) {
        self.isAppSessionPending = YES;
    } else {
        // Active session triggers are also updated by foreground transitions
        [self updateTriggersWithType:UAScheduleTriggerActiveSession argument:nil incrementAmount:1.0];
        self.isAppSessionPending = NO;
    }
    UAAutomationStateCondition *condition = self.stateConditions[@(UAScheduleTriggerActiveSession)];
    condition.stateChangeDate = self.date.now;

    [self scheduleConditionsChanged];
}

- (void)applicationDidTransitionToBackground {
    [self updateTriggersWithType:UAScheduleTriggerAppBackground argument:nil incrementAmount:1.0];
    [self scheduleConditionsChanged];
    self.isAppSessionPending = NO;
}

-(void)customEventAdded:(NSNotification *)notification {
    UACustomEvent *event = notification.userInfo[UAAnalytics.eventKey];

    [self updateTriggersWithType:UAScheduleTriggerCustomEventCount
                        argument:event.payload
                 incrementAmount:1.0];

    if (event.eventValue) {
        [self updateTriggersWithType:UAScheduleTriggerCustomEventValue
                            argument:event.payload
                     incrementAmount:[event.eventValue doubleValue]];
    }
}

-(void)regionEventAdded:(NSNotification *)notification {
    UARegionEvent *event = notification.userInfo[UAAnalytics.eventKey];

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
    NSString *screenName = notification.userInfo[UAAnalytics.screenKey];

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
    NSSortDescriptor *ascending = [[NSSortDescriptor alloc] initWithKey:@"priority" ascending:YES];
    return [schedules sortedArrayUsingDescriptors:@[ascending]];
}

- (void)updateTriggersWithScheduleID:(NSString *)scheduleID
                                type:(UAScheduleTriggerType)triggerType
                            argument:(id)argument
                     incrementAmount:(double)amount {

    if (self.paused) {
        return;
    }

    UA_LDEBUG(@"Updating triggers with type: %ld", (long)triggerType);

    NSDate *start = self.date.now;

    UA_WEAKIFY(self)
    [self.automationStore getActiveTriggers:scheduleID type:triggerType completionHandler:^(NSArray<UAScheduleTriggerData *> *triggers) {

        UA_STRONGIFY(self)

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

                // Store trigger context
                trigger.schedule.triggerContext = [UAScheduleTriggerContext
                                                   triggerContextWithTrigger:[UAAutomationEngine triggerFromData:trigger]

                                                   event:argument];

                // Normal execution trigger. Only reexecute schedules that are not currently pending
                if (trigger.schedule) {
                    [schedulesToExecute addObject:trigger.schedule];
                }
            }
        }

        // Process all the schedules to execute
        [self processTriggeredSchedules:[schedulesToExecute allObjects]];

        // Process all the schedules to cancel
        for (UAScheduleData *scheduleData in schedulesToCancel) {
            UA_LTRACE(@"Pending automation schedule %@ execution canceled", scheduleData.identifier);
            [scheduleData updateState:UAScheduleStateIdle];
        }

        NSTimeInterval executionTime = -[start timeIntervalSinceDate:self.date.now];
        UA_LTRACE(@"Automation execution time: %f seconds, triggers: %ld, triggered schedules: %ld", executionTime, (unsigned long)triggers.count, (unsigned long)schedulesToExecute.count);
    }];
}

- (void)updateTriggersWithType:(UAScheduleTriggerType)triggerType argument:(id)argument incrementAmount:(double)amount {
    [self updateTriggersWithScheduleID:nil type:triggerType argument:argument incrementAmount:amount];
}

- (void)enqueueDelayTaskForSchedule:(UAScheduleData *)scheduleData timeInterval:(NSTimeInterval)timeInterval {
    id extras = @{UAAutomationEngineTaskExtrasIdentifier : scheduleData.identifier};

    UATaskRequestOptions *requestOptions = [[UATaskRequestOptions alloc] initWithConflictPolicy:UATaskConflictPolicyAppend
                                                                                requiresNetwork:NO
                                                                                         extras:extras];


    [self.taskManager enqueueRequestWithID:UAAutomationEngineDelayTaskID
                                   options:requestOptions
                              initialDelay:timeInterval];
}

- (void)enqueueIntervalTaskForSchedule:(UAScheduleData *)scheduleData timeInterval:(NSTimeInterval)timeInterval {
    id extras = @{UAAutomationEngineTaskExtrasIdentifier : scheduleData.identifier};

    UATaskRequestOptions *requestOptions = [[UATaskRequestOptions alloc] initWithConflictPolicy:UATaskConflictPolicyAppend
                                                                                requiresNetwork:NO
                                                                                         extras:extras];


    [self.taskManager enqueueRequestWithID:UAAutomationEngineIntervalTaskID
                                   options:requestOptions
                              initialDelay:timeInterval];
}

/**
 * Handler for delay tasks. Method is called on a serial dispatch queue.
 * *
 * @param task The task.
 */
- (void)handleDelayTask:(id<UATask>)task {
    NSDictionary *extras = task.requestOptions.extras;
    UA_LTRACE(@"Handle delay task: %@", extras);

    NSString *identifier = extras[UAAutomationEngineTaskExtrasIdentifier];

    UA_WEAKIFY(self);
    [self.automationStore getSchedule:identifier completionHandler:^(UAScheduleData *scheduleData) {
        UA_STRONGIFY(self);

        // Verify we are still delayed
        if (!scheduleData || ![scheduleData verifyState:UAScheduleStateTimeDelayed]) {
            [task taskCompleted];
            return;
        }

        // Check expired
        if ([scheduleData isExpired]) {
            [self handleExpiredScheduleData:scheduleData];
            [task taskCompleted];
            return;
        }

        // Delay -> Prepare
        [scheduleData updateState:UAScheduleStatePreparingSchedule];
        [self prepareSchedules:@[scheduleData]];

        // Complete the task
        [task taskCompleted];
    }];
}

/**
 * Handler for interval tasks. Method is called on a serial dispatch queue.
 *
 * @param task The task.
 */
- (void)handleIntervalTask:(id<UATask>)task {
    NSDictionary *extras = task.requestOptions.extras;
    UA_LTRACE(@"Handle interval task: %@", extras);

    NSString *identifier = extras[UAAutomationEngineTaskExtrasIdentifier];

    UA_WEAKIFY(self);
    [self.automationStore getSchedule:identifier completionHandler:^(UAScheduleData *scheduleData) {
        UA_STRONGIFY(self);

        // Verify we are still paused
        if (!scheduleData || ![scheduleData verifyState:UAScheduleStatePaused]) {
            [task taskCompleted];
            return;
        }

        // Check expired
        if ([scheduleData isExpired]) {
            [self handleExpiredScheduleData:scheduleData];
            [task taskCompleted];
            return;
        }

        // Capture the pause date
        NSDate *pauseDate = scheduleData.executionStateChangeDate;

        // Paused -> Idle
        [scheduleData updateState:UAScheduleStateIdle];

        // Check compound trigger state
        UASchedule *schedule = [self scheduleFromData:scheduleData];
        if (schedule) {
            [self.dispatcher dispatchAsync:^{
                [self checkCompoundTriggerState:@[schedule] forStateNewerThanDate:pauseDate];
            }];
        }

        // Complete the task
        [task taskCompleted];
    }];
}

/**
 * Reschedules timers for any schedule that is pending execution and has a future delayed execution date.
 */
- (void)rescheduleTasks {
    // Delay tasks
    UA_WEAKIFY(self);
    [self.automationStore getSchedulesWithStates:@[@(UAScheduleStateTimeDelayed)] completionHandler:^(NSArray<UAScheduleData *> *schedules) {
        UA_STRONGIFY(self);
        for (UAScheduleData *scheduleData in schedules) {
            // If the delayedExecutionDate is greater than the original delay it probably means a clock adjustment. Reset the delay.
            if ([scheduleData.delayedExecutionDate timeIntervalSinceDate:self.date.now] > [scheduleData.delay.seconds doubleValue]) {
                scheduleData.delayedExecutionDate = [NSDate dateWithTimeInterval:scheduleData.delay.seconds.doubleValue sinceDate:self.date.now];
            }

            [self enqueueDelayTaskForSchedule:scheduleData timeInterval:[scheduleData.delay.seconds doubleValue]];
        }
    }];

    // Interval tasks
    [self.automationStore getSchedulesWithStates:@[@(UAScheduleStatePaused)] completionHandler:^(NSArray<UAScheduleData *> *schedules) {
        UA_STRONGIFY(self);
        for (UAScheduleData *scheduleData in schedules) {
            NSTimeInterval interval = [scheduleData.interval doubleValue];
            NSTimeInterval pauseTime = -[scheduleData.executionStateChangeDate timeIntervalSinceDate:self.date.now];
            NSTimeInterval remainingTime = interval - pauseTime;
            if (remainingTime > interval) {
                remainingTime = interval;
            }

            [self enqueueIntervalTaskForSchedule:scheduleData timeInterval:remainingTime];
        }
    }];
}

/**
 * Resets schedules back to preparing schedule
 */
- (void)resetPendingSchedules {
    id state = @[@(UAScheduleStateWaitingScheduleConditions)];
    [self.automationStore getSchedulesWithStates:state completionHandler:^(NSArray<UAScheduleData *> *schedules) {
        for (UAScheduleData *scheduleData in schedules) {
            [scheduleData updateState:UAScheduleStatePreparingSchedule];
        }
    }];
}

/**
 * Finishes any executing schedules from the previous app session.
 */
- (void)finishExecutionSchedules {
    id state = @[@(UAScheduleStateExecuting)];
    UA_WEAKIFY(self)
    [self.automationStore getSchedulesWithStates:state completionHandler:^(NSArray<UAScheduleData *> *schedules) {
        UA_STRONGIFY(self)
        for (UAScheduleData *scheduleData in schedules) {
            [self scheduleFinishedExecuting:scheduleData];
            UASchedule *schedule = [self scheduleFromData:scheduleData];
            if (schedule) {
                [self.delegate onExecutionInterrupted:schedule];
            }
        }
    }];
}

/**
 * Sets up state conditions for use with compound triggers.
 */
- (void)createStateConditions {
    UAAutomationStateCondition *activeSessionCondition = [[UAAutomationStateCondition alloc] initWithPredicate:^BOOL {
        return self.appStateTracker.state == UAApplicationStateActive;
    } argumentGenerator:nil stateChangeDate:self.date.now];

    UAAutomationStateCondition *versionCondition = [[UAAutomationStateCondition alloc] initWithPredicate:^BOOL {
        return [UAirship shared].applicationMetrics.isAppVersionUpdated;
    } argumentGenerator:^id {
        NSString *currentVersion = [UAirship shared].applicationMetrics.currentAppVersion;
        return currentVersion ? @{@"ios" : @{@"version": currentVersion}} : nil;
    } stateChangeDate:self.date.now];

    [self.stateConditions setObject:activeSessionCondition forKey:@(UAScheduleTriggerActiveSession)];
    [self.stateConditions setObject:versionCondition forKey:@(UAScheduleTriggerVersion)];
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
    [self checkCompoundTriggerState:schedules forStateNewerThanDate:[NSDate distantPast]];
}

/**
 * Sorts provided schedules in ascending prioirty order and checks whether any compound triggers
 * assigned to those schedules have currently valid state conditions, updating them if necessary.
 *
 * @param schedules The schedules.
 * @param date Filters out state triggers based on the state change date.
 */
- (void)checkCompoundTriggerState:(NSArray<UASchedule *> *)schedules forStateNewerThanDate:(NSDate *)date {
    // Sort schedules by priority in ascending order
    schedules = [self sortedSchedulesByPriority:schedules];

    for (UASchedule *schedule in schedules) {
        NSMutableArray *checkedTriggerTypes = [NSMutableArray array];
        for (UAScheduleTrigger *trigger in schedule.triggers) {
            UAScheduleTriggerType type = trigger.type;
            UAAutomationStateCondition *condition = self.stateConditions[@(type)];

            if (!condition || [checkedTriggerTypes containsObject:@(type)]) {
                continue;
            }

            // If there is a matching condition and the condition holds, update all of the schedule's triggers of that type
            if ([date compare:condition.stateChangeDate] == NSOrderedAscending && condition.predicate()) {
                id argument = condition.argumentGenerator ? condition.argumentGenerator() : nil;
                [self updateTriggersWithScheduleID:schedule.identifier type:type argument:argument incrementAmount:1.0];
            }

            [checkedTriggerTypes addObject:@(type)];
        }
    }
}

/**
 * Called when one of the schedule conditions changes.
 */
- (void)scheduleConditionsChanged {
    if (!self.isStarted) {
        return;
    }
    UA_WEAKIFY(self)
    [self.automationStore getSchedulesWithStates:@[@(UAScheduleStateWaitingScheduleConditions)]
                               completionHandler:^(NSArray<UAScheduleData *> *schedulesData) {
        UA_STRONGIFY(self);
        schedulesData = [self sortedScheduleDataByPriority:schedulesData];
        for (UAScheduleData *scheduleData in schedulesData) {
            [self attemptExecution:scheduleData];
        }
    }];
}

/**
 * Checks if a schedule that is pending execution is able to be executed.
 *
 * @param scheduleDelay The UAScheduleDelay to check.
 * @return YES if conditions are satisfied, otherwise NO.
 */
- (BOOL)isScheduleConditionsSatisfied:(UAScheduleDelay *)scheduleDelay {
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
    if (!schedules.count || self.paused) {
        return;
    }

    NSMutableArray *schedulesToPrepare = [NSMutableArray array];


    for (UAScheduleData *scheduleData in schedules) {
        UA_LTRACE(@"Processing triggered schedule %@", scheduleData.identifier);

        if (![scheduleData verifyState:UAScheduleStateIdle]) {
            continue;
        }

        // Check expired
        if ([scheduleData isExpired]) {
            [self handleExpiredScheduleData:scheduleData];
            continue;
        }

        // Reset cancellation triggers
        for (UAScheduleTriggerData *cancellationTrigger in scheduleData.delay.cancellationTriggers) {
            cancellationTrigger.goalProgress = 0;
        }

        // Check for time delay
        if ([scheduleData.delay.seconds doubleValue] > 0) {
            [scheduleData updateState:UAScheduleStateTimeDelayed];
            scheduleData.delayedExecutionDate = [NSDate dateWithTimeInterval:scheduleData.delay.seconds.doubleValue sinceDate:self.date.now];

            // Enqueue a delay task
            [self enqueueDelayTaskForSchedule:scheduleData timeInterval:[scheduleData.delay.seconds doubleValue]];

            continue;
        }

        [schedulesToPrepare addObject:scheduleData];
        [scheduleData updateState:UAScheduleStatePreparingSchedule];
    }

    [self prepareSchedules:schedulesToPrepare];
}

- (void)prepareSchedules:(NSArray<UAScheduleData *> *)schedules {
    if (!schedules.count) {
        return;
    }

    // Sort schedules by priority in ascending order
    schedules = [self sortedScheduleDataByPriority:schedules];

    for (UAScheduleData *scheduleData in schedules) {
        NSString *scheduleID = scheduleData.identifier;

        UASchedule *schedule = [self scheduleFromData:scheduleData];
        if (!schedule) {
            continue;
        }

        if (![scheduleData verifyState:UAScheduleStatePreparingSchedule]) {
            continue;
        }

        UA_LTRACE(@"Preparing schedule %@", scheduleData.identifier);

        UAScheduleTriggerContext *triggerContext = scheduleData.triggerContext;

        UA_WEAKIFY(self)
        [self.delegate prepareSchedule:schedule triggerContext:triggerContext completionHandler:^(UAAutomationSchedulePrepareResult prepareResult) {
            UA_STRONGIFY(self)

            // Get the updated schedule
            [self.automationStore getSchedule:scheduleID completionHandler:^(UAScheduleData *scheduleData) {
                UA_STRONGIFY(self)
                if (!scheduleData) {
                    return;
                }

                if (![scheduleData verifyState:UAScheduleStatePreparingSchedule]) {
                    return;
                }

                // Handle expired
                if ([scheduleData isExpired]) {
                    [self handleExpiredScheduleData:scheduleData];
                }


                UA_LTRACE(@"Schedule %@ prepare result %ld.", scheduleData.identifier, (long) prepareResult);

                switch (prepareResult) {
                    case UAAutomationSchedulePrepareResultCancel:
                        [self notifyDelegateOnScheduleCancelled:[self scheduleFromData:scheduleData]];
                        UA_LTRACE(@"Deleting schedule %@", scheduleData.identifier);
                        [scheduleData.managedObjectContext deleteObject:scheduleData];
                        break;
                    case UAAutomationSchedulePrepareResultContinue:
                        [scheduleData updateState:UAScheduleStateWaitingScheduleConditions];
                        [self attemptExecution:scheduleData];
                        break;
                    case UAAutomationSchedulePrepareResultSkip:
                        [scheduleData updateState:UAScheduleStateIdle];
                        break;
                    case UAAutomationSchedulePrepareResultInvalidate:
                        [self prepareSchedules:@[scheduleData]];
                        break;
                    case UAAutomationSchedulePrepareResultPenalize:
                    default:
                        [self scheduleFinishedExecuting:scheduleData];
                        break;
                }
            }];
        }];
    }
}

- (void)prepareScheduleWithIdentifier:(NSString *)scheduleID {
    UA_WEAKIFY(self)
    [self.automationStore getSchedule:scheduleID completionHandler:^(UAScheduleData *schedule) {
        UA_STRONGIFY(self)
        if (schedule) {
            [self prepareSchedules:@[schedule]];
        }
    }];
}

- (void)attemptExecution:(UAScheduleData *)scheduleData {

    if (![scheduleData verifyState:UAScheduleStateWaitingScheduleConditions])  {
        return;
    }

    // Verify the schedule is not expired
    if ([scheduleData isExpired]) {
        [self handleExpiredScheduleData:scheduleData];
        return;
    }

    UASchedule *schedule = [self scheduleFromData:scheduleData];

    if (!schedule) {
        return;
    }

    // Execution state must be read and written on the context's private queue
    __block UAScheduleState nextExecutionState = UAScheduleStateWaitingScheduleConditions;

    // Conditions and action executions must be run on the main queue.
    UA_WEAKIFY(self)
    [self.dispatcher doSync:^{
        UA_STRONGIFY(self)

        if (self.paused) {
            return;
        }

        if (![self isScheduleConditionsSatisfied:schedule.delay]) {
            UA_LDEBUG(@"Schedule %@ is not ready to execute. Conditions not satisfied", schedule.identifier);
            return;
        }

        id<UAAutomationEngineDelegate> delegate = self.delegate;

        switch ([delegate isScheduleReadyToExecute:schedule]) {
            case UAAutomationScheduleReadyResultInvalidate: {
                UA_LTRACE(@"Attempted to execute an invalid schedule %@", schedule.identifier);
                nextExecutionState = UAScheduleStatePreparingSchedule;
                [self prepareScheduleWithIdentifier:schedule.identifier];
                break;
            }
            case UAAutomationScheduleReadyResultContinue: {
                UA_LTRACE(@"Executing schedule %@", schedule.identifier);
                [delegate executeSchedule:schedule completionHandler:^{
                    UA_STRONGIFY(self)
                    [self.automationStore getSchedule:schedule.identifier completionHandler:^(UAScheduleData *scheduleData) {
                        UA_STRONGIFY(self)
                        [self scheduleFinishedExecuting:scheduleData];
                    }];
                }];

                nextExecutionState = UAScheduleStateExecuting;
                break;
            }
            case UAAutomationScheduleReadyResultNotReady: {
                UA_LTRACE(@"Schedule %@ not ready for execution", schedule.identifier);
                break;
            }
            case UAAutomationScheduleReadyResultSkip: {
                UA_LTRACE(@"Schedule %@ not ready for execution, resetting to idle", schedule.identifier);
                nextExecutionState = UAScheduleStateIdle;
                break;
            }
        }
    }];

    // Update execution state if necessary
    if (nextExecutionState != UAScheduleStateWaitingScheduleConditions) {
        [scheduleData updateState:nextExecutionState];
    }
}

- (void)handleExpiredScheduleData:(nonnull UAScheduleData *)scheduleData {
    UA_LTRACE(@"Schedule expired %@", scheduleData.identifier);
    [self notifyDelegateOnScheduleExpired:[self scheduleFromData:scheduleData]];
    [self finishSchedule:scheduleData];
}

- (void)finishSchedule:(UAScheduleData *)scheduleData {
    UA_LTRACE(@"Schedule finished %@", scheduleData.identifier);
    [scheduleData updateState:UAScheduleStateFinished];

    if ([scheduleData.editGracePeriod doubleValue] <= 0) {
        UA_LDEBUG(@"Deleting schedule %@", scheduleData.identifier);
        [scheduleData.managedObjectContext deleteObject:scheduleData];
    }
}

- (void)scheduleFinishedExecuting:(UAScheduleData *)scheduleData {
    if (!scheduleData) {
        return;
    }

    // Increment the count
    scheduleData.triggeredCount = @([scheduleData.triggeredCount integerValue] + 1);

    UA_LTRACE(@"Schedule %@ finished executing. Trigger count %@. Limit %@.", scheduleData.identifier, scheduleData.triggeredCount, scheduleData.limit);
    // Expired
    if ([scheduleData isExpired]) {
        [self handleExpiredScheduleData:scheduleData];
        return;
    }

    if ([scheduleData isOverLimit]) {
        // Over limit
        UA_LTRACE(@"Limit reached for schedule %@", scheduleData.identifier);
        [self finishSchedule:scheduleData];
        [self notifyDelegateOnScheduleLimitReached:[self scheduleFromData:scheduleData]];
    } else if ([scheduleData.interval doubleValue] > 0) {
        UA_LTRACE(@"Schedule %@ has an execution interval, scheduling task",  scheduleData.identifier);

        // Paused
        [scheduleData updateState:UAScheduleStatePaused];

        [self enqueueIntervalTaskForSchedule:scheduleData timeInterval:[scheduleData.interval doubleValue]];
    } else {
        UA_LTRACE(@"Schedule %@ is idle", scheduleData.identifier);
        [scheduleData updateState:UAScheduleStateIdle];
    }
}

- (void)notifyDelegateOnScheduleExpired:(nullable UASchedule *)schedule {
    if (!schedule) {
        return;
    }

    UA_WEAKIFY(self)
    [self.dispatcher dispatchAsync:^{
        UA_STRONGIFY(self)
        id<UAAutomationEngineDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(onScheduleExpired:)]) {
            [delegate onScheduleExpired:schedule];
        }
    }];
}

- (void)notifyDelegateOnScheduleCancelled:(nullable UASchedule *)schedule {
    if (!schedule) {
        return;
    }

    UA_WEAKIFY(self)
    [self.dispatcher dispatchAsync:^{
        UA_STRONGIFY(self)
        id<UAAutomationEngineDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(onScheduleCancelled:)]) {
            [delegate onScheduleCancelled:schedule];
        }
    }];
}

- (void)notifyDelegateOnScheduleLimitReached:(nullable UASchedule *)schedule {
    if (!schedule) {
        return;
    }

    UA_WEAKIFY(self)
    [self.dispatcher dispatchAsync:^{
        UA_STRONGIFY(self)
        id<UAAutomationEngineDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(onScheduleLimitReached:)]) {
            [delegate onScheduleLimitReached:schedule];
        }
    }];
}

#pragma mark -
#pragma mark Converters

- (NSArray<UASchedule *> *)schedulesFromData:(NSArray<UAScheduleData *> *)schedulesData {
    NSMutableArray *schedules = [NSMutableArray array];
    for (UAScheduleData *scheduleData in schedulesData) {
        UASchedule *schedule = [self scheduleFromData:scheduleData];
        if (schedule) {
            [schedules addObject:schedule];
        }
    }
    return schedules;
}

- (nullable UASchedule *)scheduleFromData:(UAScheduleData *)scheduleData {
    id dataJSON = [UAJSONUtils objectWithString:scheduleData.data];
    if (!dataJSON) {
        UA_LERR(@"Invalid schedule. Deleting %@", scheduleData.identifier);
        [scheduleData.managedObjectContext deleteObject:scheduleData];
        return nil;
    }

    UAScheduleAudience *audience;
    if (scheduleData.audience) {
        NSError *audienceError;
        id audienceJSON = [UAJSONUtils objectWithString:scheduleData.audience];
        audience = [UAScheduleAudience audienceWithJSON:audienceJSON error:&audienceError];
        if (!audience || audienceError) {
            UA_LERR(@"Invalid schedule. Deleting %@ - %@", scheduleData.identifier, audienceError);
            [scheduleData.managedObjectContext deleteObject:scheduleData];
            return nil;
        }
    }

    UASchedule *schedule = [UAAutomationEngine scheduleWithType:[scheduleData.type unsignedIntegerValue]
                                                       dataJSON:dataJSON
                                                   builderBlock:^(UAScheduleBuilder * _Nonnull builder) {
        builder.triggers = [UAAutomationEngine triggersFromData:scheduleData.triggers];
        builder.delay = [UAAutomationEngine delayFromData:scheduleData.delay];
        builder.group = scheduleData.group;
        builder.start = scheduleData.start;
        builder.end = scheduleData.end;
        builder.priority = [scheduleData.priority integerValue];
        builder.limit = [scheduleData.limit unsignedIntegerValue];
        builder.interval = [scheduleData.interval doubleValue];
        builder.editGracePeriod = [scheduleData.editGracePeriod doubleValue];
        builder.metadata = [UAJSONUtils objectWithString:scheduleData.metadata];
        builder.identifier = scheduleData.identifier;
        builder.audience = audience;
        builder.campaigns= scheduleData.campaigns;
        builder.reportingContext = scheduleData.reportingContext;
        builder.frequencyConstraintIDs = scheduleData.frequencyConstraintIDs;
    }];

    if (![schedule isValid]) {
        UA_LERR(@"Invalid schedule. Deleting %@", scheduleData.identifier);
        [scheduleData.managedObjectContext deleteObject:scheduleData];
        return nil;
    } else {
        return schedule;
    }
}


+ (UASchedule *)scheduleWithType:(UAScheduleType)scheduleType
                        dataJSON:(id)JSON
                    builderBlock:(void(^)(UAScheduleBuilder *builder))builderBlock {

    switch (scheduleType) {
        case UAScheduleTypeInAppMessage: {
            NSError *error;
            UAInAppMessage *message = [UAInAppMessage messageWithJSON:JSON error:&error];
            if (!error && message) {
                return [UAInAppMessageSchedule scheduleWithMessage:message
                                                      builderBlock:builderBlock];
            } else {
                UA_LERR(@"Invalid schedule data: %@ error: %@", JSON, error);
                return nil;
            }
        }

        case UAScheduleTypeActions: {
            return [UAActionSchedule scheduleWithActions:JSON builderBlock:builderBlock];
        }

        case UAScheduleTypeDeferred: {
            NSError *error;
            UAScheduleDeferredData *deferred = [UAScheduleDeferredData deferredDataWithJSON:JSON
                                                                                      error:&error];
            if (!error && deferred) {
                return [UADeferredSchedule scheduleWithDeferredData:deferred
                                                       builderBlock:builderBlock];
            } else {
                UA_LERR(@"Invalid schedule data: %@ error: %@", JSON, error);
                return nil;
            }
        }
    }
    UA_LERR(@"Unexpected type %lu", scheduleType);
    return nil;
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

+ (UAScheduleTrigger *)triggerFromData:(UAScheduleTriggerData *)data {
    if (!data) {
        return nil;
    }

    UAScheduleTrigger *trigger = [UAScheduleTrigger triggerWithType:(UAScheduleTriggerType)[data.type integerValue]
                                                               goal:data.goal
                                                          predicate:[UAAutomationEngine predicateFromData:data.predicateData]];

    return trigger;
}

+ (UAJSONPredicate *)predicateFromData:(NSData *)data {
    if (!data) {
        return nil;
    }

    id json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
    return [[UAJSONPredicate alloc] initWithJSON:json error:nil];
}

+ (void)applyEdits:(UAScheduleEdits *)edits toData:(UAScheduleData *)scheduleData {
    if (edits.data && edits.type) {
        scheduleData.data = edits.data;
        scheduleData.type = edits.type;
    }

    if (edits.start) {
        scheduleData.start = edits.start;
    }

    if (edits.end) {
        scheduleData.end = edits.end;
    }

    if (edits.interval) {
        scheduleData.interval = edits.interval;
    }

    if (edits.editGracePeriod) {
        scheduleData.editGracePeriod = edits.editGracePeriod;
    }

    if (edits.limit) {
        scheduleData.limit = edits.limit;
    }

    if (edits.priority) {
        scheduleData.priority = edits.priority;
    }

    if (edits.metadata) {
        scheduleData.metadata = [UAJSONUtils stringWithObject:edits.metadata];
    }

    if (edits.audience) {
        scheduleData.audience = [UAJSONUtils stringWithObject:[edits.audience toJSON]];
    }

    if (edits.campaigns) {
        scheduleData.campaigns = edits.campaigns;
    }
    
    if (edits.reportingContext) {
        scheduleData.reportingContext = edits.reportingContext;
    }

    if (edits.frequencyConstraintIDs) {
        scheduleData.frequencyConstraintIDs = edits.frequencyConstraintIDs;
    }
}

@end
