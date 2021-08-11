/* Copyright Airship and Contributors */

#import <UIKit/UIKit.h>
#import "UAAutomationStore+Internal.h"
#import "UAScheduleEdits.h"
#import "UASchedule.h"
#import "UAAirshipAutomationCoreImport.h"

@class UAAppStateTracker;
@class UAScheduleTriggerContext;
@class UANetworkMonitor;
@class UADispatcher;
@class UATaskManager;
@class UADate;

NS_ASSUME_NONNULL_BEGIN

/**
 * Prepare results
 */
typedef NS_ENUM(NSInteger, UAAutomationSchedulePrepareResult) {
    /**
     * Schedule should continue executing.
     */
    UAAutomationSchedulePrepareResultContinue,

    /**
     * Schedule should skip executing.
     */
    UAAutomationSchedulePrepareResultSkip,

    /**
     * Schedule should skip executing. The schedule's execution count should be incremented
     * and its execution interval should be handled.
     */
    UAAutomationSchedulePrepareResultPenalize,

    /**
     * Schedule should be marked invalidated due to stale metadata.
     */
    UAAutomationSchedulePrepareResultInvalidate,

    /**
     * Schedule should be cancelled.
     */
    UAAutomationSchedulePrepareResultCancel
};

/**
 * Ready results
 */
typedef NS_ENUM(NSInteger, UAAutomationScheduleReadyResult) {
    /**
     * Schedule should skip executing.
     */
    UAAutomationScheduleReadyResultNotReady,

    /**
     * Schedule is ready for execution.
     */
    UAAutomationScheduleReadyResultContinue,

    /**
     * Schedule is out of date and should be prepared again before it's able to be ready for execution.
     */
    UAAutomationScheduleReadyResultInvalidate,

    /**
     * Schedule has exceeded frequency limits and should be skipped
     */
    UAAutomationScheduleReadyResultSkip
};

/**
 * Automation engine delegate
 */
@protocol UAAutomationEngineDelegate <NSObject>

/**
 * Prepares the schedule.
 *
 * @param schedule The schedule.
 * @param triggerContext The trigger context.
 * @param completionHandler Completion handler when the schedule is finished preparing.
 */
- (void)prepareSchedule:(UASchedule *)schedule
         triggerContext:(nullable UAScheduleTriggerContext *)triggerContext
      completionHandler:(void (^)(UAAutomationSchedulePrepareResult))completionHandler;

/**
 * Checks if a schedule is ready to execute.
 *
 * @param schedule The schedule.
 * @returns Ready result of the schedule should be executed.
 */
- (UAAutomationScheduleReadyResult)isScheduleReadyToExecute:(UASchedule *)schedule;

/**
 * Executes a schedule.
 *
 * @param schedule The schedule.
 * @param completionHandler Completion handler when the schedule is finished executing.
 */
- (void)executeSchedule:(nonnull UASchedule *)schedule
      completionHandler:(void (^)(void))completionHandler;

@optional

/**
 * Called when a schedule is expired.
 * @param schedule The schedule.
 */
- (void)onScheduleExpired:(nonnull UASchedule *)schedule;

/**
 * Called when a schedule is cancelled.
 * @param schedule The schedule.
 */
- (void)onScheduleCancelled:(nonnull UASchedule *)schedule;

/**
 * Called when a schedule's limit is reached.
 * @param schedule The schedule.
 */
- (void)onScheduleLimitReached:(nonnull UASchedule *)schedule;

/**
 * Called when a new automation is scheduled.
 * @param schedule The schedule.
 */
- (void)onNewSchedule:(nonnull UASchedule *)schedule;


/**
 * Called when a schedule was interrupted by the app terminating. Called on next app init.
 * @param schedule The schedule.
 */
- (void)onExecutionInterrupted:(nonnull UASchedule *)schedule;

@end


/**
 * Automation engine.
 */
@interface UAAutomationEngine : NSObject

/**
 * Automation engine delegate.
 */
@property (nonatomic, weak) id<UAAutomationEngineDelegate> delegate;

/**
 * Automation engine Core Data store.
 */
@property (nonatomic, strong) UAAutomationStore *automationStore;

/**
 * Automation Engine constructor.
 *
 * @param automationStore An initialized UAAutomationStore
 * @return Initialized Automation Engine instance
 */
+ (instancetype)automationEngineWithAutomationStore:(UAAutomationStore *)automationStore;

