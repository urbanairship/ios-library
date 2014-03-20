
#import <XCTest/XCTest.h>
#import "UAWebViewCallData.h"

@interface UAWebViewCallDataTest : XCTestCase
@end

@implementation UAWebViewCallDataTest

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testcallDataForURL {
    UAWebViewCallData *data = [UAWebViewCallData callDataForURL:
                               [NSURL URLWithString:@"uairship://whatever/argument-one/argument-two?foo=bar&foo=barbar&foo"] webView:nil];
    XCTAssertNotNil(data, @"data should be non-nil");
    XCTAssertEqual(data.arguments.count, (NSUInteger)2, @"data should have two arguments");
    XCTAssertEqualObjects([data.arguments firstObject], @"argument-one", @"first arg should be 'argument-one'");
    XCTAssertEqualObjects([data.arguments objectAtIndex:1], @"argument-two", @"second arg should be 'argument-two'");

    NSArray *expectedValues = @[@"bar", @"barbar", [NSNull null]];
    XCTAssertEqualObjects([data.options objectForKey:@"foo"], expectedValues, @"key 'foo' should have values 'bar', 'barbar', and null");

    data = [UAWebViewCallData callDataForURL:[NSURL URLWithString:@"uairship://whatever/?foo=bar"] webView:nil];
    XCTAssertNotNil(data, @"data should be non-nil");
    XCTAssertEqual(data.arguments.count, (NSUInteger)0, @"data should have no arguments");

    expectedValues = @[@"bar"];
    XCTAssertEqualObjects([data.options objectForKey:@"foo"], expectedValues, @"key 'foo' should have values 'bar'");
}

@end
