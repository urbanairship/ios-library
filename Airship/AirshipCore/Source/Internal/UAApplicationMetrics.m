/* Copyright Airship and Contributors */

#import "UAApplicationMetrics+Internal.h"
#import "UAUtils+Internal.h"

#if __has_include("AirshipCore/AirshipCore-Swift.h")
#import <AirshipCore/AirshipCore-Swift.h>
#elif __has_include("Airship/Airship-Swift.h")
#import <Airship/Airship-Swift.h>
#endif

@interface UAApplicationMetrics()
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (nonatomic, strong) UADate *date;
@property (nonatomic, assign) BOOL isAppVersionUpdated;
@property (nonatomic, strong) UAPrivacyManager *privacyManager;
@end

@implementation UAApplicationMetrics
NSString *const UAApplicationMetricLastOpenDate = @"UAApplicationMetricLastOpenDate";
NSString *const UAApplicationMetricsLastAppVersion = @"UAApplicationMetricsLastAppVersion";

- (instancetype)initWithDataStore:(UAPreferenceDataStore *)dataStore
                   privacyManager:(UAPrivacyManager *)privacyManager
               notificationCenter:(NSNotificationCenter *)notificationCenter
                             date:(UADate *)date {

    self = [super init];
    if (self) {
        self.dataStore = dataStore;
        self.privacyManager = privacyManager;
        self.date = date;

        [self updateData];

        [notificationCenter addObserver:self
                               selector:@selector(applicationDidBecomeActive)
                                   name:UAAppStateTracker.didBecomeActiveNotification
                                 object:nil];

        [notificationCenter addObserver:self
                               selector:@selector(updateData)
                                   name:UAPrivacyManager.changeEvent
                                 object:nil];
    }

    return self;
}

+ (instancetype)applicationMetricsWithDataStore:(UAPreferenceDataStore *)dataStore privacyManager:(UAPrivacyManager *)privacyManager {
    return [[UAApplicationMetrics alloc] initWithDataStore:dataStore
                                            privacyManager:privacyManager
                                        notificationCenter:[NSNotificationCenter defaultCenter]
                                                      date:[[UADate alloc] init]];
}

+ (instancetype)applicationMetricsWithDataStore:(UAPreferenceDataStore *)dataStore
                                 privacyManager:(UAPrivacyManager *)privacyManager
                             notificationCenter:(NSNotificationCenter *)notificationCenter
                                           date:(UADate *)date {
    return [[UAApplicationMetrics alloc] initWithDataStore:dataStore
                                            privacyManager:privacyManager
                                        notificationCenter:notificationCenter
                                                      date:date];
}

- (NSDate *)lastApplicationOpenDate {
    return [self.dataStore objectForKey:UAApplicationMetricLastOpenDate];
}

- (NSString *)currentAppVersion {
    return [UAUtils bundleShortVersionString];
}

- (void)applicationDidBecomeActive {
    if ([self.privacyManager isEnabled:UAFeaturesInAppAutomation] || [self.privacyManager isEnabled:UAFeaturesAnalytics]) {
        [self.dataStore setObject:[self.date now] forKey:UAApplicationMetricLastOpenDate];
    }
}

- (void)updateData {
    if ([self.privacyManager isEnabled:UAFeaturesInAppAutomation] || [self.privacyManager isEnabled:UAFeaturesAnalytics]) {
        NSString *lastVersion = [self.dataStore objectForKey:UAApplicationMetricsLastAppVersion];
        NSString *currentVersion = [self currentAppVersion];

        if (lastVersion && [UAUtils compareVersion:lastVersion toVersion:currentVersion] == NSOrderedAscending) {
            self.isAppVersionUpdated = YES;
        }

        [self.dataStore setObject:currentVersion forKey:UAApplicationMetricsLastAppVersion];
    } else {
        [self.dataStore removeObjectForKey:UAApplicationMetricLastOpenDate];
        [self.dataStore removeObjectForKey:UAApplicationMetricsLastAppVersion];
    }
}

@end

