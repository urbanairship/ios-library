/* Copyright 2018 Urban Airship and Contributors */


#import "UAApplicationMetrics+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAUtils.h"

@interface UAApplicationMetrics()
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (nonatomic, assign) BOOL isAppVersionUpdated;
@end

@implementation UAApplicationMetrics
NSString *const UAApplicationMetricLastOpenDate = @"UAApplicationMetricLastOpenDate";
NSString *const UAApplicationMetricsLastAppVersion = @"UAApplicationMetricsLastAppVersion";

- (instancetype)initWithDataStore:(UAPreferenceDataStore *)dataStore {
    self = [super init];
    if (self) {
        self.dataStore = dataStore;
        // App inactive/active for incoming calls, notification center, and taskbar
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didBecomeActive)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
        [self checkAppVersion];
    }

    return self;
}

+ (instancetype)applicationMetricsWithDataStore:(UAPreferenceDataStore *)dataStore {
    return [[UAApplicationMetrics alloc] initWithDataStore:dataStore];
}

- (void)didBecomeActive {
    self.lastApplicationOpenDate = [NSDate date];
}

- (NSDate *)lastApplicationOpenDate {
    return [self.dataStore objectForKey:UAApplicationMetricLastOpenDate];
}

- (void)setLastApplicationOpenDate:(NSDate *)date {
    [self.dataStore setObject:date forKey:UAApplicationMetricLastOpenDate];
}

- (NSString *)currentAppVersion {
    return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
}

- (NSString *)lastAppVersion {
    return [self.dataStore objectForKey:UAApplicationMetricsLastAppVersion];
}

- (void)checkAppVersion {
    NSString *lastVersion = [self lastAppVersion];
    NSString *currentVersion = [self currentAppVersion];

    if (!lastVersion || [UAUtils compareVersion:lastVersion toVersion:currentVersion] == NSOrderedAscending) {
        [self.dataStore setObject:currentVersion forKey:UAApplicationMetricsLastAppVersion];
        self.isAppVersionUpdated = YES;
    }
}

@end
