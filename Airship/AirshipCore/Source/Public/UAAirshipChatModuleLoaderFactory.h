/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAModuleLoader.h"
#import "UAPreferenceDataStore.h"
#import "UAChannel.h"
#import "UAAnalytics.h"
#import "UAPush.h"

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
 * @param channel The Airship channel instance.
 * @param push The push instance.
 * @return A module loader.
 */
+ (id<UAModuleLoader>)moduleLoaderWithDataStore:(UAPreferenceDataStore *)dataStore
                                        channel:(UAChannel *)channel
                                           push:(UAPush *)push;

@end

NS_ASSUME_NONNULL_END

