/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UARemoteConfigModuleAdapter+Internal.h"
#import "UARemoteDataManager+Internal.h"

@interface UARemoteConfigManager : NSObject

/**
 * Factory method for the remoteConfigManager
 *
 * @param remoteDataManager The remote data manager to use for remote data
 * @param privacyManager The privacy manager.
 *
 * @return Newly created UARemoteConfigManager
 */
+ (UARemoteConfigManager *)remoteConfigManagerWithRemoteDataManager:(UARemoteDataManager *)remoteDataManager
                                                     privacyManager:(UAPrivacyManager *)privacyManager;
/**
 * Factory method for the remoteConfigManager. Used for testing.
 *
 * @param remoteDataManager The remote data manager to use for remote data
 * @param privacyManager The privacy manager.
 * @param moduleAdapter The module to component adapter
 * @param versionBlock The block used to fetch the version.
 * @return Newly created UARemoteConfigManager
 */
+ (instancetype)remoteConfigManagerWithRemoteDataManager:(UARemoteDataManager *)remoteDataManager
                                          privacyManager:(UAPrivacyManager *)privacyManager
                                           moduleAdapter:(UARemoteConfigModuleAdapter *)moduleAdapter
                                            versionBlock:(NSString *(^)(void))versionBlock;


/**
 * NSNotification event when the remote config  is updated. The event
 * will contain the remote config  under `UAAirshipRemoteConfigUpdatedKey`.
 */
extern NSString *const UAAirshipRemoteConfigUpdatedEvent;
extern NSString *const UAAirshipRemoteConfigUpdatedKey;

@end

