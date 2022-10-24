/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"

@import AirshipCore;

@implementation UAAirshipBaseTest

- (void)tearDown {
    //[UAirship land];
    [super tearDown];
}

- (UAPreferenceDataStore *)dataStore {
    if (_dataStore) {
        return _dataStore;
    }
    _dataStore = [[UAPreferenceDataStore alloc] initWithAppKey:NSUUID.UUID.UUIDString];
    return _dataStore;
}

- (UARuntimeConfig *)config {
    if (!_config) {
        UAConfig *config = [[UAConfig alloc] init];
        config.inProduction = NO;
        config.site = UACloudSiteUS;
        config.developmentAppKey = @"test-app-key";
        config.developmentAppSecret = @"test-app-secret";
        config.requireInitialRemoteConfigEnabled = false;
        _config = [[UARuntimeConfig alloc] initWithConfig:config dataStore:self.dataStore];
    }
    
    
    return _config;
}

@end
