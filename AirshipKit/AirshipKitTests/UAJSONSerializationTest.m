/* Copyright 2010-2019 Urban Airship and Contributors */

#import <XCTest/XCTest.h>
#import "UAJSONSerialization+Internal.h"
#import "UAirship.h"

@interface UAJSONSerializationTest : XCTestCase

@end

@implementation UAJSONSerializationTest

- (void)testInvalidJSON {
    NSError *error = nil;

    XCTAssertNil([UAJSONSerialization dataWithJSONObject:[UAirship shared] options:NSJSONWritingPrettyPrinted error:&error], @"Attempting to serialize an invalid JSON object should result in a nil output");
    XCTAssertNotNil(error, @"Attempting to serialize an invalid JSON object should generate an error");
}

- (void)testValidJSON {
    NSError *error = nil;(

    XCTAssertNotNil([UAJSONSerialization dataWithJSONObject:@{@"Valid JSON object" : @(YES)} options:NSJSONWritingPrettyPrinted error:&error], @"Attempting to serialize an invalid JSON object should result in a nil output"));
    XCTAssertNil(error, @"Attempting to serialize an valid JSON object should not generate an error");
}

@end
