/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAPreferenceDataStore.h"

NS_ASSUME_NONNULL_BEGIN

@interface UAPreferenceDataStore ()

///---------------------------------------------------------------------------------------
/// @name Preference Data Store Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Factory method for creating a preference data store with a key prefix.
 * @param keyPrefix The prefix to automatically apply to all keys.
 */
+ (instancetype)preferenceDataStoreWithKeyPrefix:(NSString *)keyPrefix;

/**
 * Migrates any values in NSUserDefaults that are not prefixed.
 * @param keys The keys to migrate.
 */
- (void)migrateUnprefixedKeys:(NSArray *)keys;

NS_ASSUME_NONNULL_END

@end
