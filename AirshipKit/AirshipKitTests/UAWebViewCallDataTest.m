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
#import <OCMock/OCMock.h>
#import "UAWebViewCallData.h"

@interface UAWebViewCallDataTest : XCTestCase
@property (nonatomic, strong) id mockWebView;
@end

@implementation UAWebViewCallDataTest

- (void)setUp {
    [super setUp];
    self.mockWebView = [OCMockObject niceMockForClass:[UIWebView class]];
}

- (void)tearDown {
    [self.mockWebView stopMocking];
    [super tearDown];
}

- (void)testcallDataForURL {
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

@end
