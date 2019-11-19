/* Copyright Airship and Contributors */

#import "NSString+UALocalizationAdditions.h"
#import "UAMessageCenterResources.h"

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
