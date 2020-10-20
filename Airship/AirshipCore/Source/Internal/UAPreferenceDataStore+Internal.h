/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAPreferenceDataStore.h"

NS_ASSUME_NONNULL_BEGIN

@interface UAPreferenceDataStore ()

///---------------------------------------------------------------------------------------
/// @name Preference Data Store Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Migrates any values in NSUserDefaults that are not prefixed.
 * @param keys The keys to migrate.
 */
- (void)migrateUnprefixedKeys:(NSArray *)keys;

NS_ASSUME_NONNULL_END

@end
