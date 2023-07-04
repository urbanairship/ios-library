/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppAutomation.h"
#import "UAInAppMessageManager.h"
#import "UAAutomationEngine+Internal.h"
#import "UAInAppMessage.h"
#import "UASchedule.h"
#import "UAInAppRemoteDataClient+Internal.h"
#import "UAAirshipAutomationCoreImport.h"
#import "UADeferredScheduleAPIClient+Internal.h"
#import "UAFrequencyLimitManager+Internal.h"

@class UAPreferenceDataStore;
@class UAChannel;
@class UAAnalytics;
@class UAPrivacyManager;
@class UAAutomationAudienceOverridesProvider;
@class UARemoteDataAutomationAccess;
@class UAAutomationAudienceChecker;

@protocol UAAutomationAudienceCheckerProtocol;

NS_ASSUME_NONNULL_BEGIN

/**
 * In-app automation manager provides a control interface for creating,
 * canceling and executing in-app automations.
 */
@interface UAInAppAutomation() 

/**
 * Factory method. Use for testing.
 *
 * @param config The UARuntimeConfigInstance.
 * @param automationEngine The automation engine.
 * @param audienceOverridesProvider The audience overides provider.
 * @param remoteDataClient The remote data client.
 * @param dataStore The preference data store.
 * @param inAppMessageManager The in-app message manager instance.
 * @param channel The channel instance.
 * @param deferredScheduleAPIClient The deferred API client.
 * @param frequencyLimitManager The frequency limit manager.
 * @param privacyManager The privacy manager.
 * @param audienceChecker The audience checker.
 * @return A in-app automation manager instance.
 */
+ (instancetype)automationWithConfig:(UARuntimeConfig *)config
                    automationEngine:(UAAutomationEngine *)automationEngine
           audienceOverridesProvider:(UAAutomationAudienceOverridesProvider *)audienceOverridesProvider
                    remoteDataClient:(UAInAppRemoteDataClient *)remoteDataClient
                           dataStore:(UAPreferenceDataStore *)dataStore
                 inAppMessageManager:(UAInAppMessageManager *)inAppMessageManager
                             channel:(UAChannel *)channel
           deferredScheduleAPIClient:(UADeferredScheduleAPIClient *)deferredScheduleAPIClient
               frequencyLimitManager:(UAFrequencyLimitManager *)frequencyLimitManager
                      privacyManager:(UAPrivacyManager *)privacyManager
                     audienceChecker:(id<UAAutomationAudienceCheckerProtocol>)audienceChecker;

/**
 * Factory method.
 *
 * @param config The UARuntimeConfigInstance.
 * @param audienceOverridesProvider The audience overides provider.
 * @param remoteData The remote data provider.
 * @param dataStore The preference data store.
 * @param channel The channel.
 * @param analytics The system analytics instance.
 * @param privacyManager The privacy manager.
 * @return A in-app automation manager instance.
 */
+ (instancetype)automationWithConfig:(UARuntimeConfig *)config
           audienceOverridesProvider:(UAAutomationAudienceOverridesProvider *)audienceOverridesProvider
                          remoteData:(UARemoteDataAutomationAccess *)remoteData
                           dataStore:(UAPreferenceDataStore *)dataStore
                             channel:(UAChannel *)channel
                           analytics:(UAAnalytics *)analytics
                      privacyManager:(UAPrivacyManager *)privacyManager;

- (void)cancelSchedulesWithType:(UAScheduleType)scheduleType
              completionHandler:(nullable void (^)(BOOL))completionHandler;

/**
 * Get all the in-app automations.
 *
 * @param completionHandler The completion handler to be called when fetch operation completes.
 */
- (void)getSchedules:(void (^)(NSArray<UASchedule *> *))completionHandler;


@end

NS_ASSUME_NONNULL_END


