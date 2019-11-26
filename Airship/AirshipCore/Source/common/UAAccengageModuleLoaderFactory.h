/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAModuleLoader.h"
#import "UAPreferenceDataStore.h"
#import "UAChannel.h"
#import "UAAnalytics.h"
#import "UAPush.h"

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
 * @param analytics The analytics instance.
 * @return A module loader.
 */
+ (id<UAModuleLoader>)moduleLoaderWithDataStore:(UAPreferenceDataStore *)dataStore
                                        channel:(UAChannel *)channel
                                           push:(UAPush *)push
                                      analytics:(UAAnalytics *)analytics;

@end

NS_ASSUME_NONNULL_END

