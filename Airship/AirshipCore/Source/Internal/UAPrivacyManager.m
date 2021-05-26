/* Copyright Airship and Contributors */

#import "UAPrivacyManager+Internal.h"
#import "UAComponent.h"
#import "UAPush+Internal.h"

NSString *const UAPrivacyManagerEnabledFeaturesKey = @"com.urbanairship.privacymanager.enabledfeatures";
NSString *const UAPrivacyManagerEnabledFeaturesChangedEvent = @"com.urbanairship.privacymanager.enabledfeatures_changed";
NSString *const UAInAppAutomationEnabledKey = @"UAInAppMessageManagerEnabled";
NSString *const UAChatEnabledKey = @"AirshipChat.enabled";

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
    if ([self.dataStore keyExists:UAirshipDataCollectionEnabledKey]) {
        if ([self.dataStore boolForKey:UAirshipDataCollectionEnabledKey]) {
            features = UAFeaturesNone;
        } else {
            features= UAFeaturesAll;
        }
        [self.dataStore removeObjectForKey:UAirshipDataCollectionEnabledKey];
    }

    if ([self.dataStore keyExists:UAPushEnabledKey]) {
        if (![self.dataStore boolForKey:UAPushEnabledKey]) {
            features &= ~UAFeaturesPush;
        }
        [self.dataStore removeObjectForKey:UAPushEnabledKey];
    }

    if ([self.dataStore keyExists:UAPushTokenRegistrationEnabledKey]) {
        if (![self.dataStore boolForKey:UAPushTokenRegistrationEnabledKey]) {
            features &= ~UAFeaturesPush;
        }
        [self.dataStore removeObjectForKey:UAPushTokenRegistrationEnabledKey];
    }

    if ([self.dataStore keyExists:kUAAnalyticsEnabled]) {
        if (![self.dataStore boolForKey:kUAAnalyticsEnabled]) {
            features &= ~UAFeaturesAnalytics;
        }
        [self.dataStore removeObjectForKey:kUAAnalyticsEnabled];
    }

    if ([self.dataStore keyExists:UAInAppAutomationEnabledKey]) {
        if (![self.dataStore boolForKey:UAInAppAutomationEnabledKey]) {
            features &= ~UAFeaturesInAppAutomation;
        }
        [self.dataStore removeObjectForKey:UAInAppAutomationEnabledKey];
    }

    if ([self.dataStore keyExists:UAChatEnabledKey]) {
        if (![self.dataStore boolForKey:UAChatEnabledKey]) {
            features &= ~UAFeaturesChat;
        }
        [self.dataStore removeObjectForKey:UAChatEnabledKey];
    }

    self.enabledFeatures = features;
}

@end
