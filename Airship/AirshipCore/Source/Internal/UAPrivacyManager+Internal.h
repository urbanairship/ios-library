/* Copyright Airship and Contributors */

#import "UAPrivacyManager.h"
#import "UAPreferenceDataStore.h"

NS_ASSUME_NONNULL_BEGIN

@interface UAPrivacyManager()

///---------------------------------------------------------------------------------------
/// @name Privacy Manager Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Factory method to create a Privacy Manager instance.
 * @param dataStore The shared preference data store.
 * @param features Default enabled features.
 * @return A new privacy manager instance.
 */
+ (instancetype)privacyManagerWithDataStore:(UAPreferenceDataStore *)dataStore defaultEnabledFeatures:(UAFeatures)features;

- (void)migrateData;

@end

NS_ASSUME_NONNULL_END
