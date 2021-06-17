/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UARuntimeConfig.h"
#import "AirshipTests-Swift.h"

@import AirshipCore;

@interface UAEventAPIClientTest : UAAirshipBaseTest
@property (nonatomic, strong) UATestRequestSession *testSession;
@property (nonatomic, strong) UAEventAPIClient *client;
@end

@implementation UAEventAPIClientTest

- (void)setUp {
    [super setUp];
    self.testSession = [[UATestRequestSession alloc] init];
    self.client = [[UAEventAPIClient alloc] initWithConfig:self.config session:self.testSession];
}

/**
 * Test the event request
 */
- (void)testEventRequest {
    NSDictionary *headers = @{@"cool": @"story"};

    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"Callback called"];
    [self.client uploadEvents:@[@{@"some": @"event"}] headers:headers
            completionHandler:^(UAEventAPIResponse *response, NSError *error) {
        [callbackCalled fulfill];
    }];

    [self waitForTestExpectations];

    UARequest *request = self.testSession.lastRequest;

    XCTAssertEqualObjects(@"https://combine.urbanairship.com/warp9/", request.url.absoluteString);
    XCTAssertEqualObjects(@"POST", request.method);
    XCTAssertTrue(request.body.length > 0);
    XCTAssertEqualObjects(@"story", request.headers[@"cool"]);
}

/**
 * Test that a successful event upload passes the response headers with no errors
 */
- (void)testUploadEvents {
    NSDictionary *headers = @{@"X-UA-Max-Total" : @"123", @"X-UA-Max-Batch" : @"234", @"X-UA-Min-Batch-Interval": @"345"};

    self.testSession.response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:headers];

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

    self.testSession.response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:400 HTTPVersion:nil headerFields:headers];

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
    self.testSession.error = [NSError errorWithDomain:NSCocoaErrorDomain code:0 userInfo:@{}];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Callback called"];

    [self.client uploadEvents:@[@{@"some": @"event"}]
                      headers:@{@"foo" : @"bar"}
            completionHandler:^(UAEventAPIResponse *response, NSError *error) {
        XCTAssertNil(response);
        XCTAssertEqualObjects(self.testSession.error, error);
        [expectation fulfill];
    }];

    [self waitForTestExpectations];
}

@end

