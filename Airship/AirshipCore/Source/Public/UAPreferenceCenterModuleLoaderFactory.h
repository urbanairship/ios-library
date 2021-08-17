/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAModuleLoader.h"


@class UAPreferenceDataStore;
@class UAChannel;

NS_ASSUME_NONNULL_BEGIN

/**
 * PreferenceCenter module loader factory.
 * @note For internal use only. :nodoc:
 */
@protocol UAPreferenceCenterModuleLoaderFactory <NSObject>

@required

/**
 * Factory method.
 * @param dataStore The preference data store.
 * @param privacyManager The privacy manager.
 * @param remoteDataProvider The remote data provider.
 * @return A module loader.
 */
+ (id<UAModuleLoader>)moduleLoaderWithDataStore:(UAPreferenceDataStore *)dataStore
                                 privacyManager:(UAPrivacyManager *)privacyManager
                             remoteDataProvider:(id<UARemoteDataProvider>)remoteDataProvider;

@end

NS_ASSUME_NONNULL_END
