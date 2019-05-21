/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppMessageManager.h"
#import "UAAutomationEngine+Internal.h"
#import "UAInAppMessage.h"
#import "UAInAppMessageScheduleInfo.h"
#import "UAInAppMessageAdapterProtocol.h"
#import "UAComponent+Internal.h"
#import "UADispatcher+Internal.h"
#import "UARemoteDataManager+Internal.h"
#import "UAPush+Internal.h"
#import "UATagGroupsLookupManager+Internal.h"
#import "UATagGroupsMutationHistory+Internal.h"
#import "UAInAppMessageDefaultDisplayCoordinator+Internal.h"
#import "UAInAppMessageAssetManager+Internal.h"
#import "UAInAppRemoteDataClient+Internal.h"

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
 * @param remoteDataManager The remote data manager.
 * @param dataStore The preference data store.
 * @param push The system UAPush instance
 * @param dispatcher GCD dispatcher.
 * @param analytics The system analytics instance.
 * @return A in-app message manager instance.
 */
+ (instancetype)managerWithAutomationEngine:(UAAutomationEngine *)automationEngine
                     tagGroupsLookupManager:(UATagGroupsLookupManager *)tagGroupsLookupManager
                          remoteDataManager:(UARemoteDataManager *)remoteDataManager
                                  dataStore:(UAPreferenceDataStore *)dataStore
                                       push:(UAPush *)push
                                 dispatcher:(UADispatcher *)dispatcher
                         displayCoordinator:(UAInAppMessageDefaultDisplayCoordinator *)displayCoordinator
                               assetManager:(UAInAppMessageAssetManager *)assetManager
                                  analytics:(UAAnalytics *)analytics;

/**
 * Factory method.
 *
 * @param config The UARuntimeConfigInstance.
 * @param tagGroupsMutationHistory The tag groups mutation history.
 * @param remoteDataManager The remote data manager.
 * @param dataStore The preference data store.
 * @param push The system UAPush instance.
 * @param analytics The system analytics instance.
 * @return A in-app message manager instance.
 */
+ (instancetype)managerWithConfig:(UARuntimeConfig *)config
         tagGroupsMutationHistory:(UATagGroupsMutationHistory *)tagGroupsMutationHistory
                remoteDataManager:(UARemoteDataManager *)remoteDataManager
                        dataStore:(UAPreferenceDataStore *)dataStore
                             push:(UAPush *)push
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

