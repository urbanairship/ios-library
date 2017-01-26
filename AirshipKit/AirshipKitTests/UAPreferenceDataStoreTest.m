/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <XCTest/XCTest.h>
#import "UAPreferenceDataStore+Internal.h"

@interface UAPreferenceDataStoreTest : XCTestCase

@property(nonatomic, strong) UAPreferenceDataStore *dataStore;

@end

@implementation UAPreferenceDataStoreTest

- (void)setUp {
    [super setUp];
    self.dataStore = [UAPreferenceDataStore preferenceDataStoreWithKeyPrefix:@"asfa"];
}

- (void)tearDown {
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

@end
