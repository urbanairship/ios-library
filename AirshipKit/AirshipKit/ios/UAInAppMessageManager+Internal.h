/* Copyright 2018 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppMessageManager.h"
#import "UAAutomationEngine+Internal.h"
#import "UAInAppMessage.h"
#import "UAInAppMessageScheduleInfo.h"
#import "UAInAppMessageAdapterProtocol.h"
#import "UAComponent+Internal.h"
#import "UADispatcher+Internal.h"

@class UARemoteDataManager;
@class UAPush;

NS_ASSUME_NONNULL_BEGIN

/**
 * In-app message manager provides a control interface for creating,
 * canceling and executing in-app message schedules.
 */
@interface UAInAppMessageManager ()  <UAAutomationEngineDelegate>

/**
 * Factory method. Use for testing.
 *
 * @param automationEngine Automation engine.
 * @param dataStore The preference data store.
 * @param push The system UAPush instance
 * @param dispatcher GCD dispatcher.
 * @return A in-app message manager instance.
 */
+ (instancetype)managerWithAutomationEngine:(UAAutomationEngine *)automationEngine
                          remoteDataManager:(UARemoteDataManager *)remoteDataManager
                                  dataStore:(UAPreferenceDataStore *)dataStore
                                       push:(UAPush *)push
                                 dispatcher:(UADispatcher *)dispatcher;

/**
 * Factory method.
 *
 * @param config The UAConfigInstance.
 * @param dataStore The preference data store.
 * @param push The system UAPush instance
 * @return A in-app message manager instance.
 */
+ (instancetype)managerWithConfig:(UAConfig *)config
                remoteDataManager:(UARemoteDataManager *)remoteDataManager
                        dataStore:(UAPreferenceDataStore *)dataStore
                             push:(UAPush *)push;


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

