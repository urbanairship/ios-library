/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

#if UA_USE_MODULE_AIRSHIP_IMPORTS
@import AirshipCore;
#else
#import "UAComponent.h"
#import "UAChannel.h"
#import "UAPush.h"
#import "UAAnalytics.h"
#import "UAPushableComponent.h"
#endif

NS_ASSUME_NONNULL_BEGIN

/**
 * Accengage transition component.
 */
@interface UAAccengage : UAComponent<UAPushableComponent>

/**
 * Factory method.
 * @param dataStore The preference data store.
 * @param channel The Airship channel instance.
 * @param push The push instance.
 * @param analytics The analytics instance.
 * @return A Accengage component.
 */
+ (instancetype)accengageWithDataStore:(UAPreferenceDataStore *)dataStore
                               channel:(UAChannel *)channel
                                  push:(UAPush *)push
                             analytics:(UAAnalytics *)analytics;

@end

NS_ASSUME_NONNULL_END
