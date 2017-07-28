/* Copyright 2017 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UAConfig.h"
#import "UANamedUserAPIClient+Internal.h"
#import "UAirship.h"

@interface UANamedUserAPIClientTest : UABaseTest

@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) id mockSession;
@property (nonatomic, strong) UAConfig *config;
@property (nonatomic, strong) UANamedUserAPIClient *client;

@end

@implementation UANamedUserAPIClientTest

- (void)setUp {
    [super setUp];

    self.config = [UAConfig config];

    self.mockSession = [self mockForClass:[UARequestSession class]];

    self.mockAirship = [self mockForClass:[UAirship class]];
    [[[self.mockAirship stub] andReturn:self.mockAirship] shared];
    [[[self.mockAirship stub] andReturn:self.config] config];

    self.client = [UANamedUserAPIClient clientWithConfig:self.config session:self.mockSession];
}

- (void)tearDown {
    [self.mockSession stopMocking];
    [self.mockAirship stopMocking];

    [super tearDown];
}

/**
 * Test associate named user retries on 5xx status codes.
 */
- (void)testAssociateRetriesFailedRequests {
    // Check that the retry block returns YES for any 5xx request
    BOOL (^retryBlockCheck)(id obj) = ^(id obj) {
        UARequestRetryBlock retryBlock = obj;

        for (NSInteger i = 500; i < 600; i++) {
            NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                                      statusCode:i
                                                                     HTTPVersion:nil
                                                                    headerFields:nil];

            BOOL retryResult = retryBlock(nil, response);

            if (retryResult) {
                continue;
            }

            return NO;
        }

        // Check that it returns NO for 400 status codes
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                                  statusCode:400
                                                                 HTTPVersion:nil
                                                                headerFields:nil];
        if (retryBlock(nil, response)) {
            return NO;
        }

        return YES;
    };

    [[self.mockSession expect] dataTaskWithRequest:OCMOCK_ANY
                                        retryWhere:[OCMArg checkWithBlock:retryBlockCheck]
                                 completionHandler:OCMOCK_ANY];

    [self.client associate:@"fakeNamedUserID"
                 channelID:@"fakeChannel"
                 onSuccess:^{
                     XCTFail(@"Should not be called");
                 }
                 onFailure:^(NSUInteger status){
                     XCTFail(@"Should not be called");
                 }];

    [self.mockSession verify];
}

/**
 * Test associate named user succeeds request when status is 2xx.
 */
-(void)testAssociateSucceedsRequest {
    __block int successBlockCalls = 0;

    BOOL (^completionBlockCheck)(id obj) = ^(id obj) {
        UARequestCompletionHandler completion = obj;

        for (NSInteger i = 200; i < 300; i++) {
            NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                                      statusCode:i
                                                                     HTTPVersion:nil
                                                                    headerFields:nil];
            completion(OCMOCK_ANY, response, nil);
        }

        return YES;
    };

    [[self.mockSession expect] dataTaskWithRequest:OCMOCK_ANY
                                        retryWhere:OCMOCK_ANY
                                 completionHandler:[OCMArg checkWithBlock:completionBlockCheck]];

    [self.client associate:@"fakeNamedUserID"
                 channelID:@"fakeChannel"
                 onSuccess:^{
                     successBlockCalls++;
                 }
                 onFailure:^(NSUInteger status){
                     XCTFail(@"Should not be called");
                 }];

    // Success block should be called once for every HTTP status from 200 to 299
    XCTAssert(successBlockCalls == 100);

    [self.mockSession verify];
}

/**
 * Test associate named user calls the FailureBlock with the failed request
 * when the request fails.
 */
- (void)testAssociateOnFailure {
    __block int failureBlockCalls = 0;

    BOOL (^completionBlockCheck)(id obj) = ^(id obj) {
        UARequestCompletionHandler completion = obj;

        for (NSInteger i = 400; i < 500; i++) {
            NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                                      statusCode:i
                                                                     HTTPVersion:nil
                                                                    headerFields:nil];
            completion(OCMOCK_ANY, response, nil);
        }

        return YES;
    };

    [[self.mockSession expect] dataTaskWithRequest:OCMOCK_ANY
                                        retryWhere:OCMOCK_ANY
                                 completionHandler:[OCMArg checkWithBlock:completionBlockCheck]];

    [self.client associate:@"fakeNamedUserID"
                 channelID:@"fakeChannel"
                 onSuccess:^{
                     XCTFail(@"Should not be called");
                 }
                 onFailure:^(NSUInteger status){
                     failureBlockCalls++;
                 }];

    // Failure block should be called once for every HTTP status from 400 to 499
    XCTAssert(failureBlockCalls == 100);
    
    [self.mockSession verify];
}

