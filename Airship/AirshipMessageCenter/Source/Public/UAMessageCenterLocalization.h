/* Copyright Airship and Contributors */

#import "UAMessageCenterResources.h"
#import "UAAirshipMessageCenterCoreImport.h"

@class UALocalizationUtils;

/**
 * Returns a localized string by key, searching the UAInbox table and falling back on
 * the "en" locale if necessary.
 */
#define UAMessageCenterLocalizedString(key) [UALocalizationUtils localizedString:key withTable:@"UrbanAirship" moduleBundle:[UAMessageCenterResources bundle] fallbackLocale:@"en"]

/**
 * Checks if a localized string exists for key, searching the UAInbox table and falling back on
 * the "en" locale if necessary.
 */
#define UAMessageCenterLocalizedStringExists(key) [UALocalizationUtils localizedStringExists:key inTable:@"UrbanAirship" moduleBundle:[UAMessageCenterResources bundle] fallbackLocale:@"en"]
