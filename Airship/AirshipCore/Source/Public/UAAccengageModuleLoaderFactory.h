/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAModuleLoader.h"

@class UAChannel;
@class UAPush;
@class UAPrivacyManager;
@class UAPreferenceDataStore;

NS_ASSUME_NONNULL_BEGIN

/**
 * Accengage module loader factory.
 * @note For internal use only. :nodoc:
 */
@protocol UAAccengageModuleLoaderFactory <NSObject>

@required

/**
 * Factory method.
 * @param dataStore The preference data store.
 * @param channel The Airship channel instance.
 * @param push The push instance.
 * @param privacyManager The privacy manager.
 * @return A module loader.
 */
+ (id<UAModuleLoader>)moduleLoaderWithDataStore:(UAPreferenceDataStore *)dataStore
                                        channel:(UAChannel *)channel
                                           push:(UAPush *)push
                                 privacyManager:(UAPrivacyManager *)privacyManager;

@end

NS_ASSUME_NONNULL_END