/**
 * Automation Engine constructor. Used for testing.
 *
 * @param automationStore An initialized UAAutomationStore
 * @param appStateTracker An app state tracker.
 * @param taskManager The task manager.
 * @param networkMonitor The network monitor.
 * @param notificationCenter The notification center.
 * @param dispatcher The dispatcher to dispatch main queue blocks.
 * @param application The main application.
 * @param date The UADate instance.
 *
 * @return Initialized Automation Engine instance
 */
+ (instancetype)automationEngineWithAutomationStore:(UAAutomationStore *)automationStore
                                    appStateTracker:(UAAppStateTracker *)appStateTracker
                                        taskManager:(UATaskManager *)taskManager
                                     networkMonitor:(UANetworkMonitor *)networkMonitor
                                 notificationCenter:(NSNotificationCenter *)notificationCenter
                                         dispatcher:(UADispatcher *)dispatcher
                                        application:(UIApplication *)application
                                               date:(UADate *)date;

/**
 * Starts the Automation Engine.
 */
- (void)start;

/**
 * Stops the Automation Engine.
 */
- (void)stop;

/**
 * Pauses the Automation Engine.
 */
- (void)pause;

/**
 * Resumes the Automation Engine.
 */
- (void)resume;

/**
 * Schedules an in-app automation.
 *
 * @param schedule The schedule.
 * @param completionHandler A completion handler.
 */
- (void)schedule:(UASchedule *)schedule completionHandler:(nullable void (^)(BOOL))completionHandler;

/**
 * Schedules multiple in-app automations.
 *
 * @param schedules The schedules.
 * @param completionHandler A completion handler.
 */
- (void)scheduleMultiple:(NSArray<UASchedule *> *)schedules
       completionHandler:(nullable void (^)(BOOL))completionHandler;

/**
 * Called when one of the schedule conditions changes.
 */
- (void)scheduleConditionsChanged;

/**
 * Cancels a schedule with the given identifier.
 *
 * @param identifier A schedule identifier.
 * @param completionHandler A completion handler called with the result.
 */
- (void)cancelScheduleWithID:(NSString *)identifier
           completionHandler:(nullable void (^)(BOOL))completionHandler;

/**
 * Cancels all schedules of the given group and type.
 *
 * @param group A schedule group.
 * @param scheduleType The schedule type.
 * @param completionHandler A completion handler called with the result.
 */
- (void)cancelSchedulesWithGroup:(NSString *)group
                            type:(UAScheduleType)scheduleType
               completionHandler:(nullable void (^)(BOOL))completionHandler;

/**
 * Cancels all schedules of the given group.
 *
 * @param group A schedule group.
 * @param completionHandler A completion handler called with the result.
 */
- (void)cancelSchedulesWithGroup:(NSString *)group
               completionHandler:(nullable void (^)(BOOL))completionHandler;

/**
 * Cancels all schedules of the given type.
 *
 * @param scheduleType The schedule type.
 * @param completionHandler A completion handler called with the result.
 */
- (void)cancelSchedulesWithType:(UAScheduleType)scheduleType
              completionHandler:(nullable void (^)(BOOL))completionHandler;

/**
 * Gets the schedule with the given identifier and type.
 *
 * @param identifier A schedule identifier.
 * @param scheduleType The schedule type.
 * @param completionHandler The completion handler with the result.
 */
- (void)getScheduleWithID:(NSString *)identifier
                     type:(UAScheduleType)scheduleType
        completionHandler:(void (^)(UASchedule * _Nullable))completionHandler;

/**
 * Gets all schedules of the given type.
 *
 * @param scheduleType The schedule type..
 * @param completionHandler The completion handler with the result.
 */
- (void)getSchedulesWithType:(UAScheduleType)scheduleType
           completionHandler:(void (^)(NSArray<UASchedule *> *))completionHandler;

/**
 * Gets all schedules.
 *
 * @param completionHandler The completion handler with the result.
 */
- (void)getSchedules:(void (^)(NSArray<UASchedule *> *))completionHandler;

/**
 * Gets all schedules of the given group and type.
 *
 * @param group The schedule group.
 * @param scheduleType The schedule type.
 * @param completionHandler The completion handler with the result.
 */
- (void)getSchedulesWithGroup:(NSString *)group
                         type:(UAScheduleType)scheduleType
            completionHandler:(void (^)(NSArray<UASchedule *> *))completionHandler;

/**
 * Edits a schedule.
 *
 * @param identifier A schedule identifier.
 * @param edits The edits to apply.
 * @param completionHandler The completion handler with the result.
 */
- (void)editScheduleWithID:(NSString *)identifier
                     edits:(UAScheduleEdits *)edits
         completionHandler:(void (^)(BOOL))completionHandler;

@end

NS_ASSUME_NONNULL_END


