/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UAirship+Internal.h"
#import "UARuntimeConfig+Internal.h"

@implementation UAAirshipBaseTest

- (void)tearDown {
    [UAirship land];

    if (_dataStore) {
        [_dataStore removeAll];
    }
    [super tearDown];
}

- (UAPreferenceDataStore *)dataStore {
    if (_dataStore) {
        return _dataStore;
    }

    // self.name is "-[TEST_CLASS TEST_NAME]". For key prefix, re-format to "TEST_CLASS.TEST_NAME", e.g. UAAnalyticsTest.testAddEvent
    NSString *prefStorePrefix = [self.name stringByReplacingOccurrencesOfString:@"\\s"
                                                                     withString:@"."
                                                                        options:NSRegularExpressionSearch
                                                                          range:NSMakeRange(0, [self.name length])];
    prefStorePrefix = [prefStorePrefix stringByReplacingOccurrencesOfString:@"-|\\[|\\]"
                                                                 withString:@""
                                                                    options:NSRegularExpressionSearch
                                                                      range:NSMakeRange(0, [prefStorePrefix length])];

    _dataStore = [UAPreferenceDataStore preferenceDataStoreWithKeyPrefix:prefStorePrefix];

    [_dataStore removeAll];

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
