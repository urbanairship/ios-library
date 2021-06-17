/* Copyright Airship and Contributors */


#import "UAAirshipBaseTest.h"
#import <UIKit/UIKit.h>

#import "UARuntimeConfig.h"
#import "UATagGroupsMutation+Internal.h"
#import "AirshipTests-Swift.h"

@import AirshipCore;


@interface UATagGroupsAPIClientTest : UAAirshipBaseTest
@property (nonatomic, strong) UATestRequestSession *testSession;
@property (nonatomic, strong) UATagGroupsAPIClient *client;
@end

@implementation UATagGroupsAPIClientTest

- (void)setUp {
    [super setUp];
    self.testSession = [[UATestRequestSession alloc] init];
    self.client = [[UATagGroupsAPIClient alloc] initWithConfig:self.config session:self.testSession typeKey:@"test_audience_key" path:@"/test"];
}

/**
 * Test channel request.
 */
- (void)testRequest {
    self.testSession.response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                            statusCode:200
                                                           HTTPVersion:nil
                                                          headerFields:nil];

    UATagGroupsMutation *mutation = [UATagGroupsMutation mutationToAddTags:@[@"tag1"]
                                                                     group:@"tag group"];

    XCTestExpectation *completionHandlerCalledExpectation = [self expectationWithDescription:@"Completion handler called"];
    [self.client updateTagGroups:@"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
                        mutation:mutation
               completionHandler:^(UAHTTPResponse *response, NSError *error){
        XCTAssertNil(error);
        XCTAssertEqual(200, response.status);
        [completionHandlerCalledExpectation fulfill];
    }];

    // verify
    [self waitForTestExpectations];

    UARequest *request = self.testSession.lastRequest;


    XCTAssertEqualObjects(@"https://device-api.urbanairship.com/test", request.url.absoluteString);
    XCTAssertEqualObjects(@"POST", request.method);
    XCTAssertEqualObjects(@"application/vnd.urbanairship+json; version=3;", request.headers[@"Accept"]);
    XCTAssertEqualObjects(@"application/json", request.headers[@"Content-Type"]);

    NSDictionary *expectedPayload = @{ @"audience": @{ @"test_audience_key": @"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE" },
                                       @"add": @{ @"tag group": @[@"tag1"] } };
    NSDictionary *body = [NSJSONSerialization JSONObjectWithData:request.body options:0 error:nil];
    XCTAssertEqualObjects(expectedPayload, body);
}

- (void)testUnsuccessfulStatus {
    self.testSession.response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                              statusCode:420
                                                             HTTPVersion:nil
                                                            headerFields:nil];

    UATagGroupsMutation *mutation = [UATagGroupsMutation mutationToAddTags:@[@"tag1"]
                                                                     group:@"tag group"];

    XCTestExpectation *completionHandlerCalledExpectation = [self expectationWithDescription:@"Completion handler called"];
    [self.client updateTagGroups:@"cool"
                        mutation:mutation
               completionHandler:^(UAHTTPResponse *response, NSError *error){
        XCTAssertNil(error);
        XCTAssertEqual(420, response.status);
        [completionHandlerCalledExpectation fulfill];
    }];

    // verify
    [self waitForTestExpectations];
}

- (void)testUpdateError {
    self.testSession.error = [[NSError alloc] initWithDomain:@"whatever" code:1 userInfo:nil];

    UATagGroupsMutation *mutation = [UATagGroupsMutation mutationToAddTags:@[@"tag1"]
                                                                     group:@"tag group"];

    XCTestExpectation *completionHandlerCalledExpectation = [self expectationWithDescription:@"Completion handler called"];
    [self.client updateTagGroups:@"cool"
                        mutation:mutation
               completionHandler:^(UAHTTPResponse *response, NSError *error){
        XCTAssertEqual(self.testSession.error, error);
        XCTAssertNil(response);
        [completionHandlerCalledExpectation fulfill];
    }];

    // verify
    [self waitForTestExpectations];
}

@end



