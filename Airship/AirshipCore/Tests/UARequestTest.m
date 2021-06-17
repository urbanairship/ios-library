/* Copyright Airship and Contributors */

#import "UABaseTest.h"

@import AirshipCore;

@interface UARequestTest : UABaseTest
@end

@implementation UARequestTest


- (void)testBuild {
    UARequest *request = [UARequest requestWithBuilderBlock:^(UARequestBuilder *builder) {
        builder.method = @"POST";
        builder.body = [@"body" dataUsingEncoding:NSUTF8StringEncoding];
        builder.url = [NSURL URLWithString:@"www.urbanairship.com"];
        builder.username = @"name";
        builder.password = @"password";
        [builder setValue:@"header_value" header:@"header_key"];
        [builder addHeaders:@{@"cool": @"story"}];
    }];

    XCTAssertEqualObjects(request.method, @"POST");
    XCTAssertEqualObjects(request.url.absoluteString, @"www.urbanairship.com");
    XCTAssertEqualObjects(request.body, [@"body" dataUsingEncoding:NSUTF8StringEncoding]);
    XCTAssertEqualObjects(request.headers[@"header_key"], @"header_value");
    XCTAssertEqualObjects(request.headers[@"cool"], @"story");
    XCTAssertEqualObjects(request.headers[@"Authorization"], @"Basic bmFtZTpwYXNzd29yZA==");
}

- (void)testGZIP {
    UARequest *request = [UARequest requestWithBuilderBlock:^(UARequestBuilder *builder) {
        builder.body = [@"body" dataUsingEncoding:NSUTF8StringEncoding];
        builder.compressBody = YES;
    }];

    XCTAssertEqualObjects(@"H4sIAAAAAAAAE0vKT6kEALILqNsEAAAA", [request.body base64EncodedStringWithOptions:0]);
    XCTAssertEqualObjects(request.headers[@"Content-Encoding"], @"gzip");
}

@end
