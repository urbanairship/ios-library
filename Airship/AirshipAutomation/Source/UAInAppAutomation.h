/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppMessage.h"
#import "UAInAppMessageScheduleInfo.h"
#import "UASchedule.h"
#import "UAInAppMessageAdapterProtocol.h"
#import "UAInAppMessageScheduleEdits.h"
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
 * In-app message manager.
 */
@property(nonatomic, readonly, strong) UAInAppMessageManager *inAppMessageManager;

/**
 * Schedules an in-app message.
 *
 * @param scheduleInfo The schedule info for the message.
 * @param completionHandler The completion handler to be called when scheduling completes.
 */
- (void)scheduleMessageWithScheduleInfo:(UAInAppMessageScheduleInfo *)scheduleInfo
                      completionHandler:(void (^)(UASchedule *))completionHandler;

/**
 * Schedules an in-app message.
 *
 * @param scheduleInfo The schedule info for the message.
 * @param metadata The schedule optional metadata.
 * @param completionHandler The completion handler to be called when scheduling completes.
 */
- (void)scheduleMessageWithScheduleInfo:(UAInAppMessageScheduleInfo *)scheduleInfo
                               metadata:(nullable NSDictionary *)metadata
                      completionHandler:(void (^)(UASchedule *))completionHandler;

/**
 * Schedules multiple in-app messages.
 *
 * @param scheduleInfos The schedule info for the messages.
 * @param metadata The schedules' optional metadata.
 * @param completionHandler The completion handler to be called when scheduling completes.
 */
- (void)scheduleMessagesWithScheduleInfo:(NSArray<UAInAppMessageScheduleInfo *> *)scheduleInfos
                                metadata:(nullable NSDictionary *)metadata
                       completionHandler:(void (^)(NSArray <UASchedule *> *))completionHandler;

/**
 * Cancels an in-app message via its schedule identifier.
 *
 * @param scheduleID The schedule ID for the message to be canceled.
 */
- (void)cancelScheduleWithID:(NSString *)scheduleID;

/**
 * Cancels an in-app message via its schedule identifier.
 *
 * @param scheduleID The schedule ID for the message to be canceled.
 * @param completionHandler A completion handler called with the schedule that was canceled, or nil if the schedule was not found.
 */
- (void)cancelScheduleWithID:(NSString *)scheduleID completionHandler:(nullable void (^)(UASchedule * _Nullable))completionHandler;

/**
 * Cancels in-app messages with the specified group identifier.
 *
 * @param identifier The message ID.
 */
- (void)cancelMessagesWithID:(NSString *)identifier;

/**
 * Cancels in-app messages with the specified group identifier.
 *
 * @param identifier The message ID.
 * @param completionHandler A completion handler called with an array of message schedules that were canceled.
 * If no messages matching the provided identifier are found, this array will be empty.
 */
- (void)cancelMessagesWithID:(NSString *)identifier completionHandler:(nullable void (^)(NSArray <UASchedule *> *))completionHandler;

/**
 * Gets schedules with the provided identifier.
 *
 * @param identifier The scheduler identifier corresponding to the in-app message to be fetched.
 * @param completionHandler The completion handler to be called when fetch operation completes.
 */
- (void)getScheduleWithID:(NSString *)identifier completionHandler:(void (^)(UASchedule * _Nullable))completionHandler;

/**
 * Gets schedules whose group is the provided message ID.
 *
 * @param messageID The message ID.
 * @param completionHandler The completion handler to be called when fetch operation completes.
 */
- (void)getSchedulesWithMessageID:(NSString *)messageID completionHandler:(void (^)(NSArray<UASchedule *> *))completionHandler;

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
                     edits:(UAInAppMessageScheduleEdits *)edits
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
- (void)checkAudience:(UAInAppMessageAudience *)audience completionHandler:(void (^)(BOOL, NSError * _Nullable))completionHandler;


@end

NS_ASSUME_NONNULL_END
