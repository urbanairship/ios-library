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
#import "UARequest+Internal.h"

@interface UARequestTest : XCTestCase
@end

@implementation UARequestTest

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testBuild {
    UARequest *request = [UARequest requestWithBuilderBlock:^(UARequestBuilder *builder) {
        builder.method = @"POST";
        builder.body = [@"body" dataUsingEncoding:NSUTF8StringEncoding];
        builder.URL = [NSURL URLWithString:@"www.urbanairship.com"];
        builder.username = @"name";
        builder.password = @"password";
        [builder setValue:@"header_value" forHeader:@"header_key"];
    }];

    XCTAssertEqualObjects(request.method, @"POST");
    XCTAssertEqualObjects(request.URL.absoluteString, @"www.urbanairship.com");
    XCTAssertEqualObjects(request.body, [@"body" dataUsingEncoding:NSUTF8StringEncoding]);
    XCTAssertEqualObjects(request.headers[@"header_key"], @"header_value");
    XCTAssertEqualObjects(request.headers[@"Authorization"], @"Basic bmFtZTpwYXNzd29yZA==");
}

- (void)testGZIP {
    UARequest *request = [UARequest requestWithBuilderBlock:^(UARequestBuilder *builder) {
        builder.body = [@"body" dataUsingEncoding:NSUTF8StringEncoding];
        builder.compressBody = YES;
    }];

    XCTAssertEqualObjects([request.body base64EncodedStringWithOptions:0], @"H4sIAAAAAAAAA0vKT6kEALILqNsEAAAA");
    XCTAssertEqualObjects(request.headers[@"Content-Encoding"], @"gzip");

}

@end
