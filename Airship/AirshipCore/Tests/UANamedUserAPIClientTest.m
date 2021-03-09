/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UARuntimeConfig.h"
#import "UANamedUserAPIClient+Internal.h"
#import "UAirship+Internal.h"

@interface UANamedUserAPIClientTest : UAAirshipBaseTest

@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) id mockSession;
@property (nonatomic, strong) UANamedUserAPIClient *client;

@end

@implementation UANamedUserAPIClientTest

- (void)setUp {
    [super setUp];

    self.mockSession = [self mockForClass:[UARequestSession class]];

    self.mockAirship = [self mockForClass:[UAirship class]];
    [UAirship setSharedAirship:self.mockAirship];
    [[[self.mockAirship stub] andReturn:self.config] config];

    self.client = [UANamedUserAPIClient clientWithConfig:self.config session:self.mockSession];
}

-(void)testAssociate {
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                              statusCode:200
                                                             HTTPVersion:nil
                                                            headerFields:nil];

    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(nil, response, nil);
    }] performHTTPRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *finishedCallbacks = [self expectationWithDescription:@"Finished callbacks"];
    [self.client associate:@"fakeNamedUserID"
                 channelID:@"fakeChannel"
         completionHandler:^(UAHTTPResponse *response, NSError *error) {
        XCTAssertNil(error);
        XCTAssertEqual(200, response.status);
        [finishedCallbacks fulfill];
    }];

    [self waitForTestExpectations];
}

-(void)testAssociateError {
    NSError *responseError = [NSError errorWithDomain:@"domain" code:100 userInfo:nil];

    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(nil, nil, responseError);
    }] performHTTPRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *finishedCallbacks = [self expectationWithDescription:@"Finished callbacks"];
    [self.client associate:@"fakeNamedUserID"
                 channelID:@"fakeChannel"
         completionHandler:^(UAHTTPResponse *response, NSError *error) {
        XCTAssertEqual(responseError, error);
        XCTAssertNil(response);
        [finishedCallbacks fulfill];
    }];

    [self waitForTestExpectations];
}

-(void)testDisassociate {
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                              statusCode:200
                                                             HTTPVersion:nil
                                                            headerFields:nil];

    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(nil, response, nil);
    }] performHTTPRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *finishedCallbacks = [self expectationWithDescription:@"Finished callbacks"];
    [self.client disassociate:@"fakeNamedUserID"
            completionHandler:^(UAHTTPResponse *response, NSError *error) {
        XCTAssertEqual(200, response.status);
        XCTAssertNil(error);
        [finishedCallbacks fulfill];
    }];

    [self waitForTestExpectations];
}

-(void)testDisassociateError {
    NSError *responseError = [NSError errorWithDomain:@"domain" code:100 userInfo:nil];

    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(nil, nil, responseError);
    }] performHTTPRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *finishedCallbacks = [self expectationWithDescription:@"Finished callbacks"];
    [self.client disassociate:@"fakeNamedUserID"
            completionHandler:^(UAHTTPResponse *response, NSError *error) {
        XCTAssertEqual(responseError, error);
        XCTAssertNil(response);
        [finishedCallbacks fulfill];
    }];

    [self waitForTestExpectations];
}

@end


