/* Copyright Airship and Contributors */

#import <CommonCrypto/CommonHMAC.h>

#import "UAAirshipBaseTest.h"
#import "UAAuthTokenAPIClient+Internal.h"

@interface UAAuthTokenAPIClientTest : UAAirshipBaseTest
@property (nonatomic, strong) UAAuthTokenAPIClient *client;
@property (nonatomic, strong) id mockSession;
@end

@implementation UAAuthTokenAPIClientTest

- (void)setUp {
    self.mockSession = [self mockForClass:[UARequestSession class]];
    self.client = [UAAuthTokenAPIClient clientWithConfig:self.config session:self.mockSession];
}

- (void)testTokenWithChannelID {
    NSDictionary *responseBody = @{@"token": @"abc123", @"expires_in" : @(12345)};
    NSData *responseData = [NSJSONSerialization dataWithJSONObject:responseBody options:0 error:nil];

    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:nil];

    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(responseData, response, nil);
    }] performHTTPRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
        UARequest *request = obj;

        NSData *secret = [self.config.appSecret dataUsingEncoding:NSUTF8StringEncoding];
        NSData *message = [[NSString stringWithFormat:@"%@:%@", self.config.appKey, @"channel ID"] dataUsingEncoding:NSUTF8StringEncoding];
        NSMutableData* hash = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
        CCHmac(kCCHmacAlgSHA256, secret.bytes, secret.length, message.bytes, message.length, hash.mutableBytes);
        NSString *bearerToken =  [hash base64EncodedStringWithOptions:0];

        XCTAssertEqualObjects(request.method, @"GET");
        XCTAssertEqualObjects(request.URL.absoluteString, [self.config.deviceAPIURL stringByAppendingString:@"/api/auth/device"]);
        XCTAssertEqualObjects(request.headers[@"X-UA-Channel-ID"], @"channel ID");
        XCTAssertEqualObjects(request.headers[@"X-UA-App-Key"], self.config.appKey);
        XCTAssertEqualObjects(request.headers[@"Accept"], @"application/vnd.urbanairship+json; version=3;");
        XCTAssertEqualObjects(request.headers[@"Authorization"], [@"Bearer " stringByAppendingString:bearerToken]);

        return YES;
    }] completionHandler:OCMOCK_ANY];

    XCTestExpectation *tokenRetrieved = [self expectationWithDescription:@"token retrieved"];

    [self.client tokenWithChannelID:@"channel ID" completionHandler:^(UAAuthToken * _Nullable token, NSError * _Nullable error) {
        if (token && !error) {
            [tokenRetrieved fulfill];
        }
    }];

    [self waitForTestExpectations];
}

- (void)testTokenWithChannelIDMalformedPayload {
    NSDictionary *responseBody = @{@"not a token": @"abc123", @"expires_in_3_2_1" : @(12345)};
    NSData *responseData = [NSJSONSerialization dataWithJSONObject:responseBody options:0 error:nil];

    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:nil];

    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(responseData, response, nil);
    }] performHTTPRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *tokenRetrieved = [self expectationWithDescription:@"token retrieved"];

    [self.client tokenWithChannelID:@"channel ID" completionHandler:^(UAAuthToken * _Nullable token, NSError * _Nullable error) {
        if (!token && error) {
            XCTAssertEqualObjects(error.domain, UAAuthTokenAPIClientErrorDomain);
            XCTAssertEqual(error.code, UAAuthTokenAPIClientErrorInvalidResponse);
            [tokenRetrieved fulfill];
        }
    }];

    [self waitForTestExpectations];
}

- (void)testTokenWithChannelIDClientError {
    NSDictionary *responseBody = @{@"too": @"bad"};
    NSData *responseData = [NSJSONSerialization dataWithJSONObject:responseBody options:0 error:nil];

    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:400 HTTPVersion:nil headerFields:nil];

    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(responseData, response, nil);
    }] performHTTPRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *tokenRetrieved = [self expectationWithDescription:@"token retrieved"];

    [self.client tokenWithChannelID:@"channel ID" completionHandler:^(UAAuthToken * _Nullable token, NSError * _Nullable error) {
        if (!token && error) {
            XCTAssertEqualObjects(error.domain, UAAuthTokenAPIClientErrorDomain);
            XCTAssertEqual(error.code, UAAuthTokenAPIClientErrorUnsuccessfulStatus);
            [tokenRetrieved fulfill];
        }
    }];

    [self waitForTestExpectations];
}

@end
