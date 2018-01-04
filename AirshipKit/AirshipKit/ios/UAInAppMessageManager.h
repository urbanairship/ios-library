/* Copyright 2017 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppMessage.h"
#import "UAInAppMessageScheduleInfo.h"
#import "UASchedule.h"
#import "UAInAppMessageAdapterProtocol.h"
#import "UAComponent.h"
#import "UAInAppMessageScheduleEdits.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Delegate protocol for receiving in-app messaging related
 * callbacks.
 */
@protocol UAInAppMessagingDelegate <NSObject>

@optional

///---------------------------------------------------------------------------------------
/// @name In App Messaging Delegate Methods
///---------------------------------------------------------------------------------------

/**
 * Indicates that an in-app message will be displayed.
 * @param message The associated in-app message.
 */
- (void)messageWillBeDisplayed:(UAInAppMessage *)message;

/**
 * Indicates that an in-app message has been dismissed.
 */
- (void)messageDismissed:(UAInAppMessage *)message;

@end

/**
 * In-app message manager provides a control interface for creating,
 * canceling and executing in-app message schedules.
 */
@interface UAInAppMessageManager : UAComponent

/**
 * In-app message enable flag.
 */
@property (nonatomic, assign, getter=isEnabled) BOOL enabled;

/**
 * In-app messaging delegate.
 */
@property (nonatomic, weak) id<UAInAppMessagingDelegate> delegate;

/**
 * Allows setting factory blocks that builds InAppMessageAdapters for each given display type.
 *
 * @param displayType The display type.
 * @param factory The adapter factory.
 */
- (void)setFactoryBlock:(id<UAInAppMessageAdapterProtocol> (^)(UAInAppMessage* message))factory
         forDisplayType:(UAInAppMessageDisplayType)displayType;

/**
 * Schedules an in-app message.
 *
 * @param scheduleInfo The schedule info for the message.
 * @param completionHandler The completion handler to be called when scheduling completes.
 */
- (void)scheduleMessageWithScheduleInfo:(UAInAppMessageScheduleInfo *)scheduleInfo
                      completionHandler:(void (^)(UASchedule *))completionHandler;

/**
 * Schedules multiple in-app messages.
 *
 * @param scheduleInfos The schedule info for the messages.
 * @param completionHandler The completion handler to be called when scheduling completes.
 */
- (void)scheduleMessagesWithScheduleInfo:(NSArray<UAInAppMessageScheduleInfo *> *)scheduleInfos
                       completionHandler:(void (^)(void))completionHandler;

/**
 * Cancels an in-app message via its schedule info.
 *
 * @param scheduleID The schedule ID for the message to be canceled.
 */
- (void)cancelScheduleWithID:(NSString *)scheduleID;

/**
 * Cancels in-app messages with the spcified message ID.
 *
 * @param identifier The message ID.
 */
- (void)cancelMessagesWithID:(NSString *)identifier;

/**
 * Gets schedules with the provided identifier.
 *
 * @param identifier The scheduler identifier corresponding to the in-app message to be canceled.
 * @param completionHandler The completion handler to be called when fetch operation completes.
 */
- (void)getScheduleWithID:(NSString *)identifier completionHandler:(void (^)(UASchedule *))completionHandler;

/**
 * Gets schedules whose group is the provided message ID.
 *
 * @param messageID The message ID.
 * @param completionHandler The completion handler to be called when fetch operation completes.
 */
- (void)getSchedulesWithMessageID:(NSString *)messageID completionHandler:(void (^)(NSArray<UASchedule *> *))completionHandler;

/**
 * Edits a schedule.
 *
 * @param identifier A schedule identifier.
 * @param edits The edits to apply.
 * @param completionHandler The completion handler with the result.
 */
- (void)editScheduleWithID:(NSString *)identifier
                     edits:(UAInAppMessageScheduleEdits *)edits
         completionHandler:(void (^)(UASchedule * __nullable))completionHandler;

@end

NS_ASSUME_NONNULL_END
