/* Copyright 2010-2019 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UAirship+Internal.h"

@interface UABaseTest()
@property (nonatomic, strong) NSPointerArray *mocks;
@end

const NSTimeInterval UATestExpectationTimeOut = 5;

@implementation UABaseTest

- (void)tearDown {
    for (id mock in self.mocks) {
        [mock stopMocking];
    }
    self.mocks = nil;
    [UAirship land];

    if (_dataStore) {
        [_dataStore removeAll];
    }
    [super tearDown];
}

- (id)mockForProtocol:(Protocol *)protocol {
    id mock = OCMProtocolMock(protocol);
    [self addMock:mock];
    return mock;
}

- (id)partialMockForObject:(NSObject *)object {
    id mock = OCMPartialMock(object);
    [self addMock:mock];
    return mock;
}

- (id)strictMockForClass:(Class)aClass {
    id mock = OCMStrictClassMock(aClass);
    [self addMock:mock];
    return mock;
}

- (id)mockForClass:(Class)aClass {
    id mock = OCMClassMock(aClass);
    [self addMock:mock];
    return mock;
}

- (void)addMock:(id)mock {
    if (!self.mocks) {
        self.mocks = [NSPointerArray weakObjectsPointerArray];
    }
    [self.mocks addPointer:(__bridge void *)mock];
}

- (void)waitForTestExpectations:(NSArray<XCTestExpectation *> *)expectations {
    [self waitForExpectations:expectations timeout:UATestExpectationTimeOut];
}

- (void)waitForTestExpectations {
    [self waitForExpectationsWithTimeout:UATestExpectationTimeOut handler:nil];
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

- (UAConfig *)config {
    if (_config) {
        return _config;
    }

    _config = [UAConfig config];
    _config.developmentAppKey = [NSString stringWithFormat:@"dev-appKey-%@", self.name];
    _config.developmentAppSecret = [NSString stringWithFormat:@"dev-appSecret-%@", self.name];
    _config.productionAppKey = [NSString stringWithFormat:@"prod-appKey-%@", self.name];
    _config.productionAppSecret = [NSString stringWithFormat:@"prod-appSecret-%@", self.name];
    return _config;
}

@end
