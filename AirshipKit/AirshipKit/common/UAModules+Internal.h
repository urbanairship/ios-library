/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAComponent+Internal.h"
#import "UAModules.h"

NS_ASSUME_NONNULL_BEGIN

@interface UAModules ()

- (instancetype)initWithDataStore:(UAPreferenceDataStore *)dataStore;

/**
 * Processes configs for all modules.
 *
 * @param configs A dictionary mapping module names to remote config JSON dictionaries.
 */
- (void)processConfigs:(NSDictionary *)configs;

@end

NS_ASSUME_NONNULL_END
