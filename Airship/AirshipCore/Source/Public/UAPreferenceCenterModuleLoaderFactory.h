/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAModuleLoader.h"
#import "UAChannel.h"

@class UAPreferenceDataStore;

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
 * @param config The config.
 * @param channel The Airship channel instance.
 * @param privacyManager The privacy manager.
 * @return A module loader.
 */
+ (id<UAModuleLoader>)moduleLoaderWithDataStore:(UAPreferenceDataStore *)dataStore
                                         config:(UARuntimeConfig *)config
                                        channel:(UAChannel *)channel
                                 privacyManager:(UAPrivacyManager *)privacyManager;

@end

NS_ASSUME_NONNULL_END
