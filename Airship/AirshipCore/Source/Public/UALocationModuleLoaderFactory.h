/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAModuleLoader.h"
#import "UAExtendableAnalyticsHeaders.h"
#import "UAAnalytics.h"
#import "UALocationProvider.h"

@class UAPreferenceDataStore;
@protocol UAChannelProtocol;

NS_ASSUME_NONNULL_BEGIN

/**
 * Internal location module loader factory.
 * @note For internal use only. :nodoc:
 */
@protocol UALocationModuleLoaderFactory <NSObject>

@required

/**
 * Factory method to provide the location module loader.
 * @param dataStore The datastore instance.
 * @param channel The airship channel.
 * @param analytics The analytics instance.
 * @return A location module loader.
 */
+ (id<UAModuleLoader, UALocationProviderLoader>)locationModuleLoaderWithDataStore:(UAPreferenceDataStore *)dataStore
                                                                          channel:(id<UAChannelProtocol>)channel
                                                                        analytics:(UAAnalytics<UAExtendableAnalyticsHeaders> *)analytics privacyManager:(UAPrivacyManager *)privacyManager;

@end

NS_ASSUME_NONNULL_END

