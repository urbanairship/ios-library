/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UAirship+Internal.h"
#import "UARuntimeConfig+Internal.h"

@import AirshipCore;

@implementation UAAirshipBaseTest

- (void)tearDown {
    [UAirship land];
    [super tearDown];
}

- (UAPreferenceDataStore *)dataStore {
    if (_dataStore) {
        return _dataStore;
    }
    _dataStore = [[UAPreferenceDataStore alloc] initWithKeyPrefix:NSUUID.UUID.UUIDString];
    return _dataStore;
}

- (UATestRuntimeConfig *)config {
    if (_config) {
        return _config;
    }

    _config = [UATestRuntimeConfig testConfig];
    _config.appKey = [NSString stringWithFormat:@"dev-appKey-%@", self.name];
    _config.appSecret = [NSString stringWithFormat:@"dev-appSecret-%@", self.name];
    return _config;
}

@end
