/* Copyright Airship and Contributors */

#import "UAMessageCenterResources.h"

#import "UAAirshipMessageCenterCoreImport.h"

/**
 * Returns a localized string by key, searching the UAInbox table and falling back on
 * the "en" locale if necessary.
 */
#define UAMessageCenterLocalizedString(key) [key localizedStringWithTable:@"UrbanAirship" moduleBundle:[UAMessageCenterResources bundle] fallbackLocale:@"en"]

/**
 * Checks if a localized string exists for key, searching the UAInbox table and falling back on
 * the "en" locale if necessary.
 */
#define UAMessageCenterLocalizedStringExists(key) [key localizedStringExistsInTable:@"UrbanAirship" moduleBundle:[UAMessageCenterResources bundle] fallbackLocale:@"en"]
