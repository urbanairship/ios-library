/* Copyright Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UAKeychainUtils+Internal.h"

@interface UAKeyChainUtilTest : UABaseTest
@property id mockBundle;
@end

@implementation UAKeyChainUtilTest

- (void)setUp {
    [super setUp];

    self.mockBundle = [self mockForClass:[NSBundle class]];
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
