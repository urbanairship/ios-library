/* Copyright 2017 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppMessage.h"
#import "UAInAppMessageScheduleInfo.h"
#import "UAInAppMessageAdapterProtocol.h"
#import "UAAutomationEngine.h"
#import "UAComponent.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * In-app message manager provides a control interface for creating,
 * canceling and executing in-app message schedules.
 */
@interface UAInAppMessageManager : UAComponent <UAAutomationEngineDelegate>

/**
 * Allows setting factory blocks that builds InAppMessageAdapters for each given display type.
 *
 * @param displayType The display type.
 * @param factory The adapter factory.
 */
- (void)setFactoryBlock:(id<UAInAppMessageAdapterProtocol> (^_Nonnull)(NSString* displayType))factory
         forDisplayType:(NSString *)displayType;

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
- (void)cancelMessageWithScheduleID:(NSString *)scheduleID;

/**
 * Cancels an in-app message via its identifier.
 *
 * @param identifier The identifier of the in-app message to be canceled.
 */
- (void)cancelMessageWithID:(NSString *)identifier;

/**
 * Cancels multiple in-app messages via their identifiers.
 *
 * @param identifiers The identifiers of the in-app messages to be canceled.
 */
-(void)cancelMessagesWithIDs:(NSArray<NSString *> *)identifiers;

@end

NS_ASSUME_NONNULL_END
