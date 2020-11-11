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

- (void)tearDown {
    [self.mockSession stopMocking];
    [self.mockAirship stopMocking];

    [super tearDown];
}

/**
 * Test associate named user succeeds request when status is 2xx.
 */
-(void)testAssociateSucceedsRequest {
    for (NSInteger i = 200; i < 300; i++) {
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                                  statusCode:i
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
             completionHandler:^(NSError * _Nullable error) {
            XCTAssertNil(error);
            [finishedCallbacks fulfill];
        }];

        [self waitForTestExpectations];
    }
}

/**
 * Test associate named user calls the FailureBlock with the failed request
 * when the request fails.
 */
- (void)testAssociateOnFailure {
    for (NSInteger i = 400; i < 500; i++) {
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                                  statusCode:i
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
             completionHandler:^(NSError * _Nullable error) {
            XCTAssertNotNil(error);
            [finishedCallbacks fulfill];
        }];

        [self waitForTestExpectations];
    }
}

/**
 * Test disassociate named user succeeds request when status is 2xx.
 */
-(void)testDisassociateSucceedsRequest {
    for (NSInteger i = 200; i < 300; i++) {
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                                  statusCode:i
                                                                 HTTPVersion:nil
                                                                headerFields:nil];

        [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
            void *arg;
            [invocation getArgument:&arg atIndex:3];
            UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
            completionHandler(nil, response, nil);
        }] performHTTPRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

        XCTestExpectation *finishedCallbacks = [self expectationWithDescription:@"Finished callbacks"];
        [self.client disassociate:@"fakeNamedUserID" completionHandler:^(NSError * _Nullable error) {
            XCTAssertNil(error);
            [finishedCallbacks fulfill];
        }];

        [self waitForTestExpectations];
    }
}

/**
 * Test disassociate named user calls the FailureBlock with the failed request
 * when the request fails.
 */
- (void)testDisassociateOnFailure {
    for (NSInteger i = 400; i < 500; i++) {
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                                  statusCode:i
                                                                 HTTPVersion:nil
                                                                headerFields:nil];

        [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
            void *arg;
            [invocation getArgument:&arg atIndex:3];
            UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
            completionHandler(nil, response, nil);
        }] performHTTPRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

        XCTestExpectation *finishedCallbacks = [self expectationWithDescription:@"Finished callbacks"];
        [self.client disassociate:@"fakeNamedUserID" completionHandler:^(NSError * _Nullable error) {
            XCTAssertNotNil(error);
            [finishedCallbacks fulfill];
        }];

        [self waitForTestExpectations];
    }
}

/**
 * Test associate named user when disabled.
 */
-(void)testAssociateWhenDisabled {
    // setup
    self.client.enabled = NO;

    // expectations
    BOOL (^completionBlockCheck)(id obj) = ^(id obj) {
        UAHTTPRequestCompletionHandler completion = obj;

        for (NSInteger i = 200; i < 300; i++) {
            NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                                      statusCode:i
                                                                     HTTPVersion:nil
                                                                    headerFields:nil];
            completion(OCMOCK_ANY, response, nil);
        }

        return YES;
    };

    [[self.mockSession stub] performHTTPRequest:OCMOCK_ANY
                              completionHandler:[OCMArg checkWithBlock:completionBlockCheck]];

    // test
    [self.client associate:@"fakeNamedUserID"
                 channelID:@"fakeChannel"
         completionHandler:^(NSError * _Nullable error) {
        XCTFail(@"Should not be called");
    }];

    // verify
    [self.mockSession verify];
}

/**
 * Test disassociate named user when disabled.
 */
-(void)testDisassociateWhenDisabled {
    // setup
    self.client.enabled = NO;

    // expectations
    BOOL (^completionBlockCheck)(id obj) = ^(id obj) {
        UAHTTPRequestCompletionHandler completion = obj;

        for (NSInteger i = 200; i < 300; i++) {
            NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                                      statusCode:i
                                                                     HTTPVersion:nil
                                                                    headerFields:nil];
            completion(OCMOCK_ANY, response, nil);
        }

        return YES;
    };

    [[self.mockSession stub] performHTTPRequest:OCMOCK_ANY
                              completionHandler:[OCMArg checkWithBlock:completionBlockCheck]];

    // test
    [self.client disassociate:@"fakeNamedUserID"
            completionHandler:^(NSError * _Nullable error) {
        XCTFail(@"Should not be called");
    }];

    // verify
    [self.mockSession verify];
}


@end


