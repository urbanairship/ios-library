/* Copyright Airship and Contributors */

#import "UABaseTest.h"

@import AirshipCore;

@interface UAJavaScriptCommandTest : UABaseTest
@end

@implementation UAJavaScriptCommandTest

- (void)testCommandForURL {
    NSURL *URL = [NSURL URLWithString:@"uairship://whatever/argument-one/argument-two?foo=bar&foo=barbar&foo"];
    UAJavaScriptCommand *command = [[UAJavaScriptCommand alloc] initWithURL:URL];

    XCTAssertNotNil(command, @"data should be non-nil");
    XCTAssertEqual(command.arguments.count, (NSUInteger)2, @"data should have two arguments");
    XCTAssertEqualObjects([command.arguments firstObject], @"argument-one", @"first arg should be 'argument-one'");
    XCTAssertEqualObjects([command.arguments objectAtIndex:1], @"argument-two", @"second arg should be 'argument-two'");

    NSArray *expectedValues = @[@"bar", @"barbar", @""];
    XCTAssertEqualObjects([command.options objectForKey:@"foo"], expectedValues, @"key 'foo' should have values 'bar', 'barbar', and ''");
}

- (void)testCommandForURLSlashBeforeArgs {
    NSURL *URL = [NSURL URLWithString:@"uairship://whatever/?foo=bar"];
    UAJavaScriptCommand *command = [[UAJavaScriptCommand alloc] initWithURL:URL];
    XCTAssertNotNil(command, @"data should be non-nil");
    XCTAssertEqual(command.arguments.count, (NSUInteger)0, @"data should have no arguments");
    XCTAssertEqualObjects([command.options objectForKey:@"foo"], @[@"bar"], @"key 'foo' should have values 'bar'");
}

- (void)testCallDataForURLEncodedArguments {
    NSURL *URL = [NSURL URLWithString:@"uairship://run-action-cb/%5Eu/%22https%3A%2F%2Fdocs.urbanairship.com%2Fengage%2Frich-content-editor%2F%23rich-content-image%22/ua-cb-2?query%20argument=%5E"];
    UAJavaScriptCommand *command = [[UAJavaScriptCommand alloc] initWithURL:URL];

    XCTAssertEqual(command.arguments.count, 3);
    XCTAssertEqualObjects([command.arguments objectAtIndex:0], @"^u");
    XCTAssertEqualObjects([command.arguments objectAtIndex:1], @"\"https://docs.urbanairship.com/engage/rich-content-editor/#rich-content-image\"");
    XCTAssertEqualObjects([command.arguments objectAtIndex:2], @"ua-cb-2");
    XCTAssertEqualObjects(command.options[@"query argument"][0], @"^");
}

@end
