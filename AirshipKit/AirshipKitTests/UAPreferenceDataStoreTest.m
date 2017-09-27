/* Copyright 2017 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UAPreferenceDataStore+Internal.h"

@interface UAPreferenceDataStoreTest : UABaseTest

@property(nonatomic, strong) UAPreferenceDataStore *dataStore;

@end

@implementation UAPreferenceDataStoreTest

- (void)setUp {
    [super setUp];
    self.dataStore = [UAPreferenceDataStore preferenceDataStoreWithKeyPrefix:@"asfa"];
}

- (void)tearDown {
    [self.dataStore removeAll];

    [super tearDown];
    [NSUserDefaults resetStandardUserDefaults];
}

- (void)testMigrateUnprefixedKeys {

    NSArray *stringArray = @[@"first", @"second", @"third"];
    NSArray *array = @[@(2), @"string"];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:@"oh hi" forKey:@"string"];
    [defaults setObject:stringArray forKey:@"string_array"];
    [defaults setObject:array forKey:@"array"];

    [defaults setURL:[NSURL URLWithString:@"http://urbanairship.com"] forKey:@"url"];
    [defaults setInteger:5 forKey:@"integer"];
    [defaults setBool:YES forKey:@"bool"];
    [defaults setDouble:200.12 forKey:@"double"];
    [defaults setFloat:1.2f forKey:@"float"];

    NSArray *keys = @[@"string", @"string_array", @"array", @"url", @"integer", @"bool", @"double", @"float"];

    [self.dataStore migrateUnprefixedKeys:keys];

    XCTAssertEqualObjects(@"oh hi", [self.dataStore stringForKey:@"string"]);
    XCTAssertEqualObjects(stringArray, [self.dataStore stringArrayForKey:@"string_array"]);
    XCTAssertEqualObjects(array, [self.dataStore arrayForKey:@"array"]);
    XCTAssertEqualObjects(@"http://urbanairship.com", [self.dataStore URLForKey:@"url"].absoluteString);
    XCTAssertEqual(5, [self.dataStore integerForKey:@"integer"]);
    XCTAssertEqual(YES, [self.dataStore boolForKey:@"bool"]);
    XCTAssertEqual(200.12, [self.dataStore doubleForKey:@"double"]);
    XCTAssertEqual(1.2f, [self.dataStore floatForKey:@"float"]);

    // Make sure all the previous values have been removed
    for (NSString *key in keys) {
        XCTAssertNil([defaults objectForKey:key]);
    }
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
    [self.dataStore removeAll];
    XCTAssertNil([self.dataStore objectForKey:@"key"]);
}

@end
