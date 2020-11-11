/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UARuntimeConfig.h"
#import "UAirship+Internal.h"
#import "UAChannel.h"
#import "UAUser+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAInboxAPIClient+Internal.h"
#import "UAUserData+Internal.h"

@interface UAInboxAPIClientTest : UAAirshipBaseTest

@property (nonatomic, strong) UAInboxAPIClient *inboxAPIClient;
@property (nonatomic, strong) id mockUser;
@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) id mockChannel;
@property (nonatomic, strong) id mockSession;
@end

@implementation UAInboxAPIClientTest

- (void)setUp {
    [super setUp];
    self.mockChannel = [self mockForClass:[UAChannel class]];
    [[[self.mockChannel stub] andReturn:@"mockChannelID"] identifier];

    self.mockSession = [self mockForClass:[UARequestSession class]];

    self.mockAirship = [self mockForClass:[UAirship class]];
    [UAirship setSharedAirship:self.mockAirship];
    [[[self.mockAirship stub] andReturn:self.mockChannel] channel];

    self.mockUser = [self mockForClass:[UAUser class]];

    UAUserData *userData = [UAUserData dataWithUsername:@"username" password:@"password"];

    [[[self.mockUser stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        void (^completionHandler)(UAUserData * _Nullable) = (__bridge void (^)(UAUserData * _Nullable)) arg;
        completionHandler(userData);
    }] getUserData:OCMOCK_ANY];

    self.inboxAPIClient = [UAInboxAPIClient clientWithConfig:self.config
                                                     session:self.mockSession
                                                        user:self.mockUser
                                                   dataStore:self.dataStore];
}

- (void)tearDown {
    [self.mockAirship stopMocking];
    [self.mockChannel stopMocking];
    [self.mockUser stopMocking];
    [self.mockSession stopMocking];

    [super tearDown];
}


/**
 * Tests retrieving the message list on success.
 */
- (void)testRetrieveMessageListOnSuccess {
    // Create a success response
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:@{}];
    NSData *responseData = [@"{\"ok\":true, \"messages\": [\"someMessage\"]}" dataUsingEncoding:NSUTF8StringEncoding];

    // Stub the session to return the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(responseData, response, nil);
    }] performHTTPRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
        UARequest *request = obj;

        if (![@"mockChannelID" isEqualToString:request.headers[kUAChannelIDHeader]]) {
            return NO;
        }
        return YES;
    }] completionHandler:OCMOCK_ANY];

    // Make call
    [self.inboxAPIClient retrieveMessageListOnSuccess:^(NSUInteger status, NSArray * _Nullable messages) {
        XCTAssertEqualObjects(messages[0], @"someMessage", @"Messages should match messages from the response");
    } onFailure:^() {
        XCTFail(@"Should not be called");
    }];

    [self.mockSession verify];
}

/**
 * Tests retrieving the message list on failure.
 */
- (void)testRetrieveMessageListOnFailure {
    // Create a failure response
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:500 HTTPVersion:nil headerFields:@{}];

    // Stub the session to return the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;

        completionHandler(nil, response, nil);
    }] performHTTPRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
        UARequest *request = obj;

        if (![@"mockChannelID" isEqualToString:request.headers[kUAChannelIDHeader]]) {
            return NO;
        }
        return YES;
    }] completionHandler:OCMOCK_ANY];

    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"callback called"];
    [self.inboxAPIClient retrieveMessageListOnSuccess:^(NSUInteger status, NSArray * _Nullable messages) {
        XCTFail(@"Should not be called");
    } onFailure:^() {
        [callbackCalled fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockSession verify];
}

/**
* Tests retrieving the message list on failure.
*/
- (void)testRetrieveMessageListInvalidResponse {

    // Create a success response
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:@{}];

    // Stub the session to return the response with no message body
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;

        completionHandler(nil, response, nil);

        typedef void (^UAHTTPRequestCompletionHandler)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error);

    }] performHTTPRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"callback called"];
    [self.inboxAPIClient retrieveMessageListOnSuccess:^(NSUInteger status, NSArray * _Nullable messages) {
        XCTFail(@"Should not be called");
    } onFailure:^() {
        [callbackCalled fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockSession verify];
}

/**
 * Tests batch mark as read on success.
 */
- (void)testBatchMarkAsReadOnSuccess {

    // Create a success response
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:@{}];
    NSData *responseData = [@"{\"ok\":true}" dataUsingEncoding:NSUTF8StringEncoding];

    // Stub the session to return the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(responseData, response, nil);
    }] performHTTPRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
        UARequest *request = obj;

        if (![@"mockChannelID" isEqualToString:request.headers[kUAChannelIDHeader]]) {
            return NO;
        }
        return YES;
    }] completionHandler:OCMOCK_ANY];

    NSDictionary *testReporting = @{@"message_id":@"126",
                                    @"group_id":@"345",
                                    @"variant_id":@"1"};

    // Make call
    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"callback called"];
    [self.inboxAPIClient performBatchMarkAsReadForMessageReporting:@[testReporting] onSuccess:^{
        [callbackCalled fulfill];
    } onFailure:^() {
        XCTFail(@"Should not be called");
    }];

    [self waitForTestExpectations];
    [self.mockSession verify];
}

