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

NS_ASSUME_NONNULL_BEGIN

@interface UARemoteDataManager : UAComponent <UARemoteDataProvider, UAPushableComponent>

///---------------------------------------------------------------------------------------
/// @name Internal Properties & Methods
///---------------------------------------------------------------------------------------

/**
 * Refresh the remote data from the cloud, with completion handler
 *
 * @param completionHandler Optional completion handler called when refresh is complete, with result.
 */
- (void)refreshWithCompletionHandler:(nullable void(^)(BOOL success))completionHandler;

/**
 * Create the remote data manager.
 *
 * @param config The Airship config.
 * @param dataStore A UAPreferenceDataStore to store persistent preferences
 * @return The remote data manager instance.
 */
+ (instancetype)remoteDataManagerWithConfig:(UARuntimeConfig *)config
                                  dataStore:(UAPreferenceDataStore *)dataStore;

///---------------------------------------------------------------------------------------
/// @name Test Properties & Internal Methods
///---------------------------------------------------------------------------------------

/**
 * The minimum amount of time in seconds between remote data refreshes. Increase this
 * value to reduce the frequency of refreshes.
 */
@property (nonatomic, assign) NSUInteger remoteDataRefreshInterval;

/**
 * The metadata used to fetch the most recent payload.
 */
@property (nullable, nonatomic, strong) NSDictionary *lastMetadata;

/**
 * The last modified date.
 *
 * Exposed for testing purposes.
 */
@property (nullable, nonatomic, strong) NSDate *lastModified;

/**
 * Refresh the remote data from the cloud only if the time since the last refresh
 * is greater than the minimum foreground refresh interval or last stored metadata
 * doesn't match current metadata.
 *
 * @param completionHandler Optional completion handler called when refresh is complete, with result.
 */
- (void)foregroundRefreshWithCompletionHandler:(nullable void(^)(BOOL success))completionHandler;

/**
 * Create the remote data manager. Used for testing.
 *
 * @param config The Airship config.
 * @param dataStore A UAPreferenceDataStore to store persistent preferences
 * @param remoteDataStore The remote data store.
 * @param remoteDataAPIClient The remote data API client.
 * @param notificationCenter The notification center.
 * @param dispatcher The dispatcher.
 * @return The remote data manager instance.
 */
+ (instancetype)remoteDataManagerWithConfig:(UARuntimeConfig *)config
                                  dataStore:(UAPreferenceDataStore *)dataStore
                            remoteDataStore:(UARemoteDataStore *)remoteDataStore
                        remoteDataAPIClient:(UARemoteDataAPIClient *)remoteDataAPIClient
                         notificationCenter:(NSNotificationCenter *)notificationCenter
                                 dispatcher:(UADispatcher *)dispatcher;

/**
 * Creates the client metadata used to fetch the request.
 *
 * @param locale The locale with which to create the metadata.
 * @return The metadata dictionary.
 */
-(NSDictionary *)createMetadata:(NSLocale *)locale;

@end

NS_ASSUME_NONNULL_END
