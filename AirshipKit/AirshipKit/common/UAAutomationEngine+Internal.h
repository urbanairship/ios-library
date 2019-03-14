/* Copyright Urban Airship and Contributors */

#import <UIKit/UIKit.h>
#import "UAAutomationStore+Internal.h"
#import "UAAnalytics+Internal.h"
#import "UAScheduleEdits.h"
#import "UASchedule.h"
#import "UAScheduleInfo.h"
#import "UATimerScheduler+Internal.h"
#import "UADispatcher+Internal.h"

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
     * Schedule should be cancelled.
     */
    UAAutomationSchedulePrepareResultCancel
};

/**
 * Automation engine delegate
 */
@protocol UAAutomationEngineDelegate <NSObject>

/**
 * Creates a schedule info from a builder.
 *
 * @param builder The schedule info builder.
 * @returns Schedule info.
 */
- (UAScheduleInfo *)createScheduleInfoWithBuilder:(UAScheduleInfoBuilder *)builder;

/**
 * Prepares the schedule.
 *
 * @param schedule The schedule.
 * @param completionHandler Completion handler when the schedule is finished preparing.
 */
- (void)prepareSchedule:(UASchedule *)schedule
      completionHandler:(void (^)(UAAutomationSchedulePrepareResult))completionHandler;

/**
 * Checks if a schedule is ready to execute.
 *
 * @param schedule The schedule.
 * @returns `YES` if the schedule should be executed, otherwise `NO`.
 */
- (BOOL)isScheduleReadyToExecute:(UASchedule *)schedule;

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
 */
- (void)scheduleExpired:(nonnull UASchedule *)schedule;

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
 * @param timerScheduler A timer scheduler
 * @param notificationCenter The notification center.
 * @param dispatcher The dispatcher to dispatch main queue blocks.
 * @param application The main application.
 * @param date The UADate instance.
 *
 * @return Initialized Automation Engine instance
 */
+ (instancetype)automationEngineWithAutomationStore:(UAAutomationStore *)automationStore
                                     timerScheduler:(UATimerScheduler *)timerScheduler
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
 * Schedules a single schedule.
 *
 * @param scheduleInfo The schedule information.
 * @param completionHandler A completion handler.
 * If the schedule info is invalid, the schedule will be nil.
 */
- (void)schedule:(UAScheduleInfo *)scheduleInfo completionHandler:(nullable void (^)(UASchedule * __nullable))completionHandler;

/**
 * Schedules multiple schedules.
 *
 * @param scheduleInfos The schedule information.
 * @param completionHandler A completion handler.
 * Note: If any schedule info is invalid, that schedule won't be scheduled and it will be [NSNull null] in the schedules
 *       returned in the completionHandler.
 */
- (void)scheduleMultiple:(NSArray<UAScheduleInfo *> *)scheduleInfos completionHandler:(void (^)(NSArray <UASchedule *> *))completionHandler;

/**
 * Called when one of the schedule conditions changes.
 */
- (void)scheduleConditionsChanged;

/**
 * Cancels a schedule with the given identifier.
 *
 * @param identifier A schedule identifier.
 */
- (void)cancelScheduleWithID:(NSString *)identifier;

/**
 * Cancels all schedules of the given group.
 *
 * @param group A schedule group.
 */
- (void)cancelSchedulesWithGroup:(NSString *)group;

/**
 * Cancels all schedules.
 */
- (void)cancelAll;

/**
 * Gets the schedule with the given identifier.
 *
 * @param identifier A schedule identifier.
 * @param completionHandler The completion handler with the result.
 */
- (void)getScheduleWithID:(NSString *)identifier
        completionHandler:(void (^)(UASchedule * __nullable))completionHandler;

/**
 * Gets all unended schedules.
 *
 * @param completionHandler The completion handler with the result.
 */
- (void)getSchedules:(void (^)(NSArray<UASchedule *> *))completionHandler;

/**
 * Gets all schedules, including schedules that have ended.
 *
 * @param completionHandler The completion handler with the result.
 */
- (void)getAllSchedules:(void (^)(NSArray<UASchedule *> *))completionHandler;

/**
 * Gets all schedules of the given group.
 *
 * @param group The schedule group.
 * @param completionHandler The completion handler with the result.
 */
- (void)getSchedulesWithGroup:(NSString *)group
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
         completionHandler:(void (^)(UASchedule * __nullable))completionHandler;

@end

NS_ASSUME_NONNULL_END

