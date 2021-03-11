/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAPreferenceDataStore.h"
#import "UARemoteConfig.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  NSNotification whenever the URL config changes.
 *  @note For internal use only. :nodoc:
 */
extern NSString *const UARemoteConfigURLManagerConfigUpdated;

/**
 * Remote URL config manager.
 * @note For internal use only. :nodoc:
 */
@interface UARemoteConfigURLManager : NSObject

/**
 * The Airship device API URL.
 *
 */
@property (nonatomic, copy, readonly, nullable) NSString *deviceAPIURL;

/**
 * The Airship analytics URL.
 *
 */
@property (nonatomic, copy, readonly, nullable) NSString *analyticsURL;

/**
 * The Airship remote data URL.
 *
 */
@property (nonatomic, copy, readonly, nullable) NSString *remoteDataURL;

/**
 * The Airship url config.
 *
 */
@property (atomic, strong, readonly) UARemoteConfig *urlConfig;

/**
 * Factory method.
 * @param dataStore  the data store.
 * @return A remote config.
 */
+ (instancetype)remoteConfigURLManagerWithDataStore:(UAPreferenceDataStore *)dataStore;

/**
 * Factory method.
 * @param dataStore  the data store.
 * @param notificationCenter The NSNotification center.
 * @return A remote config.
 */
+ (instancetype)remoteConfigURLManagerWithDataStore:(UAPreferenceDataStore *)dataStore
                                 notificationCenter:(NSNotificationCenter *)notificationCenter;


@end

NS_ASSUME_NONNULL_END
