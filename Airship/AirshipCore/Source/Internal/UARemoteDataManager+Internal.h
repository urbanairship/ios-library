/* Copyright Airship and Contributors */

#import <UIKit/UIKit.h>
#import "UADisposable.h"
#import "UARemoteDataPayload+Internal.h"
#import "UARuntimeConfig.h"
#import "UADispatcher.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UARemoteDataStore+Internal.h"
#import "UARemoteDataAPIClient+Internal.h"
#import "UAComponent.h"
#import "UAPushableComponent.h"
#import "UARemoteDataProvider.h"
#import "UAAppStateTracker.h"
#import "UADate.h"
#import "UATaskManager.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Default foreground refresh interval.
 */
extern NSTimeInterval const UARemoteDataRefreshIntervalDefault;

@interface UARemoteDataManager : UAComponent <UARemoteDataProvider, UAPushableComponent>

///---------------------------------------------------------------------------------------
/// @name Internal Properties & Methods
///---------------------------------------------------------------------------------------

/**
 * Create the remote data manager.
 *
 * @param config The Airship config.
 * @param dataStore A UAPreferenceDataStore to store persistent preferences
 * @param localeManager A UALocaleManager.
 * @param privacyManager The privacy manager.
 * @return The remote data manager instance.
 */
+ (instancetype)remoteDataManagerWithConfig:(UARuntimeConfig *)config
                                  dataStore:(UAPreferenceDataStore *)dataStore
                              localeManager:(UALocaleManager *)localeManager
                             privacyManager:(UAPrivacyManager *)privacyManager;

/**
 * The minimum amount of time in seconds between remote data refreshes. Increase this
 * value to reduce the frequency of refreshes.
 */
@property (nonatomic, assign) NSTimeInterval remoteDataRefreshInterval;

/**
 * Create the remote data manager. Used for testing.
 *
 * @param config The Airship config.
 * @param dataStore A UAPreferenceDataStore to store persistent preferences
 * @param remoteDataStore The remote data store.
 * @param remoteDataAPIClient The remote data API client.
 * @param notificationCenter The notification center.
 * @param appStateTracker The application state tracker.
 * @param dispatcher The dispatcher.
 * @param date The date.
 * @param localeManager A UALocaleManager.
 * @param taskManager The task manager.
 * @param privacyManager The privacy manager.
 * @return The remote data manager instance.
 */
+ (instancetype)remoteDataManagerWithConfig:(UARuntimeConfig *)config
                                  dataStore:(UAPreferenceDataStore *)dataStore
                            remoteDataStore:(UARemoteDataStore *)remoteDataStore
                        remoteDataAPIClient:(UARemoteDataAPIClient *)remoteDataAPIClient
                         notificationCenter:(NSNotificationCenter *)notificationCenter
                            appStateTracker:(UAAppStateTracker *)appStateTracker
                                 dispatcher:(UADispatcher *)dispatcher
                                       date:(UADate *)date
                              localeManager:(UALocaleManager *)localeManager
                                taskManager:(UATaskManager *)taskManager
                             privacyManager:(UAPrivacyManager *)privacyManager;

@end

NS_ASSUME_NONNULL_END
