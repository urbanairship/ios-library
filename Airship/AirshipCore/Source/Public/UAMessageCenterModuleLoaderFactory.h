/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAModuleLoader.h"
#import "UAChannel.h"
#import "UAExtendableChannelRegistration.h"

@class UAPreferenceDataStore;

NS_ASSUME_NONNULL_BEGIN

/**
 * Internal message center module loader factory.
 * @note For internal use only. :nodoc:
 */
@protocol UAMessageCenterModuleLoaderFactory <NSObject>

@required

/**
 * Factory method to provide the message center module loader.
 * @param dataStore The datastore.
 * @param config The config
 * @param channel The channel.
 * @param privacyManager The privacy manager.
 * @return A module loader.
 */
+ (id<UAModuleLoader>)messageCenterModuleLoaderWithDataStore:(UAPreferenceDataStore *)dataStore
                                                      config:(UARuntimeConfig *)config
                                                     channel:(UAChannel<UAExtendableChannelRegistration> *)channel
                                              privacyManager:(UAPrivacyManager *)privacyManager;


@end

NS_ASSUME_NONNULL_END

