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
@property (nonatomic, assign) UAFeatures defaultEnabledFeatures;
@end

@implementation UAPrivacyManager

+ (instancetype)privacyManagerWithDataStore:(UAPreferenceDataStore *)dataStore
                     defaultEnabledFeatures:(UAFeatures)features {
    return [[UAPrivacyManager alloc] initWithDataStore:dataStore
                                defaultEnabledFeatures:(UAFeatures)features
                                    notificationCenter:[NSNotificationCenter defaultCenter]];
}

- (instancetype)initWithDataStore:(UAPreferenceDataStore *)dataStore
           defaultEnabledFeatures:(UAFeatures)features
               notificationCenter:(NSNotificationCenter *)notificationCenter {
    self = [super init];
    if (self) {
        self.dataStore = dataStore;
        self.notificationCenter = notificationCenter;
        self.defaultEnabledFeatures = features;
    }
    return self;
}

- (void)setEnabledFeatures:(UAFeatures)features {
    NSInteger enabledFeatures = features;
    [self.dataStore setObject:@(enabledFeatures) forKey:UAPrivacyManagerEnabledFeaturesKey];
    [self.notificationCenter postNotificationName:UAPrivacyManagerEnabledFeaturesChangedEvent object:nil];
}

- (UAFeatures)enabledFeatures {
    NSNumber *enabledFeatures = [self.dataStore objectForKey:UAPrivacyManagerEnabledFeaturesKey];
    if (!enabledFeatures) {
        return self.defaultEnabledFeatures;
    }
    return [enabledFeatures integerValue];
}

- (void)enableFeatures:(UAFeatures)features {
    NSInteger updatedFeatures = ([self enabledFeatures] | features);
    [self.dataStore setObject:@(updatedFeatures) forKey:UAPrivacyManagerEnabledFeaturesKey];
    [self.notificationCenter postNotificationName:UAPrivacyManagerEnabledFeaturesChangedEvent object:nil];
}

- (void)disableFeatures:(UAFeatures)features {
    NSInteger updatedFeatures = ([self enabledFeatures] & ~features);
    [self.dataStore setObject:@(updatedFeatures) forKey:UAPrivacyManagerEnabledFeaturesKey];
    [self.notificationCenter postNotificationName:UAPrivacyManagerEnabledFeaturesChangedEvent object:nil];
}

- (BOOL)isEnabled:(UAFeatures)feature {
    NSInteger enabledFeatures = [self enabledFeatures];
    
    if (feature == UAFeaturesNone) {
        return (enabledFeatures == UAFeaturesNone);
    } else {
        return (enabledFeatures & feature) == feature;
    }
}

- (BOOL)isAnyFeatureEnabled {
    NSInteger enabledFeatures = [self enabledFeatures];
    return (enabledFeatures != UAFeaturesNone);
}

- (void)migrateData {
    if ([self.dataStore keyExists:UAirshipDataCollectionEnabledKey]) {
        if ([self.dataStore boolForKey:UAirshipDataCollectionEnabledKey]) {
            [self enableFeatures:UAFeaturesNone];
        } else {
            [self enableFeatures:UAFeaturesAll];
        }
        [self.dataStore removeObjectForKey:UAirshipDataCollectionEnabledKey];
    }
    if ([self.dataStore keyExists:UAPushEnabledKey]) {
        if (![self.dataStore boolForKey:UAPushEnabledKey]) {
            [self disableFeatures:UAFeaturesPush];
        }
        [self.dataStore removeObjectForKey:UAPushEnabledKey];
    }
    if ([self.dataStore keyExists:UAPushTokenRegistrationEnabledKey]) {
        if (![self.dataStore boolForKey:UAPushTokenRegistrationEnabledKey]) {
            [self disableFeatures:UAFeaturesPush];
        }
        [self.dataStore removeObjectForKey:UAPushTokenRegistrationEnabledKey];
    }
    if ([self.dataStore keyExists:kUAAnalyticsEnabled]) {
        if (![self.dataStore boolForKey:kUAAnalyticsEnabled]) {
            [self disableFeatures:UAFeaturesAnalytics];
        }
        [self.dataStore removeObjectForKey:kUAAnalyticsEnabled];
    }
    if ([self.dataStore keyExists:UAInAppAutomationEnabledKey]) {
        if (![self.dataStore boolForKey:UAInAppAutomationEnabledKey]) {
            [self disableFeatures:UAFeaturesInAppAutomation];
        }
        [self.dataStore removeObjectForKey:UAInAppAutomationEnabledKey];
    }
    if ([self.dataStore keyExists:UAChatEnabledKey]) {
        if (![self.dataStore boolForKey:UAChatEnabledKey]) {
            [self disableFeatures:UAFeaturesChat];
        }
        [self.dataStore removeObjectForKey:UAChatEnabledKey];
    }
}

@end
