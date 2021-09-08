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
#import "UAActionSchedule.h"
#import "UAInAppMessageSchedule.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Provides a control interface for creating, canceling and executing in-app automations.
 */
NS_SWIFT_NAME(InAppAutomation)
@interface UAInAppAutomation : NSObject<UAComponent>

/**
 * The shared InAppAutomation instance.
 */
@property (class, nonatomic, readonly, null_unspecified) UAInAppAutomation *shared;

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
 * @param completionHandler A completion handler called with the result.
 */
- (void)cancelScheduleWithID:(NSString *)scheduleID
           completionHandler:(nullable void (^)(BOOL))completionHandler;

/**
 * Cancels in-app automations with the specified group identifier.
 *
 * @param group The group.
 * @param completionHandler A completion handler called with the result.
 */
- (void)cancelSchedulesWithGroup:(NSString *)group
               completionHandler:(nullable void (^)(BOOL))completionHandler;

/**
 * Cancels action in-app automations with the specified group identifier.
 *
 * @param group The group.
 * @param completionHandler A completion handler called with the result.
 */
- (void)cancelActionSchedulesWithGroup:(NSString *)group
                     completionHandler:(nullable void (^)(BOOL))completionHandler;

/**
 * Cancels message schedules with the specified group identifier.
 *
 * @param group The group.
 * @param completionHandler A completion handler called with the result.
 */
- (void)cancelMessageSchedulesWithGroup:(NSString *)group
                      completionHandler:(nullable void (^)(BOOL))completionHandler;

/**
 * Gets the action in-app automation with the provided identifier.
 *
 * @param identifier The scheduler identifier corresponding to the in-app message to be fetched.
 * @param completionHandler The completion handler to be called when fetch operation completes.
 */
- (void)getActionScheduleWithID:(NSString *)identifier
               completionHandler:(void (^)(UAActionSchedule * _Nullable))completionHandler;

/**
 * Gets action in-app automations with the provided group.
 *
 * @param group The group.
 * @param completionHandler The completion handler to be called when fetch operation completes.
 */
- (void)getActionSchedulesWithGroup:(NSString *)group
                  completionHandler:(void (^)(NSArray<UAActionSchedule *> *))completionHandler;

/**
 * Gets all action in-app automations.
 *
 * @param completionHandler The completion handler to be called when fetch operation completes.
 */
- (void)getActionSchedules:(void (^)(NSArray<UAActionSchedule *> *))completionHandler;

/**
 * Gets the message in-app automation with the provided identifier.
 *
 * @param identifier The scheduler identifier corresponding to the in-app message to be fetched.
 * @param completionHandler The completion handler to be called when fetch operation completes.
 */
- (void)getMessageScheduleWithID:(NSString *)identifier
               completionHandler:(void (^)(UAInAppMessageSchedule * _Nullable))completionHandler;

/**
 * Gets the message in-app automations with the provided group.
 *
 * @param group The group.
 * @param completionHandler The completion handler to be called when fetch operation completes.
 */
- (void)getMessageSchedulesWithGroup:(NSString *)group
                   completionHandler:(void (^)(NSArray<UAInAppMessageSchedule *> *))completionHandler;

/**
 * Get all message in-app automations.
 *
 * @param completionHandler The completion handler to be called when fetch operation completes.
 */
- (void)getMessageSchedules:(void (^)(NSArray<UAInAppMessageSchedule *> *))completionHandler;

/**
 * Get all in-app automations.
 * @param completionHandler The completion handler to be called when fetch operation completes.
 */
- (void)getSchedules:(void (^)(NSArray<UASchedule *> *))completionHandler;

/**
 * Edits a schedule.
 *
 * @param identifier A schedule identifier.
 * @param edits The edits to apply.
 * @param completionHandler The completion handler with the result.
 */
- (void)editScheduleWithID:(NSString *)identifier
                     edits:(UAScheduleEdits *)edits
         completionHandler:(nullable void (^)(BOOL))completionHandler;

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
