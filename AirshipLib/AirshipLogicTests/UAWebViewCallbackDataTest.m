
#import <XCTest/XCTest.h>
#import "UAWebViewCallbackData.h"

@interface UAWebViewCallbackDataTest : XCTestCase

@property(nonatomic, strong) NSURL *callbackURL;

@end

@implementation UAWebViewCallbackDataTest

- (void)setUp {
    [super setUp];
    self.callbackURL = [NSURL URLWithString:@"ua://whatever/argument-one/argument-two?foo=bar"];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testCallbackDataForURL {
    UAWebViewCallbackData *data = [UAWebViewCallbackData callbackDataForURL:self.callbackURL];
    XCTAssertNotNil(data, @"data should be non-nil");
    XCTAssertEqual(data.arguments.count, (NSUInteger)2, @"data should have two arguments");
    XCTAssertEqualObjects([data.arguments firstObject], @"argument-one", @"first arg should be 'argument-one'");
    XCTAssertEqualObjects([data.arguments objectAtIndex:1], @"argument-two", @"second arg should be 'argument-two'");
    XCTAssertEqualObjects([data.options objectForKey:@"foo"], @"bar", @"key 'foo' should index 'bar'");
}

@end
