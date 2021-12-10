/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppMessageManager.h"
#import "UAInAppMessage.h"
#import "UAInAppMessageAdapterProtocol.h"
#import "UAInAppMessageDefaultDisplayCoordinator+Internal.h"
#import "UAInAppMessageAssetManager+Internal.h"
#import "UAAirshipAutomationCoreImport.h"
#import "UAAutomationEngine+Internal.h"

@class UAPreferenceDataStore;
@class UADispatcher;
@protocol UAAnalyticsProtocol;

NS_ASSUME_NONNULL_BEGIN

/**
 * Execution delegate.
 */
@protocol UAInAppMessagingExecutionDelegate  <NSObject>

/**
 * Called when execution readiness changed.
 */
- (void)executionReadinessChanged;

/**
 * Called to cancel schedules.
 * @param scheduleID The schedule ID.
 */
- (void)cancelScheduleWithID:(NSString *)scheduleID;
@end


/**
 * In-app message manager provides a control interface for creating,
 * canceling and executing in-app message schedules.
 */
@interface UAInAppMessageManager ()

@property (nonatomic, weak) id<UAInAppMessagingExecutionDelegate> executionDelegate;

/**
 * Factory method. Use for testing.
 *
 * @param dataStore The preference data store
 * @param analytics The system analytics instance.
 * @param dispatcher GCD dispatcher.
 * @param displayCoordinator Default display coordinator.
 * @param assetManager Asset manager.
 * @return A in-app message manager instance.
 */
+ (instancetype)managerWithDataStore:(UAPreferenceDataStore *)dataStore
                           analytics:(id<UAAnalyticsProtocol>)analytics
                          dispatcher:(UADispatcher *)dispatcher
                  displayCoordinator:(UAInAppMessageDefaultDisplayCoordinator *)displayCoordinator
                        assetManager:(UAInAppMessageAssetManager *)assetManager;

/**
 * Factory method.
 *
 * @param dataStore The preference data store.
 * @param analytics The system analytics instance.
 * @return A in-app message manager instance.
 */
+ (instancetype)managerWithDataStore:(UAPreferenceDataStore *)dataStore
                           analytics:(id<UAAnalyticsProtocol>)analytics;


/**
 * Called to prepare a message for display.
 * @param message The message.
 * @param scheduleID The schedule ID.
 * @param campaigns The campaign info.
 * @param reportingContext The reporting context info.

 * @param completionHandler The completion handler with the prepare result.
 */
- (void)prepareMessage:(UAInAppMessage *)message
            scheduleID:(NSString *)scheduleID
             campaigns:(nullable id)campaigns
      reportingContext:(nullable id)reportingContext
     completionHandler:(void (^)(UAAutomationSchedulePrepareResult))completionHandler;


/**
 * Called to check if the message is ready to display.
 * @param scheduleID The schedule ID.
 * @returns The ready result.
 */
- (UAAutomationScheduleReadyResult)isReadyToDisplay:(NSString *)scheduleID;

/**
 * Called when a prepared message is display is aborted.
 * @param scheduleID The schedule ID.
 */
- (void)scheduleExecutionAborted:(NSString *)scheduleID;

/**
 * Called when a message should be displayed. The message should must be prepared before it can be displayed.
 * @param scheduleID The schedule ID.
 * @param completionHandler The completion handler.
 */
- (void)displayMessageWithScheduleID:(NSString *)scheduleID
                   completionHandler:(void (^)(void))completionHandler;

/**
 * Called when a message is expired.
 * @param message The message.
 * @param scheduleID The schedule ID.
 * @param expirationDate The expiration date.
 */
- (void)messageExpired:(UAInAppMessage *)message
            scheduleID:(NSString *)scheduleID
        expirationDate:(NSDate *)expirationDate;

/**
 * Called when a message is cancelled.
 * @param message The message.
 * @param scheduleID The schedule ID.
 */
- (void)messageCancelled:(UAInAppMessage *)message
              scheduleID:(NSString *)scheduleID;

/**
 * Called when a message reaches its limit.
 * @param message The message.
 * @param scheduleID The schedule ID.
 */
- (void)messageLimitReached:(UAInAppMessage *)message
                 scheduleID:(NSString *)scheduleID;

/**
 * Called when a message is scheduled.
 * @param message The message.
 * @param scheduleID The schedule ID.
 */
- (void)messageScheduled:(UAInAppMessage *)message
              scheduleID:(NSString *)scheduleID;

/**
 * Called when a message display was interrupted.
 * @param message The message if available. If not available it indicates its a deferred message type.
 * @param scheduleID The schedule ID.
 * @param campaigns The campaign info
 * @param reportingContext The reporting context.
 */
- (void)messageExecutionInterrupted:(nullable UAInAppMessage *)message
                         scheduleID:(NSString *)scheduleID
                          campaigns:(nullable id)campaigns
                   reportingContext:(nullable id)reportingContext;

@end

NS_ASSUME_NONNULL_END


