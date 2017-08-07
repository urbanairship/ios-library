/* Copyright 2017 Urban Airship and Contributors */

#import "UABaseTest.h"

#import "UAConfig+Internal.h"
#import "UAirship+Internal.h"
#import "UAPush+Internal.h"
#import "UAUser+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAInboxAPIClient+Internal.h"

@interface UAInboxAPIClientTest : UABaseTest

@property (nonatomic, strong) UAInboxAPIClient *inboxAPIClient;
@property (nonatomic, strong) id mockUser;
@property (nonatomic, strong) id mockConfig;
@property (nonatomic, strong) id mockDataStore;
@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) id mockPush;
@property (nonatomic, strong) id mockSession;

@property (nonatomic, strong) UAConfig *config;

@end

@implementation UAInboxAPIClientTest

- (void)setUp {
    [super setUp];

    self.config = [UAConfig config];

    self.mockDataStore = [self mockForClass:[UAPreferenceDataStore class]];

    self.mockPush = [self mockForClass:[UAPush class]];
    [[[self.mockPush stub] andReturn:@"mockChannelID"] channelID];

    self.mockSession = [self mockForClass:[UARequestSession class]];

    self.mockAirship = [self mockForClass:[UAirship class]];
    [[[self.mockAirship stub] andReturn:self.mockAirship] shared];
    [[[self.mockAirship stub] andReturn:self.mockPush] push];

    self.mockUser = [self mockForClass:[UAUser class]];
    [[[self.mockUser stub] andReturn:@"userName"] username];
    [[[self.mockUser stub] andReturn:@"userPassword"] password];

    self.inboxAPIClient = [UAInboxAPIClient clientWithConfig:self.mockConfig
                                                     session:self.mockSession
                                                        user:self.mockUser
                                                   dataStore:self.mockDataStore];
}

- (void)tearDown {
    [self.mockAirship stopMocking];
    [self.mockPush stopMocking];
    [self.mockUser stopMocking];
    [self.mockDataStore stopMocking];
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
        [invocation getArgument:&arg atIndex:4];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler)arg;

        completionHandler(responseData, (NSURLResponse *)response, nil);

        typedef void (^UARequestCompletionHandler)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error);

    }] dataTaskWithRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
        UARequest *request = obj;

        if (![@"mockChannelID" isEqualToString:request.headers[kUAChannelIDHeader]]) {
            return NO;
        }
        return YES;
    }] retryWhere:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    // Make call
    [self.inboxAPIClient retrieveMessageListOnSuccess:^(NSUInteger status, NSArray * _Nullable messages) {
        XCTAssertEqualObjects(messages[0], @"someMessage", @"Messages should match messages from the response");
    } onFailure:^() {
        XCTFail(@"Should not be called");
    }];

    [self.mockSession verify];
    [self.mockSession stopMocking];
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
        [invocation getArgument:&arg atIndex:4];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler)arg;

        completionHandler(nil, (NSURLResponse *)response, nil);

        typedef void (^UARequestCompletionHandler)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error);

    }] dataTaskWithRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
        UARequest *request = obj;

        if (![@"mockChannelID" isEqualToString:request.headers[kUAChannelIDHeader]]) {
            return NO;
        }
        return YES;
    }]  retryWhere:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    __block BOOL failed = NO;
    [self.inboxAPIClient retrieveMessageListOnSuccess:^(NSUInteger status, NSArray * _Nullable messages) {
        XCTFail(@"Should not be called");
    } onFailure:^() {
        failed = YES;
    }];

    XCTAssertTrue(failed);

    [self.mockSession verify];
    [self.mockSession stopMocking];
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
        [invocation getArgument:&arg atIndex:4];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler)arg;

        completionHandler(nil, (NSURLResponse *)response, nil);

        typedef void (^UARequestCompletionHandler)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error);

    }] dataTaskWithRequest:OCMOCK_ANY retryWhere:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    __block BOOL failed = NO;
    [self.inboxAPIClient retrieveMessageListOnSuccess:^(NSUInteger status, NSArray * _Nullable messages) {
        XCTFail(@"Should not be called");
    } onFailure:^() {
        failed = YES;
    }];

    XCTAssertTrue(failed);

    [self.mockSession verify];
    [self.mockSession stopMocking];
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
        [invocation getArgument:&arg atIndex:4];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler)arg;

        completionHandler(responseData, (NSURLResponse *)response, nil);

        typedef void (^UARequestCompletionHandler)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error);
    }] dataTaskWithRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
        UARequest *request = obj;

        if (![@"mockChannelID" isEqualToString:request.headers[kUAChannelIDHeader]]) {
            return NO;
        }
        return YES;
    }] retryWhere:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    NSURL *testURL = [NSURL URLWithString:@"testURL"];
    __block BOOL successBlockCalled = false;

    // Make call
    [self.inboxAPIClient performBatchMarkAsReadForMessageURLs:@[testURL] onSuccess:^{
        successBlockCalled = true;
    } onFailure:^() {
        XCTFail(@"Should not be called");
    }];

    XCTAssertTrue(successBlockCalled);

    [self.mockSession verify];
    [self.mockSession stopMocking];
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
        [invocation getArgument:&arg atIndex:4];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler)arg;

        completionHandler(nil, (NSURLResponse *)response, nil);

        typedef void (^UARequestCompletionHandler)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error);
    }] dataTaskWithRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
        UARequest *request = obj;

        if (![@"mockChannelID" isEqualToString:request.headers[kUAChannelIDHeader]]) {
            return NO;
        }
        return YES;
    }] retryWhere:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    NSURL *testURL = [NSURL URLWithString:@"testURL"];
    __block BOOL failureBlockCalled = false;

    // Make call
    [self.inboxAPIClient performBatchMarkAsReadForMessageURLs:@[testURL] onSuccess:^{
        XCTFail(@"Should not be called");
    } onFailure:^() {
        failureBlockCalled = true;
    }];

    XCTAssertTrue(failureBlockCalled);

    [self.mockSession verify];
    [self.mockSession stopMocking];
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
        [invocation getArgument:&arg atIndex:4];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler)arg;

        completionHandler(responseData, (NSURLResponse *)response, nil);

        typedef void (^UARequestCompletionHandler)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error);
    }] dataTaskWithRequest:OCMOCK_ANY retryWhere:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    NSURL *testURL = [NSURL URLWithString:@"testURL"];
    __block BOOL successBlockCalled = false;

    // Make call
    [self.inboxAPIClient performBatchDeleteForMessageURLs:@[testURL] onSuccess:^{
        successBlockCalled = true;
    } onFailure:^() {
        XCTFail(@"Should not be called");
    }];

    XCTAssertTrue(successBlockCalled);

    [self.mockSession verify];
    [self.mockSession stopMocking];
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
        [invocation getArgument:&arg atIndex:4];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler)arg;

        completionHandler(nil, (NSURLResponse *)response, nil);

        typedef void (^UARequestCompletionHandler)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error);
    }] dataTaskWithRequest:OCMOCK_ANY retryWhere:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    NSURL *testURL = [NSURL URLWithString:@"testURL"];
    __block BOOL failureBlockCalled = false;

    // Make call
    [self.inboxAPIClient performBatchDeleteForMessageURLs:@[testURL] onSuccess:^{
        XCTFail(@"Should not be called");
    } onFailure:^() {
        failureBlockCalled = true;
    }];

    XCTAssertTrue(failureBlockCalled);

    [self.mockSession verify];
    [self.mockSession stopMocking];
}


@end
