/* Copyright 2018 Urban Airship and Contributors */

#import <Foundation/Foundation.h>

@class UAComponentDisabler;
@class UARemoteDataManager;

@interface UARemoteConfigManager : NSObject

/**
 * Factory method for the remoteConfigManager
 *
 * @param remoteDataManager The remote data manager to use for remote data
 * @param componentDisabler The component disabler to use for disabling components.
 * @return Newly created UARemoteConfigManager
 */
+ (UARemoteConfigManager *)remoteConfigManagerWithRemoteDataManager:(UARemoteDataManager *)remoteDataManager componentDisabler:(UAComponentDisabler *)componentDisabler;

@end