/**
 * Tests batch mark as read on failure.
 */
- (void)testBatchMarkAsReadOnFailure {

    // Create a failure response
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:500 HTTPVersion:nil headerFields:@{}];

    // Stub the session to return the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;

        completionHandler(nil, response, nil);

        typedef void (^UAHTTPRequestCompletionHandler)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error);
    }] performHTTPRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
        UARequest *request = obj;

        if (![@"mockChannelID" isEqualToString:request.headers[kUAChannelIDHeader]]) {
            return NO;
        }
        return YES;
    }] completionHandler:OCMOCK_ANY];

    NSDictionary *testReporting = @{@"message_id":@"126",
                                    @"group_id":@"345",
                                    @"variant_id":@"1"};

    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"callback called"];
    [self.inboxAPIClient performBatchMarkAsReadForMessageReporting:@[testReporting] onSuccess:^{
        XCTFail(@"Should not be called");
    } onFailure:^() {
        [callbackCalled fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockSession verify];
}

/**
 * Tests batch delete on success.
 */
- (void)testBatchDeleteOnSuccess {
    // Create a success response
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:@{}];
    NSData *responseData = [@"{\"ok\":true}" dataUsingEncoding:NSUTF8StringEncoding];

    // Stub the session to return the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;

        completionHandler(responseData, response, nil);

        typedef void (^UAHTTPRequestCompletionHandler)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error);
    }] performHTTPRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    NSDictionary *testReporting = @{@"message_id":@"126",
                                    @"group_id":@"345",
                                    @"variant_id":@"1"};

    // Make call
    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"callback called"];
    [self.inboxAPIClient performBatchDeleteForMessageReporting:@[testReporting] onSuccess:^{
        [callbackCalled fulfill];
    } onFailure:^() {
        XCTFail(@"Should not be called");
    }];

    [self waitForTestExpectations];
    [self.mockSession verify];
}

/**
 * Tests batch delete on failure.
 */
- (void)testBatchDeleteOnFailure {
    // Create a failure response
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:500 HTTPVersion:nil headerFields:@{}];

    // Stub the session to return the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(nil, response, nil);
    }] performHTTPRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    NSDictionary *testReporting = @{@"message_id":@"126",
                                    @"group_id":@"345",
                                    @"variant_id":@"1"};

    // Make call
    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"callback called"];
    [self.inboxAPIClient performBatchDeleteForMessageReporting:@[testReporting] onSuccess:^{
        XCTFail(@"Should not be called");
    } onFailure:^() {
        [callbackCalled fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockSession verify];
}

/**
 * Tests retrieving the message list when disabled.
 */
- (void)testRetrieveMessageListWhenDisabled {
    // setup
    self.inboxAPIClient.enabled = NO;
    XCTestExpectation *expectationForRefreshSucceeded = [self expectationWithDescription:@"UAInboxClientMessageRetrievalSuccessBlock executed"];
    
    // test
    [self.inboxAPIClient retrieveMessageListOnSuccess:^(NSUInteger status, NSArray * _Nullable messages) {
        XCTAssertEqual(status,0);
        XCTAssertFalse(messages.count);
        
        [expectationForRefreshSucceeded fulfill];
    } onFailure:^() {
        XCTFail(@"Should not fail");
    }];
    
    // verify
    [self waitForTestExpectations];
    [self.mockSession verify];
}

/**
 * Tests batch delete when disabled.
 */
- (void)testBatchDeleteWhenDisabled {
    // setup
    self.inboxAPIClient.enabled = NO;
    XCTestExpectation *expectationForRefreshSucceeded = [self expectationWithDescription:@"UAInboxClientMessageRetrievalSuccessBlock executed"];
    
    // test
    NSDictionary *testReporting = @{@"message_id":@"126",
                                    @"group_id":@"345",
                                    @"variant_id":@"1"};
    [self.inboxAPIClient performBatchDeleteForMessageReporting:@[testReporting] onSuccess:^{
        [expectationForRefreshSucceeded fulfill];
    } onFailure:^() {
        XCTFail(@"Should not fail");
    }];
    
    // verify
    [self waitForTestExpectations];
    [self.mockSession verify];
}

/**
 * Tests batch mark as read when disabled.
 */
- (void)testBatchMarkAsReadWhenDisabled {
    // setup
    self.inboxAPIClient.enabled = NO;
    XCTestExpectation *expectationForRefreshSucceeded = [self expectationWithDescription:@"UAInboxClientMessageRetrievalSuccessBlock executed"];
    
    NSDictionary *testReporting = @{@"message_id":@"126",
                                    @"group_id":@"345",
                                    @"variant_id":@"1"};
    
    // Make call
    [self.inboxAPIClient performBatchMarkAsReadForMessageReporting:@[testReporting] onSuccess:^{
        [expectationForRefreshSucceeded fulfill];
    } onFailure:^() {
        XCTFail(@"Should not fail");
    }];
    
    // verify
    [self waitForTestExpectations];
    [self.mockSession verify];
}

@end
