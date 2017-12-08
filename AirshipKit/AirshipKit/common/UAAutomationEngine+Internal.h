/* Copyright 2017 Urban Airship and Contributors */

#import "UAAutomationEngine.h"
#import "UAAutomationStore+Internal.h"
#import "UAAnalytics+Internal.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Schedule execution states.
 */
typedef NS_ENUM(NSUInteger, UAScheduleState) {

    /**
     * Schedule is idle.
     */
    UAScheduleStateIdle = 0,

    /**
     * Schedule is pending execution.
     */
    UAScheduleStatePendingExecution = 1,

    /**
     * Schedule is executing.
     */
    UAScheduleStateExecuting = 2
};

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
 * @param limit Maximum schedules to maintain
 * @return Initialized Automation Engine instance
 */
+ (instancetype)automationEngineWithAutomationStore:(UAAutomationStore *)automationStore scheduleLimit:(NSUInteger)limit;

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
- (void)scheduleMultiple:(NSArray<UAScheduleInfo *> *)scheduleInfos completionHandler:(void (^)(void))completionHandler;

/**
 * Called when one of the schedule conditions changes.
 */
- (void)scheduleConditionsChanged;

/**
 * Cancels a schedule with the given identifier.
 *
 * @param identifier A schedule identifier.
 */
- (void)cancelScheduleWithIdentifier:(NSString *)identifier;

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
- (void)getScheduleWithIdentifier:(NSString *)identifier
                completionHandler:(void (^)(UASchedule * __nullable))completionHandler;

/**
 * Gets all schedules.
 *
 * @param completionHandler The completion handler with the result.
 */
- (void)getSchedules:(void (^)(NSArray<UASchedule *> *))completionHandler;

/**
 * Gets all schedules of the given group.
 *
 * @param group The schedule group.
 * @param completionHandler The completion handler with the result.
 */
- (void)getSchedulesWithGroup:(NSString *)group
            completionHandler:(void (^)(NSArray<UASchedule *> *))completionHandler;

@end

NS_ASSUME_NONNULL_END

