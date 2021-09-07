/* Copyright Airship and Contributors */

#import "UABaseTest.h"

@import AirshipCore;

@interface UAJSONUtilsTest : UABaseTest

@end

@implementation UAJSONUtilsTest

- (void)testInvalidJSON {
    NSError *error = nil;
    XCTAssertNil([UAJSONUtils dataWithObject:[[NSObject alloc] init] options:NSJSONWritingPrettyPrinted error:&error]);
    XCTAssertNotNil(error);
}

- (void)testValidJSON {
    NSError *error = nil;(

    XCTAssertNotNil([UAJSONUtils dataWithObject:@{@"Valid JSON object" : @(YES)} options:NSJSONWritingPrettyPrinted error:&error], @"Attempting to serialize an invalid JSON object should result in a nil output"));
    XCTAssertNil(error, @"Attempting to serialize an valid JSON object should not generate an error");
}

@end
