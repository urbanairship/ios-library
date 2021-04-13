/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UAEventAPIClient+Internal.h"
#import "UARuntimeConfig.h"
#import "UAirship+Internal.h"
#import "UAPush+Internal.h"
#import "UAKeychainUtils.h"

@interface UAEventAPIClientTest : UAAirshipBaseTest
@property (nonatomic, strong) id mockPush;
@property (nonatomic, strong) id mockChannel;
@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) id mockTimeZoneClass;
@property (nonatomic, strong) id mockLocaleClass;
@property (nonatomic, strong) id mockSession;
@property (nonatomic, strong) id mockAnalytics;
@property (nonatomic, strong) id mockDelegate;

@property (nonatomic, strong) UAEventAPIClient *client;
@end

@implementation UAEventAPIClientTest

- (void)setUp {
    [super setUp];
    self.mockSession = [self mockForClass:[UARequestSession class]];
    self.client = [UAEventAPIClient clientWithConfig:self.config session:self.mockSession];
}

/**
 * Test the event request
 */
- (void)testEventRequest {
    NSDictionary *headers = @{@"cool": @"story"};

    BOOL (^checkRequestBlock)(id obj) = ^(id obj) {
        UARequest *request = obj;

        // check the url
        if (![[request.URL absoluteString] isEqualToString:@"https://combine.urbanairship.com/warp9/"]) {
            return NO;
        }

        // check that its a POST
        if (![request.method isEqualToString:@"POST"]) {
            return NO;
        }

        // check the body is set
        if (!request.body.length) {
            return NO;
        }

        // check header was included
        if (![request.headers[@"cool"] isEqual:@"story"]) {
            return NO;
        }

        return YES;
    };

    [[[self.mockSession expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(nil, nil, nil);
    }] performHTTPRequest:[OCMArg checkWithBlock:checkRequestBlock] completionHandler:OCMOCK_ANY];

    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"Callback called"];
    [self.client uploadEvents:@[@{@"some": @"event"}] headers:headers
            completionHandler:^(UAEventAPIResponse *response, NSError *error) {
        [callbackCalled fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockSession verify];
}


/**
 * Test that a successful event upload passes the response headers with no errors
 */
- (void)testUploadEvents {
    NSDictionary *headers = @{@"X-UA-Max-Total" : @"123", @"X-UA-Max-Batch" : @"234", @"X-UA-Min-Batch-Interval": @"345"};

    NSHTTPURLResponse *expectedResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:headers];

    [(UARequestSession *)[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(nil, expectedResponse, nil);
    }] performHTTPRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Callback called"];
    [self.client uploadEvents:@[@{@"some": @"event"}]
                      headers:@{@"foo" : @"bar"}
            completionHandler:^(UAEventAPIResponse *response, NSError *error) {
        XCTAssertNil(error);
        XCTAssertEqual(response.status, 200);
        XCTAssertEqualObjects(response.maxTotalDBSize, @(123));
        XCTAssertEqualObjects(response.maxBatchSize, @(234));
        XCTAssertEqualObjects(response.minBatchInterval, @(345));
        [expectation fulfill];
    }];

    [self waitForTestExpectations];
}

/**
 * Test that a non-200 event upload passes the response headers with an unsuccessful status error
 */
- (void)testUploadEventsUnsuccessfulStatus {
    NSDictionary *headers = @{@"X-UA-Max-Total" : @"123", @"X-UA-Max-Batch" : @"234", @"X-UA-Min-Batch-Interval": @"345"};

    NSHTTPURLResponse *expectedResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:400 HTTPVersion:nil headerFields:headers];

    [(UARequestSession *)[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(nil, expectedResponse, nil);
    }] performHTTPRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Callback called"];

    [self.client uploadEvents:@[@{@"some": @"event"}]
                      headers:@{@"foo" : @"bar"}
            completionHandler:^(UAEventAPIResponse *response, NSError *error) {
        XCTAssertNil(error);
        XCTAssertEqual(response.status, 400);
        XCTAssertEqualObjects(response.maxTotalDBSize, @(123));
        XCTAssertEqualObjects(response.maxBatchSize, @(234));
        XCTAssertEqualObjects(response.minBatchInterval, @(345));
        [expectation fulfill];
    }];

    [self waitForTestExpectations];
}

/**
 * Test that a failed event upload passes nil response headers, and the error, when a non-HTTP error is encountered
 */
- (void)testUploadEventsError {
    NSError *expectedError = [NSError errorWithDomain:NSCocoaErrorDomain code:0 userInfo:@{}];

    [(UARequestSession *)[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(nil, nil, expectedError);
    }] performHTTPRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Callback called"];

    [self.client uploadEvents:@[@{@"some": @"event"}]
                      headers:@{@"foo" : @"bar"}
            completionHandler:^(UAEventAPIResponse *response, NSError *error) {
        XCTAssertNil(response);
        XCTAssertEqualObjects(error, expectedError);
        [expectation fulfill];
    }];

    [self waitForTestExpectations];
}

@end

