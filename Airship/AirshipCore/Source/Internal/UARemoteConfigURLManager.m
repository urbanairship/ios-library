/* Copyright Airship and Contributors */

#import "UARemoteConfigURLManager.h"
#import "UARemoteConfig.h"
#import "UARemoteConfigManager+Internal.h"

static NSString * const UARemoteConfigKey = @"com.urbanairship.config.remote_config_key";

@interface UARemoteConfigURLManager()

@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (atomic, strong, readwrite) UARemoteConfig *urlConfig;

@end

@implementation UARemoteConfigURLManager

+ (instancetype)remoteConfigURLManagerWithDataStore:(UAPreferenceDataStore *)dataStore {
    return [[UARemoteConfigURLManager alloc] initWithDataStore:dataStore];
}

- (instancetype)initWithDataStore:(UAPreferenceDataStore *)dataStore {
   
    self = [super init];
 
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onRemoteConfigUpdated:)
                                                     name:UAAirshipRemoteConfigUpdatedEvent
                                                   object:nil];
        self.dataStore = dataStore;
        [self restoreConfig];
    }
   
    return self;
    
}

- (NSString *)deviceAPIURL {
    return self.urlConfig.deviceAPIURL;
}

- (NSString *)remoteDataURL {
    return self.urlConfig.remoteDataURL;;
}

- (NSString *)analyticsURL {
    return self.urlConfig.analyticsURL;
}

- (void)restoreConfig {
    NSDictionary *configData = [self.dataStore objectForKey:UARemoteConfigKey];
    UARemoteConfig *config = [UARemoteConfig configWithRemoteData:configData];
    [self updateConfig:config];
}

- (void)updateConfig:(UARemoteConfig *)remoteConfig {
    self.urlConfig = [UARemoteConfig configWithRemoteDataURL:remoteConfig.remoteDataURL
                                                deviceAPIURL:remoteConfig.deviceAPIURL
                                                analyticsURL:remoteConfig.analyticsURL];
}

- (void)onRemoteConfigUpdated:(NSNotification *)notification {
    NSDictionary *remoteConfigData = notification.userInfo[UAAirshipRemoteConfigUpdatedKey];
    UARemoteConfig *remoteConfig = [UARemoteConfig configWithRemoteData:remoteConfigData];
    [self updateConfig:remoteConfig];
    [self.dataStore setObject:remoteConfigData forKey:UARemoteConfigKey];
}

@end
