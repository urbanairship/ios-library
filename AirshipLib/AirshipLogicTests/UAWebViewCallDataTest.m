
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
                               [NSURL URLWithString:@"ua://whatever/argument-one/argument-two?foo=bar"]];
    XCTAssertNotNil(data, @"data should be non-nil");
    XCTAssertEqual(data.arguments.count, (NSUInteger)2, @"data should have two arguments");
    XCTAssertEqualObjects([data.arguments firstObject], @"argument-one", @"first arg should be 'argument-one'");
    XCTAssertEqualObjects([data.arguments objectAtIndex:1], @"argument-two", @"second arg should be 'argument-two'");
    XCTAssertEqualObjects([data.options objectForKey:@"foo"], @"bar", @"key 'foo' should index 'bar'");

    data = [UAWebViewCallData callDataForURL:[NSURL URLWithString:@"ua://whatever/?foo=bar"]];
    XCTAssertNotNil(data, @"data should be non-nil");
    XCTAssertEqual(data.arguments.count, (NSUInteger)0, @"data should have no arguments");
    XCTAssertEqualObjects([data.options objectForKey:@"foo"], @"bar", @"key 'foo' should index 'bar'");
}

@end
