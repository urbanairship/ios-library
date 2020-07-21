/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAModuleLoader.h"
#import "UAPreferenceDataStore.h"
#import "UARemoteDataProvider.h"
#import "UAChannel.h"
#import "UARemoteDataProvider.h"
#import "UATagGroupHistorian.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Internal automation module loader factory.
 * @note For internal use only. :nodoc:
 */
@protocol UAAutomationModuleLoaderFactory <NSObject>

@required

/**
 * Factory method to provide the automation module loader.
 * @param dataStore The datastore.
 * @param config The runtime config.
 * @param channel The channel.
 * @param analytics Analytics instance.
 * @param remoteDataProvider Remote data provider.
 * @param tagGroupHistorian Tag groups history.
 * @return The module loader.
 */
+ (id<UAModuleLoader>)inAppModuleLoaderWithDataStore:(UAPreferenceDataStore *)dataStore
                                              config:(UARuntimeConfig *)config
                                             channel:(UAChannel *)channel
                                           analytics:(UAAnalytics *)analytics
                                  remoteDataProvider:(id<UARemoteDataProvider>)remoteDataProvider
                                    tagGroupHistorian:(UATagGroupHistorian *)tagGroupHistorian;
@end

NS_ASSUME_NONNULL_END

