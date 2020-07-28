/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppMessage.h"
#import "UASchedule.h"
#import "UAInAppMessageAdapterProtocol.h"
#import "UAScheduleEdits.h"
#import "UAInAppMessageDisplayCoordinator.h"
#import "UAInAppMessageAssetManager.h"
#import "UAAirshipAutomationCoreImport.h"
#import "UAInAppMessageManager.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Provides a control interface for creating, canceling and executing in-app automations.
 */
@interface UAInAppAutomation : UAComponent

/**
 * In-app automation enable flag.
 */
@property (nonatomic, assign, getter=isEnabled) BOOL enabled;

/**
 * In-app automation pause flag.
 */
@property (nonatomic, assign, getter=isPaused) BOOL paused;

/**
 * In-app automation manager.
 */
@property(nonatomic, readonly, strong) UAInAppMessageManager *inAppMessageManager;

/**
 * Schedules an in-app automation.
 *
 * @param schedule The schedule.
 * @param completionHandler The completion handler to be called when scheduling completes.
 */
- (void)schedule:(UASchedule *)schedule completionHandler:(void (^)(BOOL))completionHandler;

/**
 * Schedules multiple in-app automations.
 *
 * @param schedules The schedules.
 * @param completionHandler The completion handler to be called when scheduling completes.
 */
- (void)scheduleMultiple:(NSArray<UASchedule *> *)schedules
       completionHandler:(void (^)(BOOL))completionHandler;

/**
 * Cancels an in-app automation via its schedule identifier.
 *
 * @param scheduleID The schedule ID.
 * @param completionHandler A completion handler called with the schedule that was canceled, or nil if the schedule was not found.
 */
- (void)cancelScheduleWithID:(NSString *)scheduleID
           completionHandler:(nullable void (^)(UASchedule * _Nullable))completionHandler;

/**
 * Cancels in-app automations with the specified group identifier.
 *
 * @param group The group.
 * @param completionHandler A completion handler called with an array of schedules that were canceled.
 * If no schedules matching the provided identifier are found, this array will be empty.
 */
- (void)cancelSchedulesWithGroup:(NSString *)group
               completionHandler:(nullable void (^)(NSArray <UASchedule *> *))completionHandler;

/**
 * Gets schedules with the provided identifier.
 *
 * @param identifier The scheduler identifier corresponding to the in-app message to be fetched.
 * @param completionHandler The completion handler to be called when fetch operation completes.
 */
- (void)getScheduleWithID:(NSString *)identifier
        completionHandler:(void (^)(UASchedule * _Nullable))completionHandler;

/**
 * Gets schedules whose group is the provided group..
 *
 * @param group The group.
 * @param completionHandler The completion handler to be called when fetch operation completes.
 */
- (void)getSchedulesWithGroup:(NSString *)group
            completionHandler:(void (^)(NSArray<UASchedule *> *))completionHandler;

/**
 * Gets all schedules, including schedules that have ended.
 *
 * @param completionHandler The completion handler to be called when fetch operation completes.
 */
- (void)getAllSchedules:(void (^)(NSArray<UASchedule *> *))completionHandler;

/**
 * Edits a schedule.
 *
 * @param identifier A schedule identifier.
 * @param edits The edits to apply.
 * @param completionHandler The completion handler with the result.
 */
- (void)editScheduleWithID:(NSString *)identifier
                     edits:(UAScheduleEdits *)edits
         completionHandler:(void (^)(UASchedule * _Nullable))completionHandler;

/**
 * Check display audience conditions.
 *
 * @param audience The specified audience
 * @param completionHandler Passed `YES` if the current user is a member of the specified audience,
 *                                 `NO` if the current user is not a member of the specified audience.
 *                                 Error is non-nil if there was an error evaluating the audience.
 * @note For internal use only. :nodoc:
 */
- (void)checkAudience:(UAScheduleAudience *)audience
    completionHandler:(void (^)(BOOL, NSError * _Nullable))completionHandler;


@end

NS_ASSUME_NONNULL_END
