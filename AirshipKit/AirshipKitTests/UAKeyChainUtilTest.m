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
#import "UAKeychainUtils+Internal.h"
#import <OCMock/OCMock.h>

@interface UAKeyChainUtilTest : XCTestCase
@property id mockBundle;
@end

@implementation UAKeyChainUtilTest

- (void)setUp {
    [super setUp];

    self.mockBundle = [OCMockObject niceMockForClass:[NSBundle class]];
    [[[self.mockBundle stub] andReturn:self.mockBundle] mainBundle];
    [[[self.mockBundle stub] andReturn:@{@"CFBundleIdentifier": @"com.urbanairship.test"}] infoDictionary];
  }

- (void)tearDown {
    [self.mockBundle stopMocking];
    [super tearDown];
}

/**
 * Test creating user in the keychain.
 */

// Todo: fix keychain entitlements in test
/*
- (void)testCreateUserKeychainValues {
    [UAKeychainUtils createKeychainValueForUsername:@"user one" withPassword:@"password one" forIdentifier:@"identifier one"];
    [UAKeychainUtils createKeychainValueForUsername:@"user two" withPassword:@"password two" forIdentifier:@"identifier two"];

    XCTAssertEqualObjects(@"user one", [UAKeychainUtils getUsername:@"identifier one"]);
    XCTAssertEqualObjects(@"password one", [UAKeychainUtils getPassword:@"identifier one"]);

    XCTAssertEqualObjects(@"user two", [UAKeychainUtils getUsername:@"identifier two"]);
    XCTAssertEqualObjects(@"password two", [UAKeychainUtils getPassword:@"identifier two"]);

    // Delete only the user two
    [UAKeychainUtils deleteKeychainValue:@"identifier two"];

    // Verify user one still exists
    XCTAssertEqualObjects(@"user one", [UAKeychainUtils getUsername:@"identifier one"]);
    XCTAssertEqualObjects(@"password one", [UAKeychainUtils getPassword:@"identifier one"]);

    // Verify user two is gone
    XCTAssertNil([UAKeychainUtils getUsername:@"identifier two"]);
    XCTAssertNil([UAKeychainUtils getPassword:@"identifier two"]);
}
 */

/**
 * Test getting the Device ID.
 */
- (void)testDeviceID {
    NSString *deviceID = [UAKeychainUtils getDeviceID];
    XCTAssertNotNil(deviceID, @"Device ID should always return a generated device ID.");
    XCTAssertEqualObjects(deviceID, [UAKeychainUtils getDeviceID], @"Device ID should return the same Device ID.");
}


@end
