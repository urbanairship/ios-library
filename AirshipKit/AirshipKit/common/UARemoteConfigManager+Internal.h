/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAModules+Internal.h"
#import "UAComponentDisabler+Internal.h"
#import "UARemoteDataManager+Internal.h"

@interface UARemoteConfigManager : NSObject

/**
 * The modules used by the remote config manager.
 */
@property (nonatomic, readonly) UAModules *modules;

/**
 * Factory method for the remoteConfigManager
 *
 * @param remoteDataManager The remote data manager to use for remote data
 * @param componentDisabler The component disabler to use for disabling components.
 * @param modules An instance of UAModules
 * 
 * @return Newly created UARemoteConfigManager
 */
+ (UARemoteConfigManager *)remoteConfigManagerWithRemoteDataManager:(UARemoteDataManager *)remoteDataManager
                                                  componentDisabler:(UAComponentDisabler *)componentDisabler
                                                            modules:(UAModules *)modules;

@end
