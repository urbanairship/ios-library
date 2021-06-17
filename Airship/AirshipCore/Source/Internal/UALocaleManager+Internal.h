/* Copyright Airship and Contributors */

#import "UALocaleManager.h"

@class UAPreferenceDataStore;

NS_ASSUME_NONNULL_BEGIN

@interface UALocaleManager()

///---------------------------------------------------------------------------------------
/// @name Locale Manager Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Factory method to create a locale manager instance.
 * @param dataStore The shared preference data store.
 * @return A new locale manager instance.
 */
+ (instancetype)localeManagerWithDataStore:(UAPreferenceDataStore *)dataStore;

/**
 * NSNotification event when a locale is updated. The event
 * will contain the current locale under `UALocaleUpdatedEventLocaleKey`.
 */

extern NSString *const UALocaleUpdatedEvent;
extern NSString *const UALocaleUpdatedEventLocaleKey;

@end

NS_ASSUME_NONNULL_END
