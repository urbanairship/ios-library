/* Copyright Airship and Contributors */

#import "UABaseTest.h"

#import "UAEventAPIClient+Internal.h"
#import "UARuntimeConfig.h"
#import "UAirship+Internal.h"
#import "UAPush+Internal.h"
#import "UAKeychainUtils.h"

@interface UAEventAPIClientTest : UABaseTest
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

    [(UARequestSession *)[self.mockSession expect] dataTaskWithRequest:[OCMArg checkWithBlock:checkRequestBlock]
                                                     completionHandler:OCMOCK_ANY];

    [self.client uploadEvents:@[@{@"some": @"event"}] headers:headers
            completionHandler:^(NSHTTPURLResponse *response) {}];

    [self.mockSession verify];
}


/**
 * Test the event response is passed back.
 */
- (void)testEventResponse {

    NSHTTPURLResponse *expectedResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:nil];

    [(UARequestSession *)[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler)arg;
        completionHandler(nil, expectedResponse, nil);
    }] dataTaskWithRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Callback called"];
    [self.client uploadEvents:@[@{@"some": @"event"}] headers:@{} completionHandler:^(NSHTTPURLResponse *response) {
        XCTAssertEqualObjects(response, expectedResponse);
        [expectation fulfill];
    }];

    [self waitForTestExpectations];
}





@end
