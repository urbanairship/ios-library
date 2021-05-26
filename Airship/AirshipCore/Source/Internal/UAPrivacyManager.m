/* Copyright Airship and Contributors */

#import "UAPrivacyManager+Internal.h"
#import "UAComponent.h"
#import "UAPush+Internal.h"

static NSString *const UAPrivacyManagerEnabledFeaturesKey = @"com.urbanairship.privacymanager.enabledfeatures";
NSString *const UAPrivacyManagerEnabledFeaturesChangedEvent = @"com.urbanairship.privacymanager.enabledfeatures_changed";

static NSString *const LegacyIAAEnableFlag = @"UAInAppMessageManagerEnabled";
static NSString *const LegacyChatEnableFlag = @"AirshipChat.enabled";
static NSString *const LegacyLocationEnableFlag = @"UALocationUpdatesEnabled";
static NSString *const LegacyAnalyticsEnableFlag = @"UAAnalyticsEnabled";
static NSString *const LegacyPushTokenRegistrationEnableFlag = @"UAPushTokenRegistrationEnabled";
static NSString *const LegacyDataCollectionEnableEnableFlag = @"com.urbanairship.data_collection_enabled";

@interface UAPrivacyManager()
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@end

@implementation UAPrivacyManager

+ (instancetype)privacyManagerWithDataStore:(UAPreferenceDataStore *)dataStore
                     defaultEnabledFeatures:(UAFeatures)defaultEnabledFeatures {
    return [[UAPrivacyManager alloc] initWithDataStore:dataStore
                                defaultEnabledFeatures:defaultEnabledFeatures
                                    notificationCenter:[NSNotificationCenter defaultCenter]];
}

- (instancetype)initWithDataStore:(UAPreferenceDataStore *)dataStore
           defaultEnabledFeatures:(UAFeatures)defaultEnabledFeatures
               notificationCenter:(NSNotificationCenter *)notificationCenter {
    self = [super init];
    if (self) {
        self.dataStore = dataStore;
        self.notificationCenter = notificationCenter;

        if ([self.dataStore keyExists:UAPrivacyManagerEnabledFeaturesKey]) {
            _enabledFeatures = [self.dataStore integerForKey:UAPrivacyManagerEnabledFeaturesKey];
        } else {
            _enabledFeatures = defaultEnabledFeatures;
        }
    }
    return self;
}

- (void)setEnabledFeatures:(UAFeatures)features {
    if (_enabledFeatures != features) {
        _enabledFeatures = features;
        [self.dataStore setObject:@(features) forKey:UAPrivacyManagerEnabledFeaturesKey];

        [[UADispatcher mainDispatcher] dispatchAsyncIfNecessary:^{
            [self.notificationCenter postNotificationName:UAPrivacyManagerEnabledFeaturesChangedEvent object:nil];
        }];
    }
}

- (void)enableFeatures:(UAFeatures)features {
    self.enabledFeatures |= features;
}

- (void)disableFeatures:(UAFeatures)features {
    self.enabledFeatures &= ~features;
}

- (BOOL)isEnabled:(UAFeatures)feature {
    if (feature == UAFeaturesNone) {
        return (self.enabledFeatures == UAFeaturesNone);
    } else {
        return (self.enabledFeatures & feature) == feature;
    }
}

- (BOOL)isAnyFeatureEnabled {
    return (self.enabledFeatures != UAFeaturesNone);
}

- (void)migrateData {
    UAFeatures features = self.enabledFeatures;
    if ([self.dataStore keyExists:LegacyDataCollectionEnableEnableFlag]) {
        if ([self.dataStore boolForKey:LegacyDataCollectionEnableEnableFlag]) {
            features = UAFeaturesAll;
        } else {
            features= UAFeaturesNone;
        }
        [self.dataStore removeObjectForKey:LegacyDataCollectionEnableEnableFlag];
    }

    if ([self.dataStore keyExists:UAPushEnabledKey]) {
        if (![self.dataStore boolForKey:UAPushEnabledKey]) {
            features &= ~UAFeaturesPush;
        }
        [self.dataStore removeObjectForKey:UAPushEnabledKey];
    }

    if ([self.dataStore keyExists:LegacyPushTokenRegistrationEnableFlag]) {
        if (![self.dataStore boolForKey:LegacyPushTokenRegistrationEnableFlag]) {
            features &= ~UAFeaturesPush;
        }
        [self.dataStore removeObjectForKey:LegacyPushTokenRegistrationEnableFlag];
    }

    if ([self.dataStore keyExists:LegacyAnalyticsEnableFlag]) {
        if (![self.dataStore boolForKey:LegacyAnalyticsEnableFlag]) {
            features &= ~UAFeaturesAnalytics;
        }
        [self.dataStore removeObjectForKey:LegacyAnalyticsEnableFlag];
    }

    if ([self.dataStore keyExists:LegacyIAAEnableFlag]) {
        if (![self.dataStore boolForKey:LegacyIAAEnableFlag]) {
            features &= ~UAFeaturesInAppAutomation;
        }
        [self.dataStore removeObjectForKey:LegacyIAAEnableFlag];
    }

    if ([self.dataStore keyExists:LegacyChatEnableFlag]) {
        if (![self.dataStore boolForKey:LegacyChatEnableFlag]) {
            features &= ~UAFeaturesChat;
        }
        [self.dataStore removeObjectForKey:LegacyChatEnableFlag];
    }

    if ([self.dataStore keyExists:LegacyLocationEnableFlag]) {
        if (![self.dataStore boolForKey:LegacyLocationEnableFlag]) {
            [self disableFeatures:UAFeaturesLocation];
        }
        [self.dataStore removeObjectForKey:LegacyLocationEnableFlag];
    }

    self.enabledFeatures = features;
}

@end
