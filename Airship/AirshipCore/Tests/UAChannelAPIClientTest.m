/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import <Foundation/Foundation.h>
#import "UAirship.h"
#import "AirshipTests-Swift.h"

@import AirshipCore;

@interface UAChannelAPIClientTest : UAAirshipBaseTest
@property (nonatomic, strong) UATestRequestSession *testSession;
@property (nonatomic, strong) UAChannelAPIClient *client;
@end

@implementation UAChannelAPIClientTest

- (void)setUp {
    [super setUp];
    self.testSession = [[UATestRequestSession alloc] init];
    self.client = [[UAChannelAPIClient alloc] initWithConfig:self.config session:self.testSession];
}

- (void)testCreateChannel {
    self.testSession.response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:@{}];
    self.testSession.data = [@"{ \"ok\":true, \"channel_id\": \"someChannelID\"}" dataUsingEncoding:NSUTF8StringEncoding];
    UAChannelRegistrationPayload *payload = [[UAChannelRegistrationPayload alloc] init];


    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"callback called"];
    [self.client createChannelWithPayload:payload
                        completionHandler:^(UAChannelCreateResponse *response, NSError *error){
        XCTAssertNil(error);
        XCTAssertEqualObjects(@"someChannelID", response.channelID);
        XCTAssertEqual(200, response.status);
        [callbackCalled fulfill];
    }];

    [self waitForTestExpectations];


    UARequest *request = self.testSession.lastRequest;

    XCTAssertEqualObjects(@"https://device-api.urbanairship.com/api/channels/", request.url.absoluteString);
    XCTAssertEqualObjects(@"POST", request.method);
    XCTAssertEqualObjects(@"application/vnd.urbanairship+json; version=3;", request.headers[@"Accept"]);
    XCTAssertEqualObjects(@"application/json", request.headers[@"Content-Type"]);
    XCTAssertEqualObjects([payload encodeWithError:nil], request.body);
}

- (void)testCreateChannelParseError {
    self.testSession.response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:@{}];
    self.testSession.data = [@"{ \"ok\":true }" dataUsingEncoding:NSUTF8StringEncoding];

    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"callback called"];
    [self.client createChannelWithPayload:[[UAChannelRegistrationPayload alloc] init]
                        completionHandler:^(UAChannelCreateResponse *response, NSError *error){
        XCTAssertNotNil(error);
        XCTAssertNil(response);
        [callbackCalled fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testCreateChannelFailure {
    self.testSession.response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:400 HTTPVersion:nil headerFields:@{}];

    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"callback called"];
    [self.client createChannelWithPayload:[[UAChannelRegistrationPayload alloc] init]
                        completionHandler:^(UAChannelCreateResponse *response, NSError *error){
        XCTAssertNil(error);
        XCTAssertNil(response.channelID);
        XCTAssertEqual(400, response.status);
        [callbackCalled fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testCreateChannelError {
    self.testSession.error = [[NSError alloc] initWithDomain:@"neat" code:1 userInfo:nil];

    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"callback called"];
    [self.client createChannelWithPayload:[[UAChannelRegistrationPayload alloc] init]
                        completionHandler:^(UAChannelCreateResponse *response, NSError *error){
        XCTAssertEqual(self.testSession.error, error);
        XCTAssertNil(response);
        [callbackCalled fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testUpdateChannel {
    UAChannelRegistrationPayload *payload = [[UAChannelRegistrationPayload alloc] init];
    self.testSession.response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:@{}];

    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"callback called"];
    [self.client updateChannelWithID:@"someChannelID"
                         withPayload:[[UAChannelRegistrationPayload alloc] init]
                   completionHandler:^(UAHTTPResponse *response, NSError * _Nullable error) {
        XCTAssertEqual(200, response.status);
        XCTAssertNil(error);
        [callbackCalled fulfill];
    }];

    [self waitForTestExpectations];

    UARequest *request = self.testSession.lastRequest;

    XCTAssertEqualObjects(@"https://device-api.urbanairship.com/api/channels/someChannelID", request.url.absoluteString);
    XCTAssertEqualObjects(@"PUT", request.method);
    XCTAssertEqualObjects(@"application/vnd.urbanairship+json; version=3;", request.headers[@"Accept"]);
    XCTAssertEqualObjects(@"application/json", request.headers[@"Content-Type"]);
    XCTAssertEqualObjects([payload encodeWithError:nil], request.body);
}

- (void)testUpdateChannelFailure {
    self.testSession.response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:400 HTTPVersion:nil headerFields:@{}];

    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"callback called"];
    [self.client updateChannelWithID:@"some-payload"
                         withPayload:[[UAChannelRegistrationPayload alloc] init]
                   completionHandler:^(UAHTTPResponse *response, NSError *error){
        XCTAssertNil(error);
        XCTAssertEqual(400, response.status);
        [callbackCalled fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testUpdateChannelError {
    self.testSession.error = [[NSError alloc] initWithDomain:@"neat" code:1 userInfo:nil];

    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"callback called"];
    [self.client updateChannelWithID:@"some-payload"
                         withPayload:[[UAChannelRegistrationPayload alloc] init]
                   completionHandler:^(UAHTTPResponse *response, NSError *error){
        XCTAssertEqual(self.testSession.error, error);
        XCTAssertNil(response);
        [callbackCalled fulfill];
    }];

    [self waitForTestExpectations];
}

@end

