/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

#if UA_USE_MODULE_AIRSHIP_IMPORTS
@import AirshipCore;
#else
#import "UAComponent.h"
#endif

@class UANotificationCategories;
@class UAPreferenceDataStore;
@class UAChannel;
@class UAPush;
@class UAPrivacyManager;

NS_ASSUME_NONNULL_BEGIN

/**
 * Accengage transition component.
 */
@interface UAAccengage : NSObject<UAComponent>

/**
 * Factory method.
 * @param dataStore The preference data store.
 * @param channel The Airship channel instance.
 * @param push The push instance.
 * @param privacyManager The privacy manager.
 * @return An Accengage component.
 */
+ (instancetype)accengageWithDataStore:(UAPreferenceDataStore *)dataStore
                               channel:(UAChannel *)channel
                                  push:(UAPush *)push
                        privacyManager:(UAPrivacyManager *)privacyManager;

/**
 * Factory method. Used for tests.
 * @param dataStore The preference data store.
 * @param channel The Airship channel instance.
 * @param push The push instance.
 * @param privacyManager The privacy manager.
 * @param settings The accengage settings.
 * @return An Accengage component.
 */
+ (instancetype)accengageWithDataStore:(UAPreferenceDataStore *)dataStore
                               channel:(UAChannel *)channel
                                  push:(UAPush *)push
                        privacyManager:(UAPrivacyManager *)privacyManager
                              settings:(NSDictionary *)settings;

@end

NS_ASSUME_NONNULL_END