/**
 * Test disassociate named user retries on 5xx status codes.
 */
- (void)testDisassociateRetriesFailedRequests {

    // Check that the retry block returns YES for any 5xx request
    BOOL (^retryBlockCheck)(id obj) = ^(id obj) {
        UARequestRetryBlock retryBlock = obj;

        for (NSInteger i = 500; i < 600; i++) {
            NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                                      statusCode:i
                                                                     HTTPVersion:nil
                                                                    headerFields:nil];
            BOOL retryResult = retryBlock(nil, response);

            if (retryResult) {
                continue;
            }

            return NO;
        }

        // Check that it returns NO for 400 status codes
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                                  statusCode:400
                                                                 HTTPVersion:nil
                                                                headerFields:nil];
        if (retryBlock(nil, response)) {
            return NO;
        }

        return YES;
    };

    [[self.mockSession expect] dataTaskWithRequest:OCMOCK_ANY
                                        retryWhere:[OCMArg checkWithBlock:retryBlockCheck]
                                 completionHandler:OCMOCK_ANY];

    [self.client disassociate:@"fakeNamedUserID" onSuccess:^{
        XCTFail(@"Should not be called");
    } onFailure:^(NSUInteger status) {
        XCTFail(@"Should not be called");

    }];

    [self.mockSession verify];
}

/**
 * Test disassociate named user succeeds request when status is 2xx.
 */
-(void)testDisassociateSucceedsRequest {
    BOOL (^completionBlockCheck)(id obj) = ^(id obj) {
        UARequestCompletionHandler completion = obj;

        for (NSInteger i = 200; i < 300; i++) {
            NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                                      statusCode:i
                                                                     HTTPVersion:nil
                                                                    headerFields:nil];
            completion(OCMOCK_ANY, response, nil);
        }

        return YES;
    };

    [[self.mockSession expect] dataTaskWithRequest:OCMOCK_ANY
                                        retryWhere:OCMOCK_ANY
                                 completionHandler:[OCMArg checkWithBlock:completionBlockCheck]];

    __block int successBlockCalls = 0;

    [self.client disassociate:@"fakeNamedUserID"
                 onSuccess:^{
                     successBlockCalls++;
                 }
                 onFailure:^(NSUInteger status){
                     XCTFail(@"Should not be called");
                 }];

    // Success block should be called once for every HTTP status from 200 to 299
    XCTAssert(successBlockCalls == 100);
    
    [self.mockSession verify];
}

/**
 * Test disassociate named user calls the FailureBlock with the failed request
 * when the request fails.
 */
- (void)testDisassociateOnFailure {
    __block int failureBlockCalls = 0;

    BOOL (^completionBlockCheck)(id obj) = ^(id obj) {
        UARequestCompletionHandler completion = obj;

        for (NSInteger i = 400; i < 500; i++) {
            NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                                      statusCode:i
                                                                     HTTPVersion:nil
                                                                    headerFields:nil];

            completion(OCMOCK_ANY, response, nil);
        }

        return YES;
    };

    [[self.mockSession expect] dataTaskWithRequest:OCMOCK_ANY
                                        retryWhere:OCMOCK_ANY
                                 completionHandler:[OCMArg checkWithBlock:completionBlockCheck]];

    [self.client disassociate:@"fakeNamedUserID"
                 onSuccess:^{
                     XCTFail(@"Should not be called");
                 }
                 onFailure:^(NSUInteger status){
                     failureBlockCalls++;
                 }];

    // Failure block should be called once for every HTTP status from 400 to 499
    XCTAssert(failureBlockCalls == 100);
    
    [self.mockSession verify];
}

@end
