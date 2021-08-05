/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"

@import AirshipCore;

@interface UAPreferenceDataStoreTest : UAAirshipBaseTest

@end

@implementation UAPreferenceDataStoreTest

- (void)tearDown {
    [super tearDown];
}

- (void)testKeyIsStoredAndRetrieved {
    NSString *value = [[NSProcessInfo processInfo] globallyUniqueString];
    [self.dataStore setObject:value forKey:@"key"];
    XCTAssertEqualObjects([self.dataStore objectForKey:@"key"], value);
}

- (void)testKeyisRemoved {
    NSString *value = [[NSProcessInfo processInfo] globallyUniqueString];
    [self.dataStore setObject:value forKey:@"key"];
    XCTAssertEqualObjects([self.dataStore objectForKey:@"key"], value);
    [self.dataStore removeObjectForKey:@"key"];
    XCTAssertNil([self.dataStore objectForKey:@"key"]);
}

- (void)testMigration {
    NSString *prefix = NSUUID.UUID.UUIDString;
    [NSUserDefaults.standardUserDefaults setBool:YES forKey:[NSString stringWithFormat:@"%@some-key", prefix]];
    UAPreferenceDataStore *dataStore = [[UAPreferenceDataStore alloc] initWithKeyPrefix:prefix];
    XCTAssertTrue([dataStore boolForKey:@"some-key"]);
}

@end
