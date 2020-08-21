/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppAutomation.h"
#import "UAInAppMessageManager.h"
#import "UAAutomationEngine+Internal.h"
#import "UAInAppMessage.h"
#import "UASchedule.h"
#import "UATagGroupsLookupManager+Internal.h"
#import "UAInAppRemoteDataClient+Internal.h"
#import "UAAirshipAutomationCoreImport.h"
#import "UADeferredScheduleAPIClient+Internal.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * In-app automation manager provides a control interface for creating,
 * canceling and executing in-app automations.
 */
@interface UAInAppAutomation() 

/**
 * Factory method. Use for testing.
 *
 * @param automationEngine The automation engine.
 * @param tagGroupsLookupManager The tag groups lookup manager.
 * @param remoteDataClient The remote data client.
 * @param dataStore The preference data store.
 * @param inAppMessageManager The in-app message manager instance.
 * @param channel The channel instance.
 * @parram deferredScheduleAPIClient The deferred API client.
 * @return A in-app automation manager instance.
 */
+ (instancetype)automationWithEngine:(UAAutomationEngine *)automationEngine
              tagGroupsLookupManager:(UATagGroupsLookupManager *)tagGroupsLookupManager
                    remoteDataClient:(UAInAppRemoteDataClient *)remoteDataClient
                           dataStore:(UAPreferenceDataStore *)dataStore
                 inAppMessageManager:(UAInAppMessageManager *)inAppMessageManager
                             channel:(UAChannel *)channel
           deferredScheduleAPIClient:(UADeferredScheduleAPIClient *)deferredScheduleAPIClient;

/**
 * Factory method.
 *
 * @param config The UARuntimeConfigInstance.
 * @param tagGroupHistorian The tag groups history.
 * @param remoteDataProvider The remote data provider.
 * @param dataStore The preference data store.
 * @param channel The channel.
 * @param analytics The system analytics instance.
 * @return A in-app automation manager instance.
 */
+ (instancetype)automationWithConfig:(UARuntimeConfig *)config
                    tagGroupHistorian:(UATagGroupHistorian *)tagGroupHistorian
                  remoteDataProvider:(id<UARemoteDataProvider>)remoteDataProvider
                           dataStore:(UAPreferenceDataStore *)dataStore
                             channel:(UAChannel *)channel
                           analytics:(UAAnalytics *)analytics;

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


