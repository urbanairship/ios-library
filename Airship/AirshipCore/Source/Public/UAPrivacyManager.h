/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAPreferenceDataStore.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * The privacy manager allow enabling/disabling features in the SDK.
 * The SDK will not make any network requests or collect data if all features our disabled, with
 * a few exceptions when going from enabled -> disabled. To have the SDK opt-out of all features on startup,
 * set the default enabled features in the AirshipConfig to UAFeaturesNone, or in the
 * airshipconfig.plist file with `enabledFeatures = none`.
 * If any feature is enabled, the SDK will collect and send the following data:
 * - Channel ID
 * - Locale
 * - TimeZone
 * - Platform
 * - Opt in state (push and notifications)
 * - SDK version
 * - Accengage Device ID (Accengage module for migration)
 */
@interface UAPrivacyManager : NSObject

/**
 * NSNotification event when enabled feature list is updated.
 */

extern NSString *const UAPrivacyManagerEnabledFeaturesChangedEvent;

/**
 * Enabled Features
 */
typedef NS_OPTIONS(NSUInteger, UAFeatures) {
    
    // Sets enabled features to none.
    UAFeaturesNone = 0,
    
    // Enables In-App Automation.
    // In addition to the default data collection, In-App Automation will collect:
    // - App Version (App update triggers)
    UAFeaturesInAppAutomation  = (1 << 0),
    
    // Enables Message Center.
    // In addition to the default data collection, Message Center will collect:
    // - Message Center User
    // - Message Reads & Deletes
    UAFeaturesMessageCenter   = (1 << 1),
    
    // Enables push.
    // In addition to the default data collection, push will collect:
    // - Push tokens
    UAFeaturesPush   = (1 << 2),
    
    // Enables Airship Chat.
    // In addition to the default data collection, Airship Chat will collect:
    // - User messages
    UAFeaturesChat = (1 << 3),
    
    // Enables analytics.
    // In addition to the default data collection, analytics will collect:
    // -  Events
    // - Associated Identifiers
    // - Registered Notification Types
    // - Time in app
    // - App Version
    // - Device model
    // - Device manufacturer
    // - OS version
    // - Carrier
    // - Connection type
    // - Framework usage
    UAFeaturesAnalytics = (1 << 4),
    
    // Enables tags and attributes.
    // In addition to the default data collection, tags and attributes will collect:
    // - Channel and Contact Tags
    // - Channel and Contact Attributes
    UAFeaturesTagsAndAttributes = (1 << 5),
    
    // Enables contacts.
    // In addition to the default data collection, contacts will collect:
    // External ids (named user)
    UAFeaturesContacts = (1 << 6),
    
    // Enables location (with Location module).
    // In addition to the default data collection, location will collect:
    // - Location permissions
    // - Collect location for the app (Airship no longer supports uploading location as events)
    UAFeaturesLocation = (1 << 7),
    
    // Sets enabled features to all.
    UAFeaturesAll = (UAFeaturesInAppAutomation | UAFeaturesMessageCenter | UAFeaturesPush | UAFeaturesChat | UAFeaturesAnalytics | UAFeaturesTagsAndAttributes | UAFeaturesContacts | UAFeaturesLocation)
};

/**
 * Factory method to create a Privacy Manager instance.
 * @note For internal use only. :nodoc:
 *
 * @param dataStore The shared preference data store.
 * @param features Default enabled features.
 * @return A new privacy manager instance.
 */
+ (instancetype)privacyManagerWithDataStore:(UAPreferenceDataStore *)dataStore
                     defaultEnabledFeatures:(UAFeatures)features;

/**
 * Gets the current enabled features.
 *
 * @return The enabled features.
 */
@property(nonatomic, assign) UAFeatures enabledFeatures;

/**
 * Enables features.
 *
 * @param features The features to enable.
 */
- (void)enableFeatures:(UAFeatures)features;

/**
 * Disables features.
 *
 * @param features The features to disable.
 */
- (void)disableFeatures:(UAFeatures)features;

/**
 * Checks if a given feature is enabled.
 *
 * @param feature The features to check.
 * @return True if the provided features are enabled, otherwise false.
*/
- (BOOL)isEnabled:(UAFeatures)feature;

/**
 * Checks if any feature is enabled.
 *
 * @return True if any feature is enabled, otherwise false.
 */
- (BOOL)isAnyFeatureEnabled;

@end

NS_ASSUME_NONNULL_END
