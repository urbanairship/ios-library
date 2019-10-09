/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UARemoteConfigModuleAdapter+Internal.h"
#import "UARemoteDataManager+Internal.h"

@interface UARemoteConfigManager : NSObject

/**
 * Factory method for the remoteConfigManager
 *
 * @param remoteDataManager The remote data manager to use for remote data
 * @param applicationMetrics Application metrics
 *
 * @return Newly created UARemoteConfigManager
 */
+ (UARemoteConfigManager *)remoteConfigManagerWithRemoteDataManager:(UARemoteDataManager *)remoteDataManager
                                                 applicationMetrics:(UAApplicationMetrics *)applicationMetrics;

/**
 * Factory method for the remoteConfigManager. Used for testing.
 *
 * @param remoteDataManager The remote data manager to use for remote data
 * @param applicationMetrics Application metrics
 * @param moduleAdapter The module to component adapter
 * @return Newly created UARemoteConfigManager
 */
+ (instancetype)remoteConfigManagerWithRemoteDataManager:(UARemoteDataManager *)remoteDataManager
                                      applicationMetrics:(UAApplicationMetrics *)applicationMetrics
                                           moduleAdapter:(UARemoteConfigModuleAdapter *)moduleAdapter;


@end
