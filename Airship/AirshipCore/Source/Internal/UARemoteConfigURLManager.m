/* Copyright Airship and Contributors */

#import "UARemoteConfigURLManager.h"
#import "UARemoteConfig.h"
#import "UARemoteConfigManager+Internal.h"

static NSString * const UARemoteConfigKey = @"com.urbanairship.config.remote_config_key";

NSNotificationName const UARemoteConfigURLManagerConfigUpdated = @"com.urbanairship.remote_url_config_updated";

@interface UARemoteConfigURLManager()
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@property (atomic, strong, readwrite) UARemoteConfig *urlConfig;
@end

@implementation UARemoteConfigURLManager

+ (instancetype)remoteConfigURLManagerWithDataStore:(UAPreferenceDataStore *)dataStore {
    return [[UARemoteConfigURLManager alloc] initWithDataStore:dataStore
                                            notificationCenter:[NSNotificationCenter defaultCenter]];
}

+ (instancetype)remoteConfigURLManagerWithDataStore:(UAPreferenceDataStore *)dataStore
                                 notificationCenter:(NSNotificationCenter *)notificationCenter {
    return [[UARemoteConfigURLManager alloc] initWithDataStore:dataStore
                                            notificationCenter:notificationCenter];

}
- (instancetype)initWithDataStore:(UAPreferenceDataStore *)dataStore
               notificationCenter:(NSNotificationCenter *)notificationCenter {

   
    self = [super init];
 
    if (self) {
        self.notificationCenter = notificationCenter;
        self.dataStore = dataStore;
        [self restoreConfig];


        [self.notificationCenter addObserver:self
                                    selector:@selector(onRemoteConfigUpdated:)
                                        name:UAAirshipRemoteConfigUpdatedEvent
                                      object:nil];
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
    self.urlConfig = [UARemoteConfig configWithRemoteData:configData];
}

- (void)onRemoteConfigUpdated:(NSNotification *)notification {
    NSDictionary *remoteConfigData = notification.userInfo[UAAirshipRemoteConfigUpdatedKey];
    UARemoteConfig *remoteConfig = [UARemoteConfig configWithRemoteData:remoteConfigData];

    if (![remoteConfig isEqual:self.urlConfig]) {
        self.urlConfig = remoteConfig;
        [self.dataStore setObject:remoteConfigData forKey:UARemoteConfigKey];
        [self.notificationCenter postNotificationName:UARemoteConfigURLManagerConfigUpdated object:nil];
    }
}

@end
