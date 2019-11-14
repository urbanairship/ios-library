/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UARequest+Internal.h"

@interface UARequestTest : UABaseTest
@end

@implementation UARequestTest


- (void)testBuild {
    UARequest *request = [UARequest requestWithBuilderBlock:^(UARequestBuilder *builder) {
        builder.method = @"POST";
        builder.body = [@"body" dataUsingEncoding:NSUTF8StringEncoding];
        builder.URL = [NSURL URLWithString:@"www.urbanairship.com"];
        builder.username = @"name";
        builder.password = @"password";
        [builder setValue:@"header_value" forHeader:@"header_key"];
        [builder addHeaders:@{@"cool": @"story"}];
    }];

    XCTAssertEqualObjects(request.method, @"POST");
    XCTAssertEqualObjects(request.URL.absoluteString, @"www.urbanairship.com");
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
    
    XCTAssertTrue([[request.body base64EncodedStringWithOptions:0] isEqualToString:@"H4sIAAAAAAAAA0vKT6kEALILqNsEAAAA"] || [[request.body base64EncodedStringWithOptions:0] isEqualToString:@"H4sIAAAAAAAAE0vKT6kEALILqNsEAAAA"]);
    XCTAssertEqualObjects(request.headers[@"Content-Encoding"], @"gzip");

}

@end
