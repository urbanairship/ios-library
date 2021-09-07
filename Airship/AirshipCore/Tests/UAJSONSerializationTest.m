/* Copyright Airship and Contributors */

#import "UABaseTest.h"

@import AirshipCore;

@interface UAJSONSerializationTest : UABaseTest

@end

@implementation UAJSONSerializationTest

- (void)testInvalidJSON {
    NSError *error = nil;

    XCTAssertThrows([UAJSONSerialization dataWithJSONObject:[[NSObject alloc] init] options:NSJSONWritingPrettyPrinted error:&error], @"Attempting to serialize an invalid JSON object should result in a nil output");

}

- (void)testValidJSON {
    NSError *error = nil;(

    XCTAssertNotNil([UAJSONSerialization dataWithJSONObject:@{@"Valid JSON object" : @(YES)} options:NSJSONWritingPrettyPrinted error:&error], @"Attempting to serialize an invalid JSON object should result in a nil output"));
    XCTAssertNil(error, @"Attempting to serialize an valid JSON object should not generate an error");
}

@end
