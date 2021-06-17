/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UARuntimeConfig.h"
#import "UAirship+Internal.h"
#import "AirshipTests-Swift.h"

@import AirshipCore;

@interface UANamedUserAPIClientTest : UAAirshipBaseTest

@property (nonatomic, strong) UATestRequestSession *testSession;
@property (nonatomic, strong) UANamedUserAPIClient *client;

@end

@implementation UANamedUserAPIClientTest

- (void)setUp {
    [super setUp];

    self.testSession = [[UATestRequestSession alloc] init];

    self.client = [[UANamedUserAPIClient alloc] initWithConfig:self.config session:self.testSession];
}

-(void)testAssociate {
    self.testSession.response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                              statusCode:200
                                                             HTTPVersion:nil
                                                            headerFields:nil];

    XCTestExpectation *finishedCallbacks = [self expectationWithDescription:@"Finished callbacks"];
    [self.client associate:@"fakeNamedUserID"
                 channelID:@"fakeChannel"
         completionHandler:^(UAHTTPResponse *response, NSError *error) {
        XCTAssertNil(error);
        XCTAssertEqual(200, response.status);
        [finishedCallbacks fulfill];
    }];

    [self waitForTestExpectations];

    UARequest *request = self.testSession.lastRequest;
    XCTAssertEqualObjects(@"https://device-api.urbanairship.com/api/named_users/associate", request.url.absoluteString);
    XCTAssertEqualObjects(@"POST", request.method);
    XCTAssertEqualObjects(@"application/vnd.urbanairship+json; version=3;", request.headers[@"Accept"]);
    XCTAssertEqualObjects(@"application/json", request.headers[@"Content-Type"]);
}

-(void)testAssociateError {
    self.testSession.error = [NSError errorWithDomain:@"domain" code:100 userInfo:nil];
    XCTestExpectation *finishedCallbacks = [self expectationWithDescription:@"Finished callbacks"];
    [self.client associate:@"fakeNamedUserID"
                 channelID:@"fakeChannel"
         completionHandler:^(UAHTTPResponse *response, NSError *error) {
        XCTAssertEqual(self.testSession.error, error);
        XCTAssertNil(response);
        [finishedCallbacks fulfill];
    }];

    [self waitForTestExpectations];
}

-(void)testDisassociate {
    self.testSession.response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                              statusCode:200
                                                             HTTPVersion:nil
                                                            headerFields:nil];

    XCTestExpectation *finishedCallbacks = [self expectationWithDescription:@"Finished callbacks"];
    [self.client disassociate:@"fakeNamedUserID"
            completionHandler:^(UAHTTPResponse *response, NSError *error) {
        XCTAssertEqual(200, response.status);
        XCTAssertNil(error);
        [finishedCallbacks fulfill];
    }];

    [self waitForTestExpectations];

    UARequest *request = self.testSession.lastRequest;
    XCTAssertEqualObjects(@"https://device-api.urbanairship.com/api/named_users/disassociate", request.url.absoluteString);
    XCTAssertEqualObjects(@"POST", request.method);
    XCTAssertEqualObjects(@"application/vnd.urbanairship+json; version=3;", request.headers[@"Accept"]);
    XCTAssertEqualObjects(@"application/json", request.headers[@"Content-Type"]);
}

-(void)testDisassociateError {
    self.testSession.error = [NSError errorWithDomain:@"domain" code:100 userInfo:nil];

    XCTestExpectation *finishedCallbacks = [self expectationWithDescription:@"Finished callbacks"];
    [self.client disassociate:@"fakeNamedUserID"
            completionHandler:^(UAHTTPResponse *response, NSError *error) {
        XCTAssertEqual(self.testSession.error, error);
        XCTAssertNil(response);
        [finishedCallbacks fulfill];
    }];

    [self waitForTestExpectations];
}

@end


