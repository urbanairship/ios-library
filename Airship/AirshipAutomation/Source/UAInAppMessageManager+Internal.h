/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppMessageManager.h"
#import "UAAutomationEngine+Internal.h"
#import "UAInAppMessage.h"
#import "UAInAppMessageScheduleInfo.h"
#import "UAInAppMessageAdapterProtocol.h"
#import "UATagGroupsLookupManager+Internal.h"
#import "UAInAppMessageDefaultDisplayCoordinator+Internal.h"
#import "UAInAppMessageAssetManager+Internal.h"
#import "UAInAppRemoteDataClient+Internal.h"
#import "UAAirshipAutomationCoreImport.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * In-app message manager provides a control interface for creating,
 * canceling and executing in-app message schedules.
 */
@interface UAInAppMessageManager ()  <UAAutomationEngineDelegate, UATagGroupsLookupManagerDelegate>

/**
 * In-app messaging asset manager.
 */
@property(nonatomic, strong) UAInAppMessageAssetManager *assetManager;

/**
 * In-app remote data client. Exposed for testing purposes.
 */
@property(nonatomic, strong) UAInAppRemoteDataClient *remoteDataClient;

/**
 * Factory method. Use for testing.
 *
 * @param automationEngine The automation engine.
 * @param tagGroupsLookupManager The tag groups lookup manager.
 * @param remoteDataProvider The remote data provider.
 * @param dataStore The preference data store.
 * @param channel The channel.
 * @param dispatcher GCD dispatcher.
 * @param analytics The system analytics instance.
 * @return A in-app message manager instance.
 */
+ (instancetype)managerWithAutomationEngine:(UAAutomationEngine *)automationEngine
                     tagGroupsLookupManager:(UATagGroupsLookupManager *)tagGroupsLookupManager
                         remoteDataProvider:(id<UARemoteDataProvider>)remoteDataProvider
                                  dataStore:(UAPreferenceDataStore *)dataStore
                                    channel:(UAChannel *)channel
                                 dispatcher:(UADispatcher *)dispatcher
                         displayCoordinator:(UAInAppMessageDefaultDisplayCoordinator *)displayCoordinator
                               assetManager:(UAInAppMessageAssetManager *)assetManager
                                  analytics:(UAAnalytics *)analytics;

/**
 * Factory method.
 *
 * @param config The UARuntimeConfigInstance.
 * @param tagGroupsHistory The tag groups history.
 * @param remoteDataProvider The remote data provider.
 * @param dataStore The preference data store.
 * @param channel The channel.
 * @param analytics The system analytics instance.
 * @return A in-app message manager instance.
 */
+ (instancetype)managerWithConfig:(UARuntimeConfig *)config
                 tagGroupsHistory:(id<UATagGroupsHistory>)tagGroupsHistory
               remoteDataProvider:(id<UARemoteDataProvider>)remoteDataProvider
                        dataStore:(UAPreferenceDataStore *)dataStore
                          channel:(UAChannel *)channel
                        analytics:(UAAnalytics *)analytics;


// UAAutomationEngineDelegate methods for testing

/**
 * Creates a schedule info from a builder.
 *
 * @param builder The schedule info builder.
 * @returns Schedule info.
 */
- (UAScheduleInfo *)createScheduleInfoWithBuilder:(UAScheduleInfoBuilder *)builder;


@end

NS_ASSUME_NONNULL_END


