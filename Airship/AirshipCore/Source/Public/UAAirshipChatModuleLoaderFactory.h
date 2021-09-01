/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAModuleLoader.h"

@class UAPreferenceDataStore;
@class UAChannel;

NS_ASSUME_NONNULL_BEGIN

/**
 * AirshipChat module loader factory.
 * @note For internal use only. :nodoc:
 */
@protocol UAAirshipChatModuleLoaderFactory <NSObject>

@required

/**
 * Factory method.
 * @param dataStore The preference data store.
 * @param config The config.
 * @param channel The Airship channel instance.
 * @return A module loader.
 */
+ (id<UAModuleLoader>)moduleLoaderWithDataStore:(UAPreferenceDataStore *)dataStore
                                        config:(UARuntimeConfig *)config
                                        channel:(UAChannel *)channel
                                 privacyManager:(UAPrivacyManager *)privacyManager;

@end

NS_ASSUME_NONNULL_END

