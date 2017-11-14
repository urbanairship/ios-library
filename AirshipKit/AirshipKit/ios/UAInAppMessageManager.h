/* Copyright 2017 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppMessage.h"
#import "UAInAppMessageScheduleInfo.h"
#import "UAInAppMessageAdapterProtocol.h"
#import "UAAutomationEngine.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * In-app message manager provides a control interface for creating,
 * canceling and executing in-app message schedules.
 */
@interface UAInAppMessageManager : NSObject <UAAutomationEngineDelegate>

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
-(void)cancelMessageWithID:(NSString *)identifier;

@end

NS_ASSUME_NONNULL_END
