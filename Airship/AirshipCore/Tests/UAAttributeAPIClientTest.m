/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import <Foundation/Foundation.h>
#import "UAirship.h"
#import "UARuntimeConfig.h"
#import "UAAnalytics+Internal.h"
#import "UAAttributePendingMutations.h"
#import "UAAttributeMutations+Internal.h"
#import "UAJSONSerialization.h"
#import "UAirship+Internal.h"
#import "UAChannel+Internal.h"
#import "AirshipTests-Swift.h"

@import AirshipCore;


@interface UAAttributeAPIClientTest : UAAirshipBaseTest
@property (nonatomic, strong) UATestRequestSession *testSession;
@property(nonatomic, strong) UAAttributeAPIClient *client;
@end

@implementation UAAttributeAPIClientTest

- (void)setUp {
    self.testSession = [[UATestRequestSession alloc] init];
    self.client = [[UAAttributeAPIClient alloc] initWithConfig:self.config session:self.testSession urlFactoryBlock:^(UARuntimeConfig *config, NSString *identifier) {
        return [NSURL URLWithString:[NSString stringWithFormat:@"https://test/%@", identifier]];
    }];
}

/**
 * Test request
 */
- (void)testResponse {
    // Create a response
    self.testSession.response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                              statusCode:200
                                                             HTTPVersion:nil
                                                            headerFields:nil];

    id mockMutation = [self mockForClass:[UAAttributePendingMutations class]];
    [[[mockMutation stub] andReturn:@{@"neat": @"payload"}] payload];

    XCTestExpectation *callback = [self expectationWithDescription:@"callback"];
    [self.client updateWithIdentifier:@"bobby"
                   mutations:mockMutation
                    completionHandler:^(UAHTTPResponse *response, NSError * _Nullable error) {
        XCTAssertNil(error);
        XCTAssertEqual(200, response.status);
        [callback fulfill];
    }];

    [self waitForTestExpectations];

    UARequest *request = self.testSession.lastRequest;

    id expectedBody = [UAJSONSerialization dataWithJSONObject:@{@"neat": @"payload"}
                                                      options:0
                                                        error:nil];

    XCTAssertEqualObjects(@"https://test/bobby", request.url.absoluteString);
    XCTAssertEqualObjects(@"POST", request.method);
    XCTAssertEqualObjects(@"application/vnd.urbanairship+json; version=3;", request.headers[@"Accept"]);
    XCTAssertEqualObjects(@"application/json", request.headers[@"Content-Type"]);
    XCTAssertEqualObjects(expectedBody, request.body);

}

- (void)testFailedUpdate {
    // Create a response
    self.testSession.response =  [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                              statusCode:420
                                                             HTTPVersion:nil
                                                            headerFields:nil];

    id mockMutation = [self mockForClass:[UAAttributePendingMutations class]];
    [[[mockMutation stub] andReturn:@{@"neat": @"payload"}] payload];


    XCTestExpectation *callback = [self expectationWithDescription:@"callback"];
    [self.client updateWithIdentifier:@"bobby"
                            mutations:mockMutation
                    completionHandler:^(UAHTTPResponse *response, NSError * _Nullable error) {
        XCTAssertNil(error);
        XCTAssertEqual(420, response.status);
        [callback fulfill];
    }];
    [self waitForTestExpectations];
}

- (void)testUpdateError {
    self.testSession.error = [[NSError alloc] initWithDomain:@"whatever" code:1 userInfo:nil];

    id mockMutation = [self mockForClass:[UAAttributePendingMutations class]];
    [[[mockMutation stub] andReturn:@{@"neat": @"payload"}] payload];

    XCTestExpectation *callback = [self expectationWithDescription:@"callback"];
    [self.client updateWithIdentifier:@"bobby"
                   mutations:mockMutation
                    completionHandler:^(UAHTTPResponse *response, NSError * _Nullable error) {
        XCTAssertEqual(self.testSession.error, error);
        XCTAssertNil(response);
        [callback fulfill];
    }];

    [self waitForTestExpectations];
}

@end
