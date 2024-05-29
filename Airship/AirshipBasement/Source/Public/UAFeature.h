/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

/**
 * Enabled Features
 */
typedef NS_OPTIONS(NSUInteger, UAFeatures) {

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

    // Do not use: UAFeaturesChat = (1 << 3),
    
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
    
    // Do not use: UAFeaturesLocation = (1 << 7),
    
    // Enables feature flags.
    UAFeaturesFeatureFlags = (1 << 8),
    
    // Sets enabled features to all.
    UAFeaturesAll = (UAFeaturesInAppAutomation | UAFeaturesMessageCenter | UAFeaturesPush | UAFeaturesAnalytics | UAFeaturesTagsAndAttributes | UAFeaturesContacts | UAFeaturesFeatureFlags)
} NS_SWIFT_NAME(_UAFeatures);

// Sets enabled features to none.
static const UAFeatures UAFeaturesNone NS_SWIFT_UNAVAILABLE("Use [] instead.") = 0;
