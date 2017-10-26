/* Copyright 2017 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UAWebViewCallData.h"

@interface UAWebViewCallDataTest : UABaseTest
@property (nonatomic, strong) id mockWebView;
@end

@implementation UAWebViewCallDataTest

- (void)setUp {
    [super setUp];
    self.mockWebView = [self mockForClass:[UIWebView class]];
}

- (void)tearDown {
    [self.mockWebView stopMocking];
    [super tearDown];
}

- (void)testCallDataForURL {
    UAWebViewCallData *data = [UAWebViewCallData callDataForURL:
                               [NSURL URLWithString:@"uairship://whatever/argument-one/argument-two?foo=bar&foo=barbar&foo"] webView:self.mockWebView];
    XCTAssertNotNil(data, @"data should be non-nil");
    XCTAssertEqual(data.arguments.count, (NSUInteger)2, @"data should have two arguments");
    XCTAssertEqualObjects([data.arguments firstObject], @"argument-one", @"first arg should be 'argument-one'");
    XCTAssertEqualObjects([data.arguments objectAtIndex:1], @"argument-two", @"second arg should be 'argument-two'");

    NSArray *expectedValues = @[@"bar", @"barbar", [NSNull null]];
    XCTAssertEqualObjects([data.options objectForKey:@"foo"], expectedValues, @"key 'foo' should have values 'bar', 'barbar', and null");

    data = [UAWebViewCallData callDataForURL:[NSURL URLWithString:@"uairship://whatever/?foo=bar"] webView:self.mockWebView];
    XCTAssertNotNil(data, @"data should be non-nil");
    XCTAssertEqual(data.arguments.count, (NSUInteger)0, @"data should have no arguments");

    expectedValues = @[@"bar"];
    XCTAssertEqualObjects([data.options objectForKey:@"foo"], expectedValues, @"key 'foo' should have values 'bar'");
}

- (void)testCallDataForURLEncodedArguments {
    UAWebViewCallData *data = [UAWebViewCallData callDataForURL:
                               [NSURL URLWithString:@"uairship://run-action-cb/%5Eu/%22https%3A%2F%2Fdocs.urbanairship.com%2Fengage%2Frich-content-editor%2F%23rich-content-image%22/ua-cb-2?query%20argument=%5E"] webView:self.mockWebView];

    XCTAssertEqual(data.arguments.count, 3);
    XCTAssertEqualObjects([data.arguments objectAtIndex:0], @"^u");
    XCTAssertEqualObjects([data.arguments objectAtIndex:1], @"\"https://docs.urbanairship.com/engage/rich-content-editor/#rich-content-image\"");
    XCTAssertEqualObjects([data.arguments objectAtIndex:2], @"ua-cb-2");

    XCTAssertEqualObjects(data.options[@"query argument"][0], @"^");

}

@end
